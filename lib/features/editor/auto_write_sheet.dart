import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/database/novel_repository.dart';
import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/llm/stream_progress.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/prompts/prompt_limits.dart';
import '../../core/prompts/prompt_templates.dart';
import '../../core/security/api_key_vault.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/streaming_status_chip.dart';
import '../../domain/models/novel_domain.dart';
import '../../domain/writing/context_builder.dart';

/// 自动撰写流水线（修复原版 B3 三大缺陷：URL 安全校验、建档喂 reasoning 事件、空章 R18 语言回退细纲/梗概）
class AutoWriteSheet extends ConsumerStatefulWidget {
  const AutoWriteSheet({
    super.key,
    required this.novelId,
    this.resolveStyleCard,
    this.resolveSourceWindow,
  });

  final String novelId;
  final Future<String?> Function(NovelBundle bundle)? resolveStyleCard;
  final Future<String?> Function(NovelBundle bundle, ChapterBundle ch)?
  resolveSourceWindow;

  @override
  ConsumerState<AutoWriteSheet> createState() => _AutoWriteSheetState();
}

class _AutoWriteSheetState extends ConsumerState<AutoWriteSheet> {
  int _wordTarget = 2000;
  bool _antiAIInline = true;
  bool _running = false;
  String _status = '准备就绪';
  int _done = 0;
  int _total = 0;
  final List<String> _completed = [];
  String? _error;

  final _progress = StreamProgressTracker();
  CancelToken? _cancel;

