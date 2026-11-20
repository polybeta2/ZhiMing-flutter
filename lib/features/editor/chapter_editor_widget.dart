import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/database/novel_repository.dart';
import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/llm/stream_progress.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/prompts/prompt_limits.dart';
import '../../core/prompts/prompt_templates.dart';
import '../../core/security/api_key_vault.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/prompt_guard.dart';
import '../../core/widgets/diff_preview_dialog.dart';
import '../../core/widgets/streaming_status_chip.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/models/novel_domain.dart';
import '../../domain/writing/context_builder.dart';
import '../../domain/writing/prose_checker.dart';
import '../app_settings/model_selector_sheet.dart';

/// 会话级文风选择三态（仅当前编辑会话生效，不落库）
sealed class SessionStyleMode {
  const SessionStyleMode();
}

final class FollowBookStyle extends SessionStyleMode {
  const FollowBookStyle();
}

final class OffSessionStyle extends SessionStyleMode {
  const OffSessionStyle();
}

final class CustomSessionStyle extends SessionStyleMode {
  const CustomSessionStyle(this.profileId);
  final String profileId;
}

/// 不可变续写参数对象（修复 B6：重新生成保留 antiAIInline 开关）
class _ContinueRequest {
  const _ContinueRequest({
    required this.isNewChapter,
    required this.wordTarget,
    required this.antiAIInline,
    this.instruction,
  });

  final bool isNewChapter;
  final int wordTarget;
  final bool antiAIInline;
  final String? instruction;
}

class _RewriteRequest {
  const _RewriteRequest({
    required this.mode,
    required this.selection,
    this.instruction,
  });

  final String mode;
  final String selection;
  final String? instruction;
}

/// 增强章节编辑器：
/// - 顶栏属性胶囊（模型 / 文风 / 查找 / 排版 / 版本历史）+ 底栏仅 4 主动作
/// - 原生划词选中即出现悬浮精修条（改写/润色/扩写/去AI味），彻底告别手动复制粘贴
/// - Diff 对比替换（修复 B4 选区丢失吞报错与丢草稿）
/// - 1.2s 防抖增量 SQLite 保存（修复 B1 整库卡顿）
class ChapterEditorWidget extends ConsumerStatefulWidget {
  const ChapterEditorWidget({
    super.key,
    required this.novelId,
    required this.chapterId,
    this.onOpenStyleEval,
    this.resolveStyleCard,
    this.resolveSourceWindow,
    this.onToggleReferencePane,
    this.referencePaneOpen = false,
  });

  final String novelId;
  final String chapterId;
  final Future<void> Function(
    String draftText,
    String chapterTitle,
    ProviderRecord provider,
    ValueChanged<String> onApply,
  )?
  onOpenStyleEval;
  final Future<String?> Function(
    NovelBundle bundle,
    SessionStyleMode mode,
    String variant,
  )?
  resolveStyleCard;
  final Future<String?> Function(NovelBundle bundle, ChapterBundle ch)?
  resolveSourceWindow;
  final VoidCallback? onToggleReferencePane;
  final bool referencePaneOpen;

  @override
  ConsumerState<ChapterEditorWidget> createState() =>
      _ChapterEditorWidgetState();
}

class _ChapterEditorWidgetState extends ConsumerState<ChapterEditorWidget> {
  final _textCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _replaceCtrl = TextEditingController();

  Chapter? _chapter;
  bool _loading = true;
  bool _dirty = false;
  Timer? _debounce;

  // 编辑器快捷工具
  bool _showFindBar = false;
  ProviderRecord? _sessionProvider;
  SessionStyleMode _sessionStyle = const FollowBookStyle();

  // AI 草稿流状态
  bool _streaming = false;
  String _draft = '';
  List<String> _truncatedSections = const [];
  String? _aiError;
  _ContinueRequest? _lastContinue;
  _RewriteRequest? _lastRewrite;
  final _draftProgress = StreamProgressTracker();
  CancelToken? _draftCancel;

  // 摘要流状态
  bool _summarizing = false;
  final _summaryProgress = StreamProgressTracker();
  CancelToken? _summaryCancel;

