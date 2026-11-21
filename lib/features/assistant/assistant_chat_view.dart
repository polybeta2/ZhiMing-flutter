import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/database/novel_repository.dart';
import '../../core/llm/llm_types.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/llm/stream_progress.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/prompts/prompt_limits.dart';
import '../../core/prompts/prompt_templates.dart';
import '../../core/security/api_key_vault.dart';
import '../../core/storage/blob_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/prompt_guard.dart';
import '../../core/widgets/streaming_status_chip.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/creation/creation_session_engine.dart';
import '../../domain/models/blueprint_models.dart';
import '../../domain/models/novel_domain.dart';
import '../../domain/source/novel_local_indexer.dart';
import '../../domain/writing/assistant_patch.dart';
import '../../domain/writing/assistant_search.dart';
import '../../domain/writing/context_builder.dart';
import '../app_settings/model_selector_sheet.dart';
import 'blueprint_review_card.dart';

/// 作品助手统一视图：
/// - 若作品存在未完成的立项会话，自动打开「立项共创（五阶段状态机 + Drift 持久化恢复）」；
/// - 否则打开「写作助手（单一显式只读/读写胶囊 + zm-patch 逐项确认卡）」。
class AssistantChatView extends ConsumerStatefulWidget {
  const AssistantChatView({
    super.key,
    required this.novelId,
    this.resolveStyleCard,
    this.resolveSourceContext,
    this.onCreationConfirmed,
  });

  final String novelId;
  final Future<String?> Function(NovelBundle bundle)? resolveStyleCard;
  final Future<String?> Function(NovelBundle bundle)? resolveSourceContext;
  final VoidCallback? onCreationConfirmed;

  @override
  ConsumerState<AssistantChatView> createState() => _AssistantChatViewState();
}

class _AssistantChatViewState extends ConsumerState<AssistantChatView> {
  static const _uuid = Uuid();
  static const _kAccessMode = 'assistant.accessMode';

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _progress = StreamProgressTracker();

  ChatThread? _thread;
  CreationSessionEngine? _engine;
  ProviderRecord? _sessionProvider;
  AssistantAccessMode _accessMode = AssistantAccessMode.readOnly;

  bool _loading = true;
  bool _streaming = false;
  String _streamingBuffer = '';
  String? _error;
  AssistantPatch? _pendingPatch;
  List<String> _pendingPatchLines = const [];
  CancelToken? _cancel;

  bool get _isCreation => _thread?.purpose == 'creation';

  @override
  void initState() {
    super.initState();
    _initThread();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _progress.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    unawaited(_disableWakelockSafely());
    super.dispose();
  }

  Future<void> _enableWakelockSafely() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> _disableWakelockSafely() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  Future<void> _initThread() async {
    final db = ref.read(appDatabaseProvider);
    final repo = ref.read(novelRepositoryProvider);
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_kAccessMode);
    if (modeStr == AssistantAccessMode.readWrite.name) {
      _accessMode = AssistantAccessMode.readWrite;
    }

    final pendingCreation = await repo.hasPendingCreationThread(widget.novelId);
    final threads = await db.getChatThreads(widget.novelId);
    ChatThread? target;
    if (pendingCreation) {
      target = threads.where((t) => t.purpose == 'creation').firstOrNull;
    }
    target ??= threads.where((t) => t.purpose == 'writing').firstOrNull;
    if (target == null) {
      final id = _uuid.v4();
      final now = DateTime.now();
      await db.upsertChatThread(
        ChatThreadsCompanion.insert(
          id: id,
          novelId: widget.novelId,
          purpose: 'writing',
          createdAt: now,
        ),
      );
      target = (await db.getChatThreads(
        widget.novelId,
      )).where((t) => t.id == id).first;
    }

    _thread = target;