  @override
  void dispose() {
    _cancel?.cancel();
    _progress.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _start() async {
    final provider = ref.read(defaultProviderProvider);
    if (provider == null) {
      setState(() => _error = '尚未配置默认模型提供商，请先前往设置。');
      return;
    }
    final repo = ref.read(novelRepositoryProvider);
    var bundle = await repo.loadBundle(widget.novelId);
    if (bundle == null) return;

    final allChapters = bundle.allChaptersInOrder
        .where((c) => !c.chapter.isOriginal)
        .toList();
    if (allChapters.isEmpty) {
      setState(() => _error = '全书暂无可写章节。');
      return;
    }
    final missingOutline = allChapters.any(
      (c) => (c.chapter.detailedOutline ?? '').trim().isEmpty,
    );
    if (missingOutline) {
      setState(() => _error = '自动撰写要求全书非原作章节均已填写细纲，请先到「大纲与伏笔」页补全。');
      return;
    }
    final targets = allChapters
        .where((c) => c.chapter.content.trim().isEmpty)
        .toList();
    if (targets.isEmpty) {
      setState(() => _error = '没有待写的空白章节。');
      return;
    }

    LLMClient client;
    try {
      client = await createClientForProvider(
        provider,
        ref.read(apiKeyVaultProvider),
      );
    } catch (e) {
      setState(() => _error = '$e');
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _done = 0;
      _total = targets.length;
      _completed.clear();
    });
    _cancel = CancelToken();
    await WakelockPlus.enable();

    final lib = ref.read(promptLibraryProvider);
    final config = GenerationConfig(
      temperature: provider.temperature,
      maxTokens: provider.maxTokens,
    );

    try {
      for (final item in targets) {
        if (_cancel?.isCancelled ?? false) break;
        // 每章重读最新 bundle（确保拿到上一章刚落盘的正文与摘要）
        bundle = await repo.loadBundle(widget.novelId);
        if (bundle == null) break;
        final freshCh = bundle.allChaptersInOrder
            .where((c) => c.chapter.id == item.chapter.id)
            .firstOrNull;
        if (freshCh == null) continue;

        setState(() => _status = '撰写《${freshCh.chapter.title}》…');

        // 1) 组装上下文（修复原版 B3：空章 R18 语言探测回退到细纲/梗概）
        String? r18Text;
        if (bundle.novel.r18Enabled) {
          final sample = (freshCh.chapter.detailedOutline ?? '').isNotEmpty
              ? freshCh.chapter.detailedOutline!
              : bundle.novel.synopsis;
          r18Text = await lib.r18Supplement(sample);
        }
        final styleCard = await widget.resolveStyleCard?.call(bundle);
        final sourceWindow = await widget.resolveSourceWindow?.call(
          bundle,
          freshCh,
        );
        final antiAiText = _antiAIInline
            ? lib.resolvedText(PromptID.antiAIInline)
            : null;
        final budget = PromptTemplates.adjustedInputBudget(
          provider.contextBudgetChars,
          [r18Text, styleCard, antiAiText, provider.systemPromptExtra],
        );
        final ctx = ContextBuilder.buildContinueContext(
          chapter: freshCh,
          bundle: bundle,
          budgetChars: budget,
          styleCard: styleCard,
          sourceWindow: sourceWindow,
        );
        var writeMsgs = PromptTemplates.writing(
          library: lib,
          staticContext: ctx.staticPrefix,
          renderedContext: ctx.dynamicSuffix.isNotEmpty
              ? ctx.dynamicSuffix
              : ctx.rendered,
          wordTarget: _wordTarget,
        );
        writeMsgs = PromptTemplates.applyingExtra(r18Text, writeMsgs);
        writeMsgs = PromptTemplates.applyingExtra(antiAiText, writeMsgs);
        writeMsgs = PromptTemplates.applyingExtra(
          provider.systemPromptExtra,
          writeMsgs,
        );

        _progress.begin();
        final draftBuf = StringBuffer();
        await for (final ev in client.streamChat(
          writeMsgs,
          config: config,
          cancelToken: _cancel,
        )) {
          _progress.handle(ev);
          if (ev is ContentDelta) draftBuf.write(ev.text);
        }
        if (_cancel?.isCancelled ?? false) break;

        final draft = draftBuf.toString().trim();
        if (draft.length < 200) {
          setState(
            () => _error =
                '《${freshCh.chapter.title}》输出过短（${draft.length} 字），已自动停机保护；之前章节已保存。',
          );
          break;
        }

        await repo.takeSnapshot(
          chapterId: freshCh.chapter.id,
          content: freshCh.chapter.content,
          triggerType: 'ai_insert',
        );
        await repo.saveChapterContent(
          novelId: widget.novelId,
          chapterId: freshCh.chapter.id,
          content: draft,
        );

        // 2) 建档摘要（修复原版 B3：全事件喂给 progress，包含 reasoning）
        setState(() => _status = '建档摘要《${freshCh.chapter.title}》…');
        final sumMsgs = PromptTemplates.applyingExtra(
          provider.systemPromptExtra,
          PromptTemplates.summarize(
            library: lib,
            content: draft,
            title: freshCh.chapter.title,
          ),
        );
        _progress.begin();
        final rawSum = StringBuffer();
        await for (final ev in client.streamChat(
          sumMsgs,
          config: GenerationConfig(
            temperature: 0.2,
            maxTokens: provider.maxTokens,
          ),
          cancelToken: _cancel,
        )) {
          _progress.handle(ev);
          if (ev is ContentDelta) rawSum.write(ev.text);
        }
        if (_cancel?.isCancelled ?? false) break;

        final parsedSum = SummaryResult.tryParse(rawSum.toString());
        if (parsedSum == null) {
          setState(
            () => _error =
                '《${freshCh.chapter.title}》正文已保存，但摘要 JSON 解析失败，已暂停；手动建档后可继续。',
          );
          break;
        }
        await repo.applySummaryResult(
          novelId: widget.novelId,
          chapter: freshCh.chapter,
          result: parsedSum,
        );
        setState(() {
          _done++;
          _completed.add(freshCh.chapter.title);
        });
      }

      if (mounted && _error == null) {
        setState(
          () => _status = (_cancel?.isCancelled ?? false)
              ? '已手动停止（完成 $_done / $_total 章，均已保存）'
              : '自动撰写全部完成（$_done / $_total 章）',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '执行出错：$e（已完成章节均已保存）');
    } finally {
      _progress.finish();
      await WakelockPlus.disable();
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppTokens.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '自动撰写流水线',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '按顺序补齐空白章节（每章「撰写 → 摘要建档」后强制落盘）。批量生成不保证每章完美，建议重要章仍逐章打磨。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('每章目标字数'),
              const Spacer(),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1500, label: Text('1500')),
                  ButtonSegment(value: 2000, label: Text('2000')),
                  ButtonSegment(value: 3000, label: Text('3000')),
                ],
                selected: {_wordTarget},
                onSelectionChanged: _running
                    ? null
                    : (s) => setState(() => _wordTarget = s.first),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('去AI味 · 写作时自动约束'),
            value: _antiAIInline,
            onChanged: _running
                ? null
                : (v) => setState(() => _antiAIInline = v),
          ),
          if (_running || _total > 0) ...[
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text('$_done / $_total'),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _total == 0 ? null : _done / _total,
              borderRadius: BorderRadius.circular(4),
            ),
            if (_running) ...[
              const SizedBox(height: 8),
              StreamingStatusChip(tracker: _progress),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
          ],
          if (_completed.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '已完成：${_completed.join('、')}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_running)
                FilledButton.tonal(
                  onPressed: () => _cancel?.cancel(),
                  child: const Text('停止流水线'),
                )
              else ...[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('开始自动撰写'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