  @override
  void initState() {
    super.initState();
    _loadChapter(widget.chapterId);
    _textCtrl.addListener(_onTextOrSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant ChapterEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterId != widget.chapterId) {
      _flushSaveSync();
      _resetDraft();
      _loadChapter(widget.chapterId);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flushSaveSync();
    _draftCancel?.cancel();
    _summaryCancel?.cancel();
    _draftProgress.dispose();
    _summaryProgress.dispose();
    _textCtrl.removeListener(_onTextOrSelectionChanged);
    _textCtrl.dispose();
    _searchCtrl.dispose();
    _replaceCtrl.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _loadChapter(String chapterId) async {
    setState(() => _loading = true);
    final ch = await ref.read(appDatabaseProvider).getChapter(chapterId);
    if (!mounted) return;
    _chapter = ch;
    _textCtrl.text = ch?.content ?? '';
    _dirty = false;
    setState(() => _loading = false);
  }

  void _onTextOrSelectionChanged() {
    if (_chapter == null || _chapter!.isOriginal) return;
    if (_textCtrl.text != _chapter!.content) {
      _dirty = true;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1200), _saveNow);
    }
    setState(() {});
  }

  void _flushSaveSync() {
    if (_dirty && _chapter != null && !_chapter!.isOriginal) {
      final chId = _chapter!.id;
      final content = _textCtrl.text;
      _dirty = false;
      ref
          .read(novelRepositoryProvider)
          .saveChapterContent(
            novelId: widget.novelId,
            chapterId: chId,
            content: content,
          );
    }
  }

  Future<void> _saveNow({bool notify = false}) async {
    final ch = _chapter;
    if (ch == null || ch.isOriginal) return;
    _debounce?.cancel();
    _dirty = false;
    final content = _textCtrl.text;
    await ref
        .read(novelRepositoryProvider)
        .saveChapterContent(
          novelId: widget.novelId,
          chapterId: ch.id,
          content: content,
        );
    _chapter = ch.copyWith(content: content, wordCount: content.length);
    if (notify && mounted) {
      showZmSnackBar(context, '已保存（${content.length} 字）');
    }
  }

  ProviderRecord? get _activeProvider =>
      _sessionProvider ?? ref.read(defaultProviderProvider);