    if (target.purpose == 'creation') {
      final cachedJson = await db.loadCreationCache(target.id);
      CreationSessionState state;
      if (cachedJson != null) {
        try {
          state = CreationSessionState.fromJson(
            jsonDecode(cachedJson) as Map<String, dynamic>,
          );
        } catch (_) {
          state = CreationSessionState();
        }
      } else {
        final novel = await db.getNovel(widget.novelId);
        state = CreationSessionState(brief: novel?.synopsis ?? '');
      }
      _engine = CreationSessionEngine(state);

      // 新建一句话立项 / 完整思路立项：首进自动触发启动
      final existingMsgs = await db.getChatMessages(target.id);
      if (mounted) setState(() => _loading = false);
      if (existingMsgs.isEmpty &&
          state.phase == CreationPhase.collecting &&
          state.brief.trim().isNotEmpty &&
          _activeProvider != null) {
        if (target.skipsClarification) {
          await _appendMessage('user', state.brief);
          await _appendMessage('assistant', '已收到完整思路，跳过问答直接规划卷章结构…');
          await _runCreationStream(CreationStreamKind.structure);
        } else {
          await _appendMessage('user', state.brief);
          await _runCreationStream(CreationStreamKind.clarify);
        }
      }
      return;
    }

    if (mounted) setState(() => _loading = false);
  }

  ProviderRecord? get _activeProvider =>
      _sessionProvider ?? ref.read(defaultProviderProvider);

  Future<void> _appendMessage(String role, String content) async {
    final thread = _thread;
    if (thread == null || content.trim().isEmpty) return;
    await ref
        .read(appDatabaseProvider)
        .insertChatMessage(
          ChatMessagesCompanion.insert(
            id: _uuid.v4(),
            threadId: thread.id,
            role: role,
            content: content.trim(),
            createdAt: DateTime.now(),
          ),
        );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _persistCreationState() async {
    final thread = _thread;
    final engine = _engine;
    if (thread == null || engine == null) return;
    await ref
        .read(appDatabaseProvider)
        .saveCreationCache(thread.id, jsonEncode(engine.state.toJson()));
  }

  // ---- 发送消息路由 ----

  Future<void> _sendInput() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _streaming) return;
    if (_activeProvider == null) {
      showZmSnackBar(context, '请先在「设置 → 模型提供商」配置一个接口', isError: true);
      return;
    }
    _inputCtrl.clear();
    await _appendMessage('user', text);

    if (_isCreation) {
      await _routeCreationInput(text);
    } else {
      await _sendWritingAssistant();
    }
  }

  Future<void> _routeCreationInput(String text) async {
    final engine = _engine!;
    switch (engine.state.phase) {
      case CreationPhase.collecting:
        if (engine.state.brief.trim().isEmpty) {
          engine.state.brief = text;
        } else {
          engine.state.qaText += '【作者回答】\n$text\n';
        }
        await _persistCreationState();
        if (_thread?.skipsClarification == true) {
          await _runCreationStream(CreationStreamKind.structure);
        } else {
          await _runCreationStream(CreationStreamKind.clarify);
        }
      case CreationPhase.proposing:
        await _runCreationStream(CreationStreamKind.structure, feedback: text);
      case CreationPhase.blueprintReady:
      case CreationPhase.outlining:
        if (engine.state.blueprint != null) {
          await _runCreationStream(CreationStreamKind.revise, feedback: text);
        } else {
          await _runCreationStream(CreationStreamKind.foundation, feedback: text);
        }
      case CreationPhase.confirmed:
        await _appendMessage('assistant', '作品已完成立项落库，请切换到「写作」或「大纲伏笔」页继续创作。');
    }
  }

  Future<void> _runCreationStream(
    CreationStreamKind kind, {
    String? feedback,
    int chapterNameVolIdx = -1,
  }) async {
    final provider = _activeProvider;
    final engine = _engine;
    if (provider == null || engine == null || _streaming) return;

    final repo = ref.read(novelRepositoryProvider);
    final bundle = await repo.loadBundle(widget.novelId);
    if (bundle == null) return;
    final lib = ref.read(promptLibraryProvider);

    // 补充约束：智能标签命中 + R18 + 文风对齐
    final supplements = <String>[];
    final enabledTags = decodeStringList(bundle.novel.enabledTagIdsJson);
    final tagSup = lib.matchedSupplement(enabledTags, engine.state.brief);
    if (tagSup != null) supplements.add(tagSup);
    if (bundle.novel.r18Enabled) {
      supplements.add(await lib.r18Supplement(engine.state.brief));
    }
    final styleCard = await widget.resolveStyleCard?.call(bundle);
    if (styleCard != null && styleCard.isNotEmpty) {
      supplements.add('【文风档案对齐】\n规划 style_guide 与叙事基调时须与以下文风档案保持一致：\n$styleCard');
    }
    final supplement = supplements.isEmpty ? null : supplements.join('\n\n');
    final sourceCtx = await widget.resolveSourceContext?.call(bundle);

    List<LLMMessage> msgs;
    switch (kind) {
      case CreationStreamKind.clarify:
        msgs = PromptTemplates.creationClarify(
          library: lib,
          brief: engine.state.brief,
          qaHistory: engine.state.qaText,
          supplement: supplement,
          sourceContext: sourceCtx,
        );
      case CreationStreamKind.structure:
        msgs = PromptTemplates.creationStructure(
          library: lib,
          brief: engine.state.brief,
          qaHistory: engine.state.qaText,
          feedback: feedback,
          supplement: supplement,
          sourceContext: sourceCtx,
        );
      case CreationStreamKind.foundation:
        msgs = PromptTemplates.creationFoundation(
          library: lib,
          brief: engine.state.brief,
          qaHistory: engine.state.qaText,
          structureJson: engine.state.proposal?.toPrettyJson() ?? '{}',
          feedback: feedback,
          supplement: supplement,
          sourceContext: sourceCtx,
        );
      case CreationStreamKind.revise:
        msgs = PromptTemplates.creationRevise(
          library: lib,
          blueprintJson: engine.state.blueprint?.toPrettyJson() ?? '{}',
          feedback: feedback ?? '',
          supplement: supplement,
        );
      case CreationStreamKind.volumeBatch:
        final targets = engine.pendingVolumes(engine.state.volumesPerBatch);
        if (targets.isEmpty) return;
        msgs = PromptTemplates.creationVolumeBatch(
          library: lib,
          context: engine.volumeBatchContext(targets, sourceWindow: sourceCtx),
          targets: targets,
          supplement: supplement,
        );
      case CreationStreamKind.chapterNames:
        final bp = engine.state.blueprint;
        if (bp == null ||
            chapterNameVolIdx < 0 ||
            chapterNameVolIdx >= bp.volumes.length) {
          return;
        }
        final vol = bp.volumes[chapterNameVolIdx];
        final ctx =
            '【书名】${bp.titleSuggestion ?? ''}\n【梗概】${bp.synopsis ?? ''}\n【目标卷】${vol.name ?? '本卷'}（本章数：${vol.chapters.length}）';
        msgs = PromptTemplates.creationChapterNames(
          library: lib,
          context: ctx,
          supplement: supplement,
        );
      case CreationStreamKind.chapterBatch:
        final targets = engine.pendingChapters(engine.state.chaptersPerBatch);
        if (targets.isEmpty) return;
        msgs = PromptTemplates.creationChapterBatch(
          library: lib,
          context: engine.chapterBatchContext(targets, sourceWindow: sourceCtx),
          targets: targets,
          supplement: supplement,
        );
    }

    msgs = PromptTemplates.applyingExtra(provider.systemPromptExtra, msgs);
    if (!mounted) return;
    if (!await PromptGuard.authorize(
      context,
      totalChars: msgs.totalContentChars,
    )) {
      return;
    }

    setState(() {
      _streaming = true;
      _error = null;
      _streamingBuffer = '';
    });
    _cancel = CancelToken();
    _progress.begin();
    await _enableWakelockSafely();

    final raw = StringBuffer();
    try {
      final client = await createClientForProvider(
        provider,
        ref.read(apiKeyVaultProvider),
      );
      await for (final ev in client.streamChat(
        msgs,
        config: GenerationConfig(
          temperature: provider.temperature,
          maxTokens: provider.maxTokens,
        ),
        cancelToken: _cancel,
      )) {
        _progress.handle(ev);
        if (ev is ContentDelta) raw.write(ev.text);
      }
      if (_cancel?.isCancelled ?? false) return;

      final outcome = engine.settle(
        kind: kind,
        raw: raw.toString(),
        chapterNameTargetIndex: chapterNameVolIdx,
      );
      await _persistCreationState();

      if (outcome.error != null) {
        setState(() => _error = outcome.error);
      }
      if (outcome.message != null) {
        await _appendMessage('assistant', outcome.message!);
      }

      if (mounted) {
        setState(() => _streaming = false);
      }
      _progress.finish();
      await _disableWakelockSafely();

      if (outcome.nextStep == CreationNextStep.requestStructure) {
        await _runCreationStream(CreationStreamKind.structure);
      } else if (outcome.autoNext && mounted) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (mounted && engine.state.autoContinue) {
          await _runCreationStream(kind);
        }
      }
      return;
    } catch (e) {
      if (mounted) setState(() => _error = '请求失败：$e');
    } finally {
      _progress.finish();
      await _disableWakelockSafely();
      if (mounted) setState(() => _streaming = false);
    }
  }

  Future<void> _confirmAndPersistBlueprint() async {
    final engine = _engine;
    final bp = engine?.state.blueprint;
    if (engine == null || bp == null) return;

    await CreationSessionEngine.persistBlueprintToDb(
      db: ref.read(appDatabaseProvider),
      novelId: widget.novelId,
      blueprint: bp,
    );
    engine.state.phase = CreationPhase.confirmed;
    if (_thread != null) {
      await ref.read(appDatabaseProvider).deleteCreationCache(_thread!.id);
    }
    if (mounted) {
      showZmSnackBar(context, '作品蓝图已落库，可以开始写作了！');
      widget.onCreationConfirmed?.call();
    }
  }

  // ---- 写作助手对话（含只读/读写 zm-patch） ----

  Future<void> _sendWritingAssistant() async {
    final provider = _activeProvider;
    final thread = _thread;
    if (provider == null || thread == null) return;

    final repo = ref.read(novelRepositoryProvider);
    final bundle = await repo.loadBundle(widget.novelId);
    if (bundle == null) return;
    final lib = ref.read(promptLibraryProvider);

    final styleCard = await widget.resolveStyleCard?.call(bundle);
    final rwProtocol = _accessMode == AssistantAccessMode.readWrite
        ? lib.resolvedText(PromptID.assistantReadWrite)
        : null;
    final r18Text = bundle.novel.r18Enabled
        ? await lib.r18Supplement(bundle.novel.synopsis)
        : null;

    final budget = PromptTemplates.adjustedInputBudget(
      provider.contextBudgetChars,
      [rwProtocol, r18Text, styleCard, provider.systemPromptExtra],
    );
    final refCtx = ContextBuilder.buildAssistantContext(
      bundle: bundle,
      budgetChars: budget,
    );

    var system = PromptTemplates.writingAssistantSystem(
      library: lib,
      title: bundle.novel.title,
      synopsis: bundle.novel.synopsis,
      styleGuide: bundle.novel.styleGuide,
      styleCard: styleCard,
    );
    if (refCtx.rendered.isNotEmpty) {
      system += '\n\n【当前作品档案】\n${refCtx.rendered}';
    }
    system += '\n\n${AssistantSearchProtocol.systemInstruction}';

    final dbMsgs = await ref.read(appDatabaseProvider).getChatMessages(thread.id);
    final recent = dbMsgs.length > 12
        ? dbMsgs.sublist(dbMsgs.length - 12)
        : dbMsgs;

    var msgs = <LLMMessage>[
      LLMMessage(role: LLMRole.system, content: system),
      for (final m in recent)
        LLMMessage(
          role: m.role == 'user' ? LLMRole.user : LLMRole.assistant,
          content: m.content.length > PromptLimits.historyMessageCap
              ? m.content.substring(0, PromptLimits.historyMessageCap)
              : m.content,
        ),
    ];
    msgs = PromptTemplates.applyingExtra(rwProtocol, msgs);
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
      _streaming = true;
      _error = null;
      _streamingBuffer = '';
      _pendingPatch = null;
    });
    _cancel = CancelToken();
    _progress.begin();
    await _enableWakelockSafely();

    try {
      final client = await createClientForProvider(
        provider,
        ref.read(apiKeyVaultProvider),
      );
      var activeMsgs = List<LLMMessage>.from(msgs);
      var finalText = '';

      // 最多支持 2 轮本地按需查书（zm-search），每轮 <30ms，字节级复用静态前缀命中 KV Cache
      for (var searchRound = 0; searchRound <= 2; searchRound++) {
        final buf = StringBuffer();
        await for (final ev in client.streamChat(
          activeMsgs,
          config: GenerationConfig(
            temperature: provider.temperature,
            maxTokens: provider.maxTokens,
          ),
          cancelToken: _cancel,
        )) {
          _progress.handle(ev);
          if (ev is ContentDelta) {
            buf.write(ev.text);
            if (mounted) setState(() => _streamingBuffer = buf.toString());
          }
        }
        if (_cancel?.isCancelled ?? false) return;

        final roundText = buf.toString().trim();
        final queries = AssistantSearchProtocol.extractQueries(roundText);
        if (queries.isNotEmpty && searchRound < 2) {
          if (mounted) {
            setState(
              () => _streamingBuffer = '正在本地查书核对：${queries.join("、")}…',
            );
          }
          final evidence = await _runLocalBookSearch(bundle, queries);
          activeMsgs = [
            ...activeMsgs,
            LLMMessage(role: LLMRole.assistant, content: roundText),
            LLMMessage(
              role: LLMRole.user,
              content:
                  '【本地查书返回原文证据】\n$evidence\n\n请基于以上真实原文证据直接回答用户问题（不要再输出 zm-search，除非仍有关键缺漏）。',
            ),
          ];
          continue;
        }
        finalText = AssistantSearchProtocol.stripSearchBlock(roundText);
        break;
      }

      if (finalText.isNotEmpty) {
        if (_accessMode == AssistantAccessMode.readWrite) {
          final extracted = AssistantPatch.extract(finalText);
          await _appendMessage(
            'assistant',
            extracted.cleanedText.isEmpty
                ? '已生成设定变更提案，请审阅下方卡片：'
                : extracted.cleanedText,
          );
          if (extracted.patch != null) {
            final latestBundle = await repo.loadBundle(widget.novelId);
            if (latestBundle != null && mounted) {
              setState(() {
                _pendingPatch = extracted.patch;
                _pendingPatchLines = extracted.patch!.describe(latestBundle);
              });
            }
          }
        } else {
          await _appendMessage('assistant', finalText);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '助手请求失败：$e');
    } finally {
      _progress.finish();
      await _disableWakelockSafely();
      if (mounted) {
        setState(() {
          _streaming = false;
          _streamingBuffer = '';
        });
      }
    }
  }

  Future<String> _runLocalBookSearch(
    NovelBundle bundle,
    List<String> queries,
  ) async {
    final chapters = <IndexedChapter>[];
    var idx = 1;
    for (final ch in bundle.allChaptersInOrder) {
      if (ch.chapter.content.trim().isEmpty) continue;
      chapters.add(
        IndexedChapter(
          chapterNo: idx++,
          title: '${ch.volumeName} · ${ch.chapter.title}',
          body: ch.chapter.content,
        ),
      );
    }

    NovelLocalIndexer? sourceIndexer;
    final srcId = bundle.novel.sourceProfileId;
    if (srcId != null && srcId.isNotEmpty) {
      final rawSource = await ref
          .read(blobStoreProvider)
          .loadText(BlobKinds.continuation, srcId);
      if (rawSource != null && rawSource.isNotEmpty) {
        sourceIndexer = NovelLocalIndexer.fromRawText(rawSource);
      }
    }
    final novelIndexer = NovelLocalIndexer.fromChapters(chapters);

    final out = StringBuffer();
    for (final q in queries) {
      out.writeln('■ 关键词「$q」：');
      final novelHits = novelIndexer.grepSpan(q, earliestHits: 1, latestHits: 2);
      final srcHits =
          sourceIndexer?.grepSpan(q, earliestHits: 1, latestHits: 2) ?? const [];
      if (novelHits.isEmpty && srcHits.isEmpty) {
        out.writeln('  （未在当前作品及关联原作中检索到精确匹配）');
      } else {
        for (final h in novelHits) {
          out.writeln('  [本作] ${h.format()}');
        }
        for (final h in srcHits) {
          out.writeln('  [原作] ${h.format()}');
        }
      }
    }
    return out.toString().trim();
  }

  Future<void> _applyPatch() async {
    final patch = _pendingPatch;
    if (patch == null) return;
    final bundle = await ref
        .read(novelRepositoryProvider)
        .loadBundle(widget.novelId);
    if (bundle == null) return;
    final results = await patch.applyToDb(
      db: ref.read(appDatabaseProvider),
      bundle: bundle,
    );
    setState(() {
      _pendingPatch = null;
      _pendingPatchLines = const [];
    });
    if (mounted) {
      showZmSnackBar(context, results.join('；'));
    }
  }

  Future<void> _toggleAccessMode() async {
    final next = _accessMode == AssistantAccessMode.readOnly
        ? AssistantAccessMode.readWrite
        : AssistantAccessMode.readOnly;
    setState(() => _accessMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessMode, next.name);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final thread = _thread;
    if (thread == null) return const SizedBox.shrink();

    final db = ref.watch(appDatabaseProvider);
    final activeProvider = _sessionProvider ?? ref.watch(defaultProviderProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 顶栏（清晰模型胶囊 + 清空对话）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isCreation ? Icons.auto_awesome_rounded : Icons.chat_rounded,
                size: 18,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _isCreation ? '立项共创助手' : '写作助手',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              ActionChip(
                avatar: const Icon(Icons.memory_rounded, size: 15),
                label: Text(
                  activeProvider?.modelName ?? '未配模型',
                  style: const TextStyle(fontSize: 12),
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
              if (!_isCreation)
                IconButton(
                  tooltip: '清空对话记录',
                  icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  onPressed: () async {
                    final ok = await showZmConfirmDialog(
                      context,
                      title: '清空助手对话？',
                      message: '不会影响作品设定与正文。',
                      confirmLabel: '清空',
                      destructive: true,
                    );
                    if (ok) await db.clearChatMessages(thread.id);
                  },
                ),
            ],
          ),
        ),

        if (_isCreation && _engine != null)
          CreationStageBar(phase: _engine!.state.phase),

        // 聊天消息流
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: db.watchChatMessages(thread.id),
            builder: (context, snap) {
              final msgs = snap.data ?? const [];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(14),
                    itemCount: msgs.length + (_streamingBuffer.isNotEmpty ? 1 : 0),
                    itemBuilder: (_, idx) {
                      if (idx == msgs.length) {
                        return _Bubble(
                          isUser: false,
                          text: _streamingBuffer,
                        );
                      }
                      final m = msgs[idx];
                      return _Bubble(isUser: m.role == 'user', text: m.content);
                    },
                  ),
                ),
              );
            },
          ),
        ),

        // 立项交互卡片区
        if (_isCreation && _engine != null) ...[
          if (_engine!.state.phase == CreationPhase.proposing &&
              _engine!.state.proposal != null)
            StructureProposalCard(
              proposal: _engine!.state.proposal!,
              busy: _streaming,
              onConfirm: () =>
                  _runCreationStream(CreationStreamKind.foundation),
            ),
          if ((_engine!.state.phase == CreationPhase.blueprintReady ||
                  _engine!.state.phase == CreationPhase.outlining) &&
              _engine!.state.blueprint != null)
            BlueprintActionPanel(
              state: _engine!.state,
              progress: _engine!.outlineProgress,
              busy: _streaming,
              onGenerateVolumeBatch: () =>
                  _runCreationStream(CreationStreamKind.volumeBatch),
              onGenerateChapterBatch: () =>
                  _runCreationStream(CreationStreamKind.chapterBatch),
              onGenerateChapterNames: (volIdx) => _runCreationStream(
                CreationStreamKind.chapterNames,
                chapterNameVolIdx: volIdx,
              ),
              onToggleAutoContinue: (v) {
                setState(() => _engine!.state.autoContinue = v);
                _persistCreationState();
              },
              onChaptersPerBatchChanged: (n) {
                setState(() => _engine!.state.chaptersPerBatch = n);
                _persistCreationState();
              },
              onEditBlueprint: () async {
                await showBlueprintEditorDialog(
                  context,
                  blueprint: _engine!.state.blueprint!,
                  onChanged: () {
                    setState(() {});
                    _persistCreationState();
                  },
                );
              },
              onConfirmPersist: _confirmAndPersistBlueprint,
            ),
        ],

        // 写作助手 zm-patch 提案确认卡
        if (!_isCreation && _pendingPatch != null)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: cs.primaryContainer.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _pendingPatch!.summary ?? '写作助手提议修改以下设定',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final line in _pendingPatchLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $line', style: const TextStyle(fontSize: 12.5)),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _pendingPatch = null),
                        child: const Text('忽略'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _applyPatch,
                        child: const Text('确认应用'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        if (_streaming || _error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                if (_streaming) StreamingStatusChip(tracker: _progress),
                if (_error != null)
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12, color: cs.error),
                    ),
                  ),
              ],
            ),
          ),

        // 底部输入胶囊（写作助手仅在此保留唯一的只读/读写权限胶囊，杜绝重复开关）
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!_isCreation) ...[
                    ActionChip(
                      avatar: Icon(
                        _accessMode == AssistantAccessMode.readWrite
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        size: 16,
                        color: _accessMode == AssistantAccessMode.readWrite
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                      label: Text(
                        _accessMode == AssistantAccessMode.readWrite
                            ? '可改设定'
                            : '只读',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: _toggleAccessMode,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: _isCreation
                            ? '回答澄清问题，或输入对结构/蓝图的修订意见…'
                            : '向写作助手提问或提出设定修改需求…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusCapsule,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _sendInput(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_streaming)
                    IconButton.filledTonal(
                      tooltip: '停止生成',
                      icon: const Icon(Icons.stop_rounded),
                      onPressed: () {
                        _cancel?.cancel();
                        if (_engine != null) {
                          _engine!.state.autoContinue = false;
                        }
                      },
                    )
                  else
                    IconButton.filled(
                      tooltip: '发送',
                      icon: const Icon(Icons.arrow_upward_rounded),
                      onPressed: _sendInput,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isUser, required this.text});
  final bool isUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isUser
        ? cs.primary.withValues(alpha: isDark ? 0.72 : 0.92)
        : cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.65 : 0.75);
    final fg = isUser ? cs.onPrimary : cs.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTokens.radiusBubble),
            topRight: const Radius.circular(AppTokens.radiusBubble),
            bottomLeft: Radius.circular(
              isUser ? AppTokens.radiusBubble : AppTokens.radiusTail,
            ),
            bottomRight: Radius.circular(
              isUser ? AppTokens.radiusTail : AppTokens.radiusBubble,
            ),
          ),
        ),
        child: SelectableText(
          text,
          style: TextStyle(color: fg, fontSize: 14, height: 1.55),
        ),
      ),
    );
  }
}