  String get _selectedText {
    final sel = _textCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) return '';
    final start = sel.start.clamp(0, _textCtrl.text.length);
    final end = sel.end.clamp(0, _textCtrl.text.length);
    if (end <= start) return '';
    return _textCtrl.text.substring(start, end);
  }

  void _resetDraft() {
    _draftCancel?.cancel();
    _draftProgress.finish();
    WakelockPlus.disable();
    setState(() {
      _streaming = false;
      _draft = '';
      _truncatedSections = const [];
      _aiError = null;
      _lastContinue = null;
      _lastRewrite = null;
    });
  }

  // ---- 撰写 / 续写 ----

  Future<void> _openContinueDialog() async {
    final provider = _activeProvider;
    if (provider == null) {
      showZmSnackBar(context, '请先在「设置 → 模型提供商」配置一个接口', isError: true);
      return;
    }
    final isNew = _textCtrl.text.trim().isEmpty;
    final hasOutline = (_chapter?.detailedOutline ?? '').trim().isNotEmpty;
    final prefs = await SharedPreferences.getInstance();
    var antiAI = prefs.getBool('writing.antiai.inline') ?? false;
    var wordTarget = isNew ? 2000 : 1500;
    final instrCtrl = TextEditingController();

    if (!mounted) return;
    final req = await showDialog<_ContinueRequest>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text(isNew ? 'AI 撰写整章' : 'AI 续写'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNew && !hasOutline)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '本章尚未填写细纲，建议先在「大纲与伏笔」页补全以提升连贯度。',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                const Text('目标字数'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final opt
                        in isNew
                            ? const [1500, 2000, 2500, 3000, 4000]
                            : const [800, 1500, 2500])
                      ChoiceChip(
                        label: Text('约 $opt 字'),
                        selected: wordTarget == opt,
                        onSelected: (_) => setModal(() => wordTarget = opt),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instrCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: '附加指令（可选）',
                    hintText: isNew
                        ? '例如：开篇以对话切入，节奏紧凑…'
                        : '例如：本段偏动作推进，少写心理独白…',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('去AI味 · 写作时自动约束'),
                  subtitle: const Text(
                    '前置注入反模板规则，减少说明腔与套话',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: antiAI,
                  onChanged: (v) => setModal(() => antiAI = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                await prefs.setBool('writing.antiai.inline', antiAI);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop(
                    _ContinueRequest(
                      isNewChapter: isNew,
                      wordTarget: wordTarget,
                      antiAIInline: antiAI,
                      instruction: instrCtrl.text.trim().isEmpty
                          ? null
                          : instrCtrl.text.trim(),
                    ),
                  );
                }
              },
              child: const Text('开始生成'),
            ),
          ],
        ),
      ),
    );
    instrCtrl.dispose();
    if (req != null) {
      await _startContinue(req);
    }
  }

  Future<void> _startContinue(_ContinueRequest req) async {
    final provider = _activeProvider;
    if (provider == null || _chapter == null) return;
    await _saveNow();
    final repo = ref.read(novelRepositoryProvider);
    final bundle = await repo.loadBundle(widget.novelId);
    if (bundle == null) return;
    final chBundle = bundle.allChaptersInOrder
        .where((c) => c.chapter.id == _chapter!.id)
        .firstOrNull;
    if (chBundle == null) return;

    final lib = ref.read(promptLibraryProvider);
    String? r18Text;
    if (bundle.novel.r18Enabled) {
      final sample = (req.instruction ?? '').isNotEmpty
          ? req.instruction!
          : (_textCtrl.text.isNotEmpty
                ? _textCtrl.text.substring(
                    0,
                    _textCtrl.text.length.clamp(0, 400),
                  )
                : (chBundle.chapter.detailedOutline ?? bundle.novel.synopsis));
      r18Text = await lib.r18Supplement(sample);
    }
    final styleCard = await widget.resolveStyleCard?.call(
      bundle,
      _sessionStyle,
      'writing',
    );
    final sourceWindow = await widget.resolveSourceWindow?.call(
      bundle,
      chBundle,
    );
    final antiAI = req.antiAIInline
        ? lib.resolvedText(PromptID.antiAIInline)
        : null;
    final budget = PromptTemplates.adjustedInputBudget(
      provider.contextBudgetChars,
      [r18Text, styleCard, antiAI, provider.systemPromptExtra],
    );
    final ctx = ContextBuilder.buildContinueContext(
      chapter: chBundle,
      bundle: bundle,
      budgetChars: budget,
      styleCard: styleCard,
      sourceWindow: sourceWindow,
    );
    var msgs = req.isNewChapter
        ? PromptTemplates.writing(
            library: lib,
            staticContext: ctx.staticPrefix,
            renderedContext: ctx.dynamicSuffix.isNotEmpty
                ? ctx.dynamicSuffix
                : ctx.rendered,
            wordTarget: req.wordTarget,
            extra: req.instruction,
          )
        : PromptTemplates.continueWriting(
            library: lib,
            staticContext: ctx.staticPrefix,
            renderedContext: ctx.dynamicSuffix.isNotEmpty
                ? ctx.dynamicSuffix
                : ctx.rendered,
            wordTarget: req.wordTarget,
            extra: req.instruction,
          );
    msgs = PromptTemplates.applyingExtra(r18Text, msgs);
    msgs = PromptTemplates.applyingExtra(antiAI, msgs);
    msgs = PromptTemplates.applyingExtra(provider.systemPromptExtra, msgs);

    if (!mounted) return;
    if (!await PromptGuard.authorize(
      context,
      totalChars: msgs.totalContentChars,
    )) {
      return;
    }

    setState(() {
      _lastContinue = req;
      _lastRewrite = null;
      _truncatedSections = ctx.truncatedSections;
    });
    await _runDraftStream(provider, msgs);
  }

  // ---- 划词精修 / 改写 / 润色 / 扩写 / 去AI味 ----

  Future<void> _openRewriteDialog({String presetMode = '改写'}) async {
    final provider = _activeProvider;
    if (provider == null) {
      showZmSnackBar(context, '请先在「设置 → 模型提供商」配置一个接口', isError: true);
      return;
    }
    final initialSelection = _selectedText.isNotEmpty
        ? _selectedText
        : _textCtrl.text;
    var mode = presetMode;
    final selCtrl = TextEditingController(text: initialSelection);
    final instrCtrl = TextEditingController();

    final req = await showDialog<_RewriteRequest>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('AI 精修'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '改写', label: Text('改写')),
                    ButtonSegment(value: '润色', label: Text('润色')),
                    ButtonSegment(value: '扩写', label: Text('扩写')),
                    ButtonSegment(value: '去AI味', label: Text('去AI味')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => setModal(() => mode = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: selCtrl,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: _selectedText.isNotEmpty
                        ? '已自动带入编辑器选中片段（${_selectedText.length} 字）'
                        : '待精修原文（未划词则默认全章）',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: instrCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '附加要求（可选）',
                    hintText: '例如：削减形容词，增加环境细节…',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (selCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(
                  _RewriteRequest(
                    mode: mode,
                    selection: selCtrl.text,
                    instruction: instrCtrl.text.trim().isEmpty
                        ? null
                        : instrCtrl.text.trim(),
                  ),
                );
              },
              child: const Text('开始精修'),
            ),
          ],
        ),
      ),
    );
    selCtrl.dispose();
    instrCtrl.dispose();
    if (req != null) {
      await _startRewrite(req);
    }
  }

  Future<void> _startRewrite(_RewriteRequest req) async {
    final provider = _activeProvider;
    if (provider == null || _chapter == null) return;
    final bundle = await ref
        .read(novelRepositoryProvider)
        .loadBundle(widget.novelId);
    if (bundle == null) return;
    final lib = ref.read(promptLibraryProvider);

    var effectiveInstruction = req.instruction;
    if (req.mode == '去AI味') {
      final issues = ProseChecker.reportLines(req.selection);
      final report = issues.isEmpty
          ? '本地快检未发现明显模板腔，请通读后按规范微调。'
          : issues.join('\n');
      effectiveInstruction =
          '【本地体检结果】\n$report${effectiveInstruction != null ? '\n【作者附加】$effectiveInstruction' : ''}';
    }

    final styleCard = await widget.resolveStyleCard?.call(
      bundle,
      _sessionStyle,
      req.mode == '去AI味' ? 'antiAI' : 'writing',
    );
    String? r18Text;
    if (bundle.novel.r18Enabled) {
      r18Text = await lib.r18Supplement(req.instruction ?? req.selection);
    }

    var msgs = PromptTemplates.rewrite(
      library: lib,
      mode: req.mode,
      selection: req.selection,
      instruction: effectiveInstruction,
      styleCard: styleCard,
    );
    msgs = PromptTemplates.applyingExtra(r18Text, msgs);
    msgs = PromptTemplates.applyingExtra(provider.systemPromptExtra, msgs);

    if (!mounted) return;
    if (!await PromptGuard.authorize(
      context,
      totalChars: msgs.totalContentChars,
    )) {
      return;
    }

    setState(() {
      _lastRewrite = req;
      _lastContinue = null;
      _truncatedSections = const [];
    });
    await _runDraftStream(provider, msgs);
  }

  Future<void> _runDraftStream(
    ProviderRecord provider,
    List<LLMMessage> messages,
  ) async {
    _draftCancel?.cancel();
    _draftCancel = CancelToken();
    setState(() {
      _streaming = true;
      _draft = '';
      _aiError = null;
    });
    _draftProgress.begin();
    await WakelockPlus.enable();

    final buf = StringBuffer();
    var lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final client = await createClientForProvider(
        provider,
        ref.read(apiKeyVaultProvider),
      );
      await for (final ev in client.streamChat(
        messages,
        config: GenerationConfig(
          temperature: provider.temperature,
          maxTokens: provider.maxTokens,
        ),
        cancelToken: _draftCancel,
      )) {
        _draftProgress.handle(ev);
        if (ev is ContentDelta) {
          buf.write(ev.text);
          final now = DateTime.now();
          if (now.difference(lastFlush).inMilliseconds >= 100) {
            lastFlush = now;
            if (mounted) setState(() => _draft = buf.toString());
          }
        }
      }
      if (mounted) setState(() => _draft = buf.toString());
    } catch (e) {
      if (mounted) setState(() => _aiError = '$e');
    } finally {
      _draftProgress.finish();
      await WakelockPlus.disable();
      if (mounted) setState(() => _streaming = false);
    }
  }

  Future<void> _acceptDraft() async {
    if (_streaming || _draft.isEmpty || _chapter == null) return;
    final repo = ref.read(novelRepositoryProvider);

    if (_lastRewrite != null) {
      final selection = _lastRewrite!.selection;
      final confirmed = await showDiffConfirmDialog(
        context,
        title: '确认应用「${_lastRewrite!.mode}」修改',
        before: selection,
        after: _draft,
        confirmLabel: '建快照并替换',
      );
      if (!confirmed || !mounted) return;

      final currentText = _textCtrl.text;
      final idx = currentText.indexOf(selection);
      if (idx == -1) {
        // 修复 B4：选区已变动时不静默丢草稿，让用户决定复制或追加
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('原选区已变动'),
            content: const Text('你在生成期间修改了正文，原选中文本已找不到。草稿已保留，请选择处理方式：'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('cancel'),
                child: const Text('保留草稿'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('copy'),
                child: const Text('复制草稿'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop('append'),
                child: const Text('追加到章末'),
              ),
            ],
          ),
        );
        if (action == 'copy') {
          await Clipboard.setData(ClipboardData(text: _draft));
          if (mounted) showZmSnackBar(context, '草稿已复制到剪贴板');
        } else if (action == 'append') {
          await repo.takeSnapshot(
            chapterId: _chapter!.id,
            content: currentText,
            triggerType: 'ai_insert',
          );
          _textCtrl.text = '$currentText\n$_draft';
          await _saveNow();
          _resetDraft();
        }
        return;
      }

      await repo.takeSnapshot(
        chapterId: _chapter!.id,
        content: currentText,
        triggerType: 'ai_insert',
      );
      final updated = currentText.replaceRange(
        idx,
        idx + selection.length,
        _draft,
      );
      _textCtrl.text = updated;
      await _saveNow();
      _resetDraft();
      if (mounted) showZmSnackBar(context, '已保存快照并完成替换');
      return;
    }

    // 撰写 / 续写采纳
    await repo.takeSnapshot(
      chapterId: _chapter!.id,
      content: _textCtrl.text,
      triggerType: 'ai_insert',
    );
    _textCtrl.text = '${_textCtrl.text}$_draft';
    await _saveNow();
    _resetDraft();
    if (mounted) showZmSnackBar(context, '已保存快照并采纳正文');
  }

  Future<void> _regenerate() async {
    if (_lastContinue != null) {
      await _startContinue(_lastContinue!);
    } else if (_lastRewrite != null) {
      await _startRewrite(_lastRewrite!);
    }
  }

  // ---- 摘要建档 ----

  Future<void> _openSummarySheet() async {
    if (_chapter == null) return;
    await _saveNow();
    final existing = await ref
        .read(appDatabaseProvider)
        .getSummary(_chapter!.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SummarySheet(
        chapter: _chapter!,
        existing: existing,
        onGenerate: () async {
          Navigator.of(ctx).pop();
          await _generateSummary();
        },
        onSaveManual: (text, facts) async {
          await ref
              .read(appDatabaseProvider)
              .upsertSummary(
                ChapterSummariesCompanion.insert(
                  chapterId: _chapter!.id,
                  summaryText: text,
                  keyFactsJson: Value(encodeStringList(facts)),
                  updatedAt: DateTime.now(),
                ),
              );
          if (mounted) showZmSnackBar(context, '摘要已保存');
        },
      ),
    );
  }

  Future<void> _generateSummary() async {
    final provider = _activeProvider;
    if (provider == null) {
      showZmSnackBar(context, '请先配置模型提供商', isError: true);
      return;
    }
    final content = _textCtrl.text.trim();
    if (content.isEmpty) {
      showZmSnackBar(context, '本章还没有正文，先写点内容再建档', isError: true);
      return;
    }
    final msgs = PromptTemplates.applyingExtra(
      provider.systemPromptExtra,
      PromptTemplates.summarize(
        library: ref.read(promptLibraryProvider),
        content: content,
        title: _chapter!.title,
      ),
    );
    if (!await PromptGuard.authorize(
      context,
      totalChars: msgs.totalContentChars,
    )) {
      return;
    }

    setState(() => _summarizing = true);
    _summaryCancel = CancelToken();
    _summaryProgress.begin();
    try {
      final client = await createClientForProvider(
        provider,
        ref.read(apiKeyVaultProvider),
      );
      final raw = StringBuffer();
      await for (final ev in client.streamChat(
        msgs,
        config: GenerationConfig(
          temperature: 0.2,
          maxTokens: provider.maxTokens,
        ),
        cancelToken: _summaryCancel,
      )) {
        _summaryProgress.handle(ev);
        if (ev is ContentDelta) raw.write(ev.text);
      }
      final parsed = SummaryResult.tryParse(raw.toString());
      if (parsed == null) {
        if (mounted) {
          showZmSnackBar(context, '摘要 JSON 解析失败，请重试或手动编辑', isError: true);
        }
        return;
      }
      await ref
          .read(novelRepositoryProvider)
          .applySummaryResult(
            novelId: widget.novelId,
            chapter: _chapter!,
            result: parsed,
          );
      if (mounted) {
        showZmSnackBar(
          context,
          '建档完成（${parsed.keyFacts.length} 条关键事实，${parsed.newForeshadowings.length} 条新伏笔）',
        );
      }
    } catch (e) {
      if (mounted) showZmSnackBar(context, '建档失败：$e', isError: true);
    } finally {
      _summaryProgress.finish();
      if (mounted) setState(() => _summarizing = false);
    }
  }

  // ---- 版本快照 ----

  Future<void> _openSnapshots() async {
    if (_chapter == null) return;
    await _saveNow();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SnapshotHistorySheet(
        novelId: widget.novelId,
        chapterId: _chapter!.id,
        currentText: _textCtrl.text,
        onManualSnapshot: () async {
          await ref
              .read(novelRepositoryProvider)
              .takeSnapshot(
                chapterId: _chapter!.id,
                content: _textCtrl.text,
                triggerType: 'manual_save',
              );
          if (mounted) showZmSnackBar(context, '已保存手动快照');
        },
        onRestored: (restoredText) {
          _textCtrl.text = restoredText;
          setState(() {});
          showZmSnackBar(context, '已回退（原正文已自动备份为新版本）');
        },
      ),
    );
  }

  // ---- 排版设置弹窗 ----

  Future<void> _openTypographySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (ctx, ref, _) {
          final st = ref.watch(appearanceProvider);
          final nt = ref.read(appearanceProvider.notifier);
          return Padding(
            padding: const EdgeInsets.all(AppTokens.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '编辑器排版与护眼纸感',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in EditorPaperTheme.values)
                      ChoiceChip(
                        label: Text(p.label),
                        selected: st.editorPaperTheme == p,
                        onSelected: (_) => nt.setEditorPaperTheme(p),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('字号'),
                    Expanded(
                      child: Slider(
                        value: st.editorFontSize,
                        min: 13,
                        max: 24,
                        divisions: 11,
                        onChanged: nt.setEditorFontSize,
                      ),
                    ),
                    Text('${st.editorFontSize.round()}'),
                  ],
                ),
                Row(
                  children: [
                    const Text('行距'),
                    Expanded(
                      child: Slider(
                        value: st.editorLineHeight,
                        min: 1.3,
                        max: 2.3,
                        divisions: 10,
                        onChanged: nt.setEditorLineHeight,
                      ),
                    ),
                    Text(st.editorLineHeight.toStringAsFixed(1)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- 会话内文风选择 ----

  Future<void> _openSessionStylePicker() async {
    final profiles = await ref.read(appDatabaseProvider).getStyleProfiles();
    if (!mounted) return;
    final picked = await showModalBottomSheet<SessionStyleMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppTokens.s3),
          children: [
            ListTile(
              title: const Text('跟随本书绑定文风'),
              trailing: _sessionStyle is FollowBookStyle
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(ctx).pop(const FollowBookStyle()),
            ),
            ListTile(
              title: const Text('本次会话暂时关闭文风'),
              trailing: _sessionStyle is OffSessionStyle
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(ctx).pop(const OffSessionStyle()),
            ),
            if (profiles.isNotEmpty) const Divider(),
            for (final p in profiles)
              ListTile(
                title: Text(p.name),
                subtitle: const Text('临时指定（不改变本书默认绑定）'),
                trailing:
                    _sessionStyle is CustomSessionStyle &&
                        (_sessionStyle as CustomSessionStyle).profileId == p.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop(CustomSessionStyle(p.id)),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _sessionStyle = picked);
  }

  void _replaceAll() {
    final q = _searchCtrl.text;
    if (q.isEmpty || _chapter?.isOriginal == true) return;
    final count = RegExp(RegExp.escape(q)).allMatches(_textCtrl.text).length;
    if (count == 0) {
      showZmSnackBar(context, '未找到匹配内容');
      return;
    }
    _textCtrl.text = _textCtrl.text.replaceAll(q, _replaceCtrl.text);
    _saveNow();
    showZmSnackBar(context, '已替换 $count 处');
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    // 响应式订阅全局默认模型（修复 B7 陈旧快照）
    final defaultProvider = ref.watch(defaultProviderProvider);
    final activeProvider = _sessionProvider ?? defaultProvider;
    final cs = Theme.of(context).colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());
    final ch = _chapter;
    if (ch == null) {
      return const ZmEmptyState(icon: Icons.article_outlined, title: '未找到章节');
    }

    final paperBg =
        appearance.editorPaperTheme.background ?? cs.surfaceContainerLowest;
    final paperFg = appearance.editorPaperTheme.foreground ?? cs.onSurface;
    final hasSelection = _selectedText.isNotEmpty && !ch.isOriginal;
    final showDraft = _streaming || _draft.isNotEmpty || _aiError != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            _saveNow(notify: true),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            setState(() => _showFindBar = !_showFindBar),
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!ch.isOriginal && !_streaming) {
            _openContinueDialog();
          }
        },
      },
      child: Column(
        children: [
          // 1) 顶栏属性胶囊区
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          ch.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_textCtrl.text.length} 字',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (ch.isOriginal) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '原作 · 只读',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.purple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 模型胶囊
                ActionChip(
                  avatar: const Icon(Icons.memory_rounded, size: 15),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      activeProvider?.modelName ?? '未配模型',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final picked = await showModelSelectorSheet(
                      context,
                      ref: ref,
                      currentSessionProvider: _sessionProvider,
                    );
                    if (mounted) setState(() => _sessionProvider = picked);
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '会话文风',
                  icon: Icon(
                    Icons.text_format_rounded,
                    size: 20,
                    color: _sessionStyle is OffSessionStyle
                        ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                        : cs.primary,
                  ),
                  onPressed: _openSessionStylePicker,
                ),
                IconButton(
                  tooltip: '查找与替换 (Ctrl+F)',
                  icon: const Icon(Icons.find_replace_rounded, size: 20),
                  onPressed: () =>
                      setState(() => _showFindBar = !_showFindBar),
                ),
                IconButton(
                  tooltip: '排版与纸感',
                  icon: const Icon(Icons.format_size_rounded, size: 20),
                  onPressed: _openTypographySheet,
                ),
                IconButton(
                  tooltip: '版本快照',
                  icon: const Icon(Icons.history_rounded, size: 20),
                  onPressed: _openSnapshots,
                ),
                if (widget.onToggleReferencePane != null)
                  IconButton(
                    tooltip: '对照参考栏（细纲/角色/伏笔）',
                    icon: Icon(
                      widget.referencePaneOpen
                          ? Icons.vertical_split_rounded
                          : Icons.vertical_split_outlined,
                      size: 20,
                      color: widget.referencePaneOpen ? cs.primary : null,
                    ),
                    onPressed: widget.onToggleReferencePane,
                  ),
              ],
            ),
          ),

          // 查找替换条
          if (_showFindBar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: '查找…',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _replaceCtrl,
                      decoration: const InputDecoration(
                        hintText: '替换为…',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.tonal(
                    onPressed: ch.isOriginal ? null : _replaceAll,
                    child: const Text('全部替换'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _showFindBar = false),
                  ),
                ],
              ),
            ),

          // 2) 沉浸正文编辑区
          Expanded(
            child: Container(
              color: paperBg,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: TextField(
                    controller: _textCtrl,
                    readOnly: ch.isOriginal,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: appearance.editorFontSize,
                      height: appearance.editorLineHeight,
                      color: paperFg,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      hintText: '开始写下本章故事，或点击下方「撰写 / 续写」让 AI 协助…',
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3) 划词快捷精修浮条（选区非空自动出现）
          if (hasSelection && !showDraft)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: cs.primaryContainer.withValues(alpha: 0.45),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '已选中 ${_selectedText.length} 字：',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  for (final m in const ['改写', '润色', '扩写', '去AI味'])
                    ActionChip(
                      label: Text(m, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openRewriteDialog(presetMode: m),
                    ),
                ],
              ),
            ),

          // 4) AI 流式草稿卡 或 精简 4 按钮主操作条
          if (showDraft)
            _buildDraftCard(cs)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: ch.isOriginal
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '原作章节仅供阅读与续写衔接锚定，请在后续新章中续写。',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_summarizing) ...[
                          Row(
                            children: [
                              StreamingStatusChip(tracker: _summaryProgress),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _summaryCancel?.cancel(),
                                child: const Text('停止建档'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: _openContinueDialog,
                              icon: Icon(
                                _textCtrl.text.trim().isEmpty
                                    ? Icons.edit_note_rounded
                                    : Icons.auto_awesome_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _textCtrl.text.trim().isEmpty
                                    ? 'AI 撰写'
                                    : 'AI 续写',
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _openRewriteDialog(),
                              icon: const Icon(
                                Icons.auto_fix_high_rounded,
                                size: 18,
                              ),
                              label: const Text('AI 精修'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                if (_textCtrl.text.trim().length < 60) {
                                  showZmSnackBar(
                                    context,
                                    '风格体检至少需要 60 字正文',
                                    isError: true,
                                  );
                                  return;
                                }
                                if (activeProvider == null) {
                                  showZmSnackBar(
                                    context,
                                    '请先配置模型提供商',
                                    isError: true,
                                  );
                                  return;
                                }
                                if (widget.onOpenStyleEval != null) {
                                  await widget.onOpenStyleEval!(
                                    _textCtrl.text,
                                    ch.title,
                                    activeProvider,
                                    (newText) async {
                                      await ref
                                          .read(novelRepositoryProvider)
                                          .takeSnapshot(
                                            chapterId: ch.id,
                                            content: _textCtrl.text,
                                            triggerType: 'styleEval',
                                          );
                                      _textCtrl.text = newText;
                                      await _saveNow();
                                      if (!mounted) return;
                                      showZmSnackBar(
                                        this.context,
                                        '已建快照并应用风格体检修改',
                                      );
                                    },
                                  );
                                } else {
                                  final issues = ProseChecker.reportLines(
                                    _textCtrl.text,
                                  );
                                  showZmSnackBar(
                                    context,
                                    issues.isEmpty
                                        ? '本地快检：未发现明显 AI 腔问题'
                                        : '本地快检发现 ${issues.length} 项提示（完整 7 维体检将在 Phase 4 接入）',
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.fact_check_outlined,
                                size: 18,
                              ),
                              label: const Text('风格体检'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _summarizing
                                  ? null
                                  : _openSummarySheet,
                              icon: const Icon(
                                Icons.summarize_outlined,
                                size: 18,
                              ),
                              label: const Text('摘要建档'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(ColorScheme cs) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _lastRewrite != null
                    ? 'AI 精修草稿（${_lastRewrite!.mode}）'
                    : 'AI 写作草稿',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              StreamingStatusChip(
                tracker: _draftProgress,
                hideWhenOutputting: true,
              ),
              const Spacer(),
              Text(
                '${_draft.length} 字',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (_truncatedSections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '预算裁剪：${_truncatedSections.join('、')}',
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),
          if (_aiError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _aiError!,
                style: TextStyle(fontSize: 12, color: cs.error),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _draft.isEmpty && _streaming ? '等待生成内容…' : _draft,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_streaming)
                FilledButton.tonal(
                  onPressed: () => _draftCancel?.cancel(),
                  child: const Text('停止生成'),
                )
              else ...[
                TextButton(
                  onPressed: _resetDraft,
                  child: const Text('放弃'),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: _regenerate,
                  child: const Text('重新生成'),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: _draft.isEmpty ? null : _acceptDraft,
                  child: Text(_lastRewrite != null ? 'Diff 对比并替换' : '采纳到正文'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SummarySheet extends StatefulWidget {
  const _SummarySheet({
    required this.chapter,
    required this.existing,
    required this.onGenerate,
    required this.onSaveManual,
  });

  final Chapter chapter;
  final ChapterSummary? existing;
  final VoidCallback onGenerate;
  final Future<void> Function(String summary, List<String> facts) onSaveManual;

  @override
  State<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<_SummarySheet> {
  late final TextEditingController _sumCtrl;
  late final TextEditingController _factsCtrl;

  @override
  void initState() {
    super.initState();
    _sumCtrl = TextEditingController(text: widget.existing?.summaryText ?? '');
    _factsCtrl = TextEditingController(
      text: decodeStringList(widget.existing?.keyFactsJson).join('\n'),
    );
  }

  @override
  void dispose() {
    _sumCtrl.dispose();
    _factsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '叙事账本 · ${widget.chapter.title}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.onGenerate,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('AI 生成摘要'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sumCtrl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '本章摘要',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _factsCtrl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '关键事实（每行一条）',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                final facts = _factsCtrl.text
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                await widget.onSaveManual(_sumCtrl.text.trim(), facts);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('保存摘要'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotHistorySheet extends ConsumerWidget {
  const _SnapshotHistorySheet({
    required this.novelId,
    required this.chapterId,
    required this.currentText,
    required this.onManualSnapshot,
    required this.onRestored,
  });

  final String novelId;
  final String chapterId;
  final String currentText;
  final Future<void> Function() onManualSnapshot;
  final ValueChanged<String> onRestored;

  String _triggerLabel(String type) => switch (type) {
    'manual_save' => '手动快照',
    'ai_insert' => 'AI 采纳前自动备份',
    'restore' => '回退前自动备份',
    'styleEval' => '风格体检改写前备份',
    _ => type,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '版本快照（最近 50 版，回退永不丢历史）',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onManualSnapshot,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('存一版'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ChapterSnapshot>>(
              stream: db.watchSnapshots(chapterId),
              builder: (context, snap) {
                final list = snap.data ?? const [];
                if (list.isEmpty) {
                  return const ZmEmptyState(
                    icon: Icons.history,
                    title: '暂无历史快照',
                    description: '点击右上角手动保存，或每次采纳 AI 草稿前会自动创建快照。',
                  );
                }
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = list[i];
                    return Card(
                      child: ListTile(
                        title: Text(
                          'v${s.versionNumber} · ${_triggerLabel(s.triggerType)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${s.content.length} 字 · ${s.createdAt.toString().substring(0, 16)}',
                        ),
                        trailing: OutlinedButton(
                          onPressed: () async {
                                final nav = Navigator.of(context);
                                final ok = await showDiffConfirmDialog(
                                  context,
                                  title: '对比并回退到 v${s.versionNumber}',
                                  before: currentText,
                                  after: s.content,
                                  confirmLabel: '确认回退',
                                );
                                if (!ok) return;
                                await ref
                                    .read(novelRepositoryProvider)
                                    .restoreSnapshot(
                                      novelId: novelId,
                                      chapterId: chapterId,
                                      snapshot: s,
                                    );
                                onRestored(s.content);
                                nav.pop();
                          },
                          child: const Text('对比回退'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
