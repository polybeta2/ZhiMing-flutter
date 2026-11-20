import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/security/api_key_vault.dart';
import '../../core/storage/blob_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/text_encoding.dart';
import '../../core/widgets/streaming_status_chip.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/models/source_profile_models.dart';
import '../../domain/source/source_batch_helper.dart';
import '../../domain/source/source_scan_chunker.dart';
import '../../domain/style/style_chapter_sampler.dart';
import '../app_settings/model_selector_sheet.dart';
import 'source_scan_controller.dart';

/// 扫描进度对话框：含 praying.gif 动画、流式心跳、进度条、Token/ETA、暂停/换商续跑。
class SourceScanProgressDialog extends ConsumerStatefulWidget {
  const SourceScanProgressDialog({
    super.key,
    required this.sourceText,
    required this.title,
    required this.mode,
    required this.batchSize,
    required this.isContinuation,
    required this.initialProvider,
    this.presetProfileId,
  });

  final String sourceText;
  final String title;
  final ScanMode mode;
  final int batchSize;
  final bool isContinuation;
  final ProviderRecord initialProvider;
  final String? presetProfileId;

  static Future<SourceNovelProfileData?> show(
    BuildContext context, {
    required String sourceText,
    required String title,
    required ScanMode mode,
    int batchSize = 3,
    bool isContinuation = false,
    required ProviderRecord initialProvider,
    String? presetProfileId,
  }) {
    return showDialog<SourceNovelProfileData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SourceScanProgressDialog(
        sourceText: sourceText,
        title: title,
        mode: mode,
        batchSize: batchSize,
        isContinuation: isContinuation,
        initialProvider: initialProvider,
        presetProfileId: presetProfileId,
      ),
    );
  }

  @override
  ConsumerState<SourceScanProgressDialog> createState() =>
      _SourceScanProgressDialogState();
}

class _SourceScanProgressDialogState
    extends ConsumerState<SourceScanProgressDialog> {
  SourceScanController? _ctrl;
  late ProviderRecord _provider;
  String? _activeProfileId;

  @override
  void initState() {
    super.initState();
    _provider = widget.initialProvider;
    _activeProfileId = widget.presetProfileId ?? const Uuid().v4();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startOrResume());
  }

  Future<void> _startOrResume() async {
    try {
      final client = await createClientForProvider(
        _provider,
        ref.read(apiKeyVaultProvider),
      );
      if (!mounted) return;
      if (_ctrl == null) {
        _ctrl = SourceScanController(
          db: ref.read(appDatabaseProvider),
          blobs: ref.read(blobStoreProvider),
          client: client,
          provider: _provider,
        )..addListener(_onTick);
      } else {
        _ctrl!.updateProvider(_provider, client);
      }
      setState(() {});
      await _ctrl!.start(
        sourceText: widget.sourceText,
        title: widget.title,
        mode: widget.mode,
        batchSize: widget.batchSize,
        isContinuation: widget.isContinuation,
        presetProfileId: _activeProfileId,
      );
    } catch (e) {
      if (mounted) {
        showZmSnackBar(context, '初始化模型失败：$e', isError: true);
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _switchProvider() async {
    final picked = await showModelSelectorSheet(
      context,
      ref: ref,
      currentSessionProvider: _provider,
    );
    if (picked == null || !mounted) return;
    setState(() => _provider = picked);
    try {
      final client = await createClientForProvider(
        picked,
        ref.read(apiKeyVaultProvider),
      );
      _ctrl?.updateProvider(picked, client);
    } catch (e) {
      if (mounted) showZmSnackBar(context, '切换模型失败：$e', isError: true);
    }
  }

  String _formatEta(int? sec) {
    if (sec == null || sec <= 0) return '计算中…';
    if (sec < 60) return '约 $sec 秒';
    final min = sec ~/ 60;
    final rem = sec % 60;
    return '约 $min 分 $rem 秒';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    final phase = ctrl?.phase ?? ScanPhase.mapping;
    final total = ctrl?.totalChunks ?? 0;
    final done = ctrl?.doneChunks ?? 0;
    final ratio = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    final isRunning =
        phase == ScanPhase.mapping || phase == ScanPhase.reducing;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            phase == ScanPhase.done
                ? Icons.check_circle_outline
                : (phase == ScanPhase.failed
                      ? Icons.error_outline
                      : Icons.auto_awesome_outlined),
            color: phase == ScanPhase.done
                ? Colors.green
                : (phase == ScanPhase.failed
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.isContinuation
                  ? '续写深度分析 · ${widget.title}'
                  : '原作档案分析 · ${widget.title}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isRunning)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/animations/praying.gif',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                ),
              ),
            Text(
              ctrl?.statusDetail ??
                  switch (phase) {
                    ScanPhase.idle => '准备中…',
                    ScanPhase.mapping =>
                      widget.mode == ScanMode.evidence
                          ? '正在进行极速证据建档（本地索引 + 检索查证 + 前缀缓存）…'
                          : '正在逐批分析并滚动归并（${widget.mode.label} · 每批 ${widget.batchSize} 块）',
                    ScanPhase.reducing =>
                      widget.isContinuation
                          ? '正在深度归并人物现状、未回收伏笔与剧情弧…'
                          : '正在终归并全书人物、时间线与世界观…',
                    ScanPhase.paused => '已暂停（进度已自动保存到断点，可随时继续或更换模型）',
                    ScanPhase.done => '分析完成！档案已入库',
                    ScanPhase.failed => '分析中断（已完成块与阶段摘要已安全缓存）',
                  },
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: phase == ScanPhase.reducing
                  ? null
                  : (total > 0 ? ratio : null),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  widget.mode == ScanMode.evidence
                      ? '阶段 $done / $total'
                      : '分块 $done / $total',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  'Token ${((ctrl?.tokensIn ?? 0) / 1000).toStringAsFixed(1)}k 入'
                  '${(ctrl?.cachedTokens ?? 0) > 0 ? "（缓存 ${(ctrl!.cachedTokens / 1000).toStringAsFixed(1)}k）" : ""} / '
                  '${((ctrl?.tokensOut ?? 0) / 1000).toStringAsFixed(1)}k 出',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '模型：${_provider.name} (${_provider.modelName})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (phase == ScanPhase.mapping)
                  Text(
                    '预计剩余 ${_formatEta(ctrl?.estimatedRemainingSeconds)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            if (ctrl != null && isRunning) ...[
              const SizedBox(height: 10),
              StreamingStatusChip(tracker: ctrl.progress),
            ],
            if (ctrl?.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTokens.radiusInput),
                ),
                child: Text(
                  ctrl!.errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (isRunning)
          TextButton.icon(
            onPressed: () => ctrl?.pause(),
            icon: const Icon(Icons.pause_circle_outline, size: 18),
            label: const Text('暂停并保留断点'),
          ),
        if (phase == ScanPhase.paused || phase == ScanPhase.failed) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('稍后续跑'),
          ),
          TextButton.icon(
            onPressed: _switchProvider,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('切换模型'),
          ),
          FilledButton.icon(
            onPressed: _startOrResume,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('继续分析'),
          ),
        ],
        if (phase == ScanPhase.done)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(ctrl?.resultProfile),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('完成并使用'),
          ),
      ],
    );
  }
}

/// 批量复制外包分析对话框：把最耗 Token 的 Map 阶段外包给外部免费 AI App，最后在织命内完成 Reduce 归并。
class BatchCopyOutsourceDialog extends ConsumerStatefulWidget {
  const BatchCopyOutsourceDialog({
    super.key,
    required this.sourceText,
    required this.bookTitle,
    this.isContinuation = false,
  });

  final String sourceText;
  final String bookTitle;
  final bool isContinuation;

  static Future<SourceNovelProfileData?> show(
    BuildContext context, {
    required String sourceText,
    required String bookTitle,
    bool isContinuation = false,
  }) {
    return showDialog<SourceNovelProfileData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchCopyOutsourceDialog(
        sourceText: sourceText,
        bookTitle: bookTitle,
        isContinuation: isContinuation,
      ),
    );
  }

  @override
  ConsumerState<BatchCopyOutsourceDialog> createState() =>
      _BatchCopyOutsourceDialogState();
}

class _BatchCopyOutsourceDialogState
    extends ConsumerState<BatchCopyOutsourceDialog> {
  final String _pid = const Uuid().v4();
  final _pasteCtrl = TextEditingController();
  late final List<SourceScanChunk> _chunks;
  late final List<({int chapterNo, String body})> _chapterBlocks;

  int _batchSize = 20;
  final Set<int> _doneChapters = {};
  bool _copiedTip = false;
  String? _parseError;

  static const _batchOptions = [5, 10, 20, 30, 50];

  @override
  void initState() {
    super.initState();
    _chunks = SourceScanChunker.chunks(widget.sourceText, mode: ScanMode.full);
    final order = <int>[];
    final grouped = <int, String>{};
    for (final c in _chunks) {
      if (!grouped.containsKey(c.chapterIndex)) {
        order.add(c.chapterIndex);
        grouped[c.chapterIndex] = c.text;
      } else {
        grouped[c.chapterIndex] = '${grouped[c.chapterIndex]}\n\n${c.text}';
      }
    }
    _chapterBlocks = order
        .map((idx) => (chapterNo: idx + 1, body: grouped[idx] ?? ''))
        .toList();
  }

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  List<({int chapterNo, String body})> get _nextBatch {
    final pending = _chapterBlocks
        .where((b) => !_doneChapters.contains(b.chapterNo - 1))
        .toList();
    return pending.take(_batchSize).toList();
  }

  bool get _allDone =>
      _chapterBlocks.isNotEmpty &&
      _doneChapters.length >= _chapterBlocks.length;

  Future<void> _copyPrompt() async {
    final batch = _nextBatch;
    if (batch.isEmpty) return;
    final prompt = SourceBatchHelper.prompt(
      title: widget.bookTitle,
      chapters: batch
          .map((b) => BatchChapterInput(index: b.chapterNo, body: b.body))
          .toList(),
    );
    await Clipboard.setData(ClipboardData(text: prompt));
    if (mounted) {
      setState(() => _copiedTip = true);
      showZmSnackBar(context, '已复制本批提示词（${batch.length} 章，${prompt.length} 字）');
    }
  }

  Future<void> _submitBatch() async {
    final raw = _pasteCtrl.text.trim();
    if (raw.isEmpty) return;
    try {
      final parsed = SourceBatchHelper.parseBatchOutput(raw);
      final db = ref.read(appDatabaseProvider);
      for (final entry in parsed.entries) {
        final zeroBasedChapter = entry.key;
        final payload = entry.value.toJsonString();
        for (var pos = 0; pos < _chunks.length; pos++) {
          if (_chunks[pos].chapterIndex == zeroBasedChapter) {
            await db.markScanChunk(
              ScanChunksCompanion.insert(
                profileId: _pid,
                idx: pos,
                status: 'done',
                payloadJson: Value(payload),
                updatedAt: DateTime.now(),
              ),
            );
          }
        }
        _doneChapters.add(zeroBasedChapter);
      }
      setState(() {
        _copiedTip = false;
        _parseError = null;
        _pasteCtrl.clear();
      });
      if (mounted) {
        showZmSnackBar(context, '成功入库 ${parsed.length} 章微摘要');
      }
    } catch (_) {
      setState(() {
        _parseError = '未能解析出逐章 JSON 微摘要，请确认外部 AI 按提示词格式返回了 {"chapter": ...} 对象。';
      });
    }
  }

  Future<void> _startMerge() async {
    final provider = ref.read(defaultProviderProvider);
    if (provider == null) {
      showZmSnackBar(context, '请先在「设置 → 模型提供商」配置模型后再执行归并', isError: true);
      return;
    }
    final profile = await SourceScanProgressDialog.show(
      context,
      sourceText: widget.sourceText,
      title: widget.bookTitle,
      mode: ScanMode.full,
      batchSize: 3,
      isContinuation: widget.isContinuation,
      initialProvider: provider,
      presetProfileId: _pid,
    );
    if (mounted && profile != null) {
      Navigator.of(context).pop(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = _nextBatch;
    final rangeLabel = batch.isEmpty
        ? '已完成'
        : '第 ${batch.first.chapterNo}-${batch.last.chapterNo} 章';

    return AlertDialog(
      title: Text('批量复制外包分析 · ${widget.bookTitle}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '将耗 Token 的逐章提取外包给免费外部 AI（如 DeepSeek App / Gemini），再贴回此处入库，全部完成后在织命内自动归并。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('每批章数：'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _batchSize,
                    items: _batchOptions
                        .map(
                          (n) => DropdownMenuItem(value: n, child: Text('$n 章')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _batchSize = v);
                    },
                  ),
                  const Spacer(),
                  Text(
                    '进度 ${_doneChapters.length} / ${_chapterBlocks.length} 章',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!_allDone) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _copyPrompt,
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(
                        _copiedTip
                            ? '重新复制本批 ($rangeLabel)'
                            : '复制本批提示词 ($rangeLabel)',
                      ),
                    ),
                    if (_copiedTip)
                      const Text(
                        '已复制 ✓',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pasteCtrl,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: '粘贴外部 AI 返回的逐章 JSON',
                    hintText: '可原样粘贴（允许包含说明文字或代码块围栏，系统会自动提取）',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_parseError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _parseError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _submitBatch,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('提交本批微摘要'),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTokens.radiusInput),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已收集全部 ${_chapterBlocks.length} 章微摘要！',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _startMerge,
                        icon: const Icon(Icons.merge_type, size: 18),
                        label: const Text('开始在织命内归并生成档案'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(_allDone ? '关闭' : '取消'),
        ),
      ],
    );
  }
}

/// 续写小说导入向导：选择 txt（选定从第 X 章续写）或加载已有档案 → 输出续写档案。
class ContinuationImportDialog extends ConsumerStatefulWidget {
  const ContinuationImportDialog({super.key});

  static Future<SourceNovelProfileData?> show(BuildContext context) {
    return showDialog<SourceNovelProfileData>(
      context: context,
      builder: (_) => const ContinuationImportDialog(),
    );
  }

  @override
  ConsumerState<ContinuationImportDialog> createState() =>
      _ContinuationImportDialogState();
}

class _ContinuationImportDialogState
    extends ConsumerState<ContinuationImportDialog> {
  String? _bookTitle;
  List<SampleChapter> _chapters = const [];
  int _continueFrom = 1;
  bool _useBatchCopy = false;
  ScanMode _mode = ScanMode.evidence;
  int _batchSize = 3;
  bool _loadingFile = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _loadingFile = true);
    try {
      final text = await TextEncoding.loadFile(path);
      final chapters = StyleChapterSampler.split(text);
      if (chapters.isEmpty) {
        if (mounted) {
          showZmSnackBar(
            context,
            '未识别到章节标题（如「第X章」/「Chapter X」），请检查文件格式',
            isError: true,
          );
        }
        return;
      }
      final fileName = result!.files.single.name.replaceAll(
        RegExp(r'\.(txt|md)$', caseSensitive: false),
        '',
      );
      setState(() {
        _bookTitle = fileName;
        _chapters = chapters;
        _continueFrom = chapters.length;
      });
    } catch (e) {
      if (mounted) showZmSnackBar(context, '读取文件失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingFile = false);
    }
  }

  Future<void> _pickFromArchive() async {
    final rows = await ref.read(appDatabaseProvider).watchSourceProfiles().first;
    final profiles = rows
        .map((r) {
          try {
            return SourceNovelProfileData.fromJsonString(r.payloadJson);
          } catch (_) {
            return null;
          }
        })
        .whereType<SourceNovelProfileData>()
        .where((p) => p.scanState.isComplete)
        .toList();

    if (!mounted) return;
    if (profiles.isEmpty) {
      showZmSnackBar(context, '原作档案库中还没有已完成的档案');
      return;
    }

    final chosen = await showDialog<SourceNovelProfileData>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从已有档案加载'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: profiles.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = profiles[i];
              final isCont = p.continuationFromChapter != null;
              return ListTile(
                title: Text(p.title),
                subtitle: Text(
                  isCont
                      ? '续写深度档案 · 截至第 ${p.continuationFromChapter} 章'
                      : '同人精度档案 · ${p.meta.totalChapters} 章',
                ),
                trailing: Icon(
                  isCont ? Icons.edit_note : Icons.warning_amber_rounded,
                  color: isCont ? Colors.blue : Colors.orange,
                ),
                onTap: () => Navigator.of(ctx).pop(p),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;

    if (chosen.continuationFromChapter == null) {
      final proceed = await showZmConfirmDialog(
        context,
        title: '同人精度档案提醒',
        message:
            '「${chosen.title}」是常规同人精度档案，缺少续写专用的深度现状快照与未回收伏笔清单，续写衔接精度可能略低。是否仍要用于续写？',
        confirmLabel: '仍用于续写',
      );
      if (!proceed || !mounted) return;
    }
    Navigator.of(context).pop(chosen);
  }

  Future<void> _start() async {
    final title = _bookTitle ?? '未命名原作';
    final truncated = _chapters
        .take(_continueFrom)
        .map((c) => '${c.marker}\n${c.body}')
        .join('\n\n');

    SourceNovelProfileData? profile;
    if (_useBatchCopy) {
      profile = await BatchCopyOutsourceDialog.show(
        context,
        sourceText: truncated,
        bookTitle: title,
        isContinuation: true,
      );
    } else {
      final provider = ref.read(defaultProviderProvider);
      if (provider == null) {
        showZmSnackBar(context, '请先配置模型提供商，或切换为「批量复制外包」', isError: true);
        return;
      }
      profile = await SourceScanProgressDialog.show(
        context,
        sourceText: truncated,
        title: title,
        mode: _mode,
        batchSize: _batchSize,
        isContinuation: true,
        initialProvider: provider,
      );
    }
    if (mounted && profile != null) {
      Navigator.of(context).pop(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_chapters.isEmpty ? '续写小说导入' : '选择续写起点 · $_bookTitle'),
      content: SizedBox(
        width: 480,
        child: _chapters.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '导入断更、烂尾或自己未写完的小说 txt（自动识别 UTF-8 / GBK），选择从第几章开始续写；也可直接从原作档案库加载已有档案。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadingFile ? null : _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_loadingFile ? '读取并分章中…' : '导入本地小说 txt'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pickFromArchive,
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    label: const Text('从原作档案库加载已有档案'),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '共识别 ${_chapters.length} 章。默认从最后一章续写，选中间章将开启你的 IF 线（其后原文会被忽略）。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _continueFrom,
                      decoration: const InputDecoration(
                        labelText: '截至第几章（之后开始续写）',
                      ),
                      items: List.generate(
                        _chapters.length,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(
                            '第 ${i + 1} 章 · ${_chapters[i].marker}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) setState(() => _continueFrom = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('API 自动分析')),
                        ButtonSegment(value: true, label: Text('批量复制（外部 AI）')),
                      ],
                      selected: {_useBatchCopy},
                      onSelectionChanged: (s) =>
                          setState(() => _useBatchCopy = s.first),
                    ),
                    if (!_useBatchCopy) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<ScanMode>(
                              initialValue: _mode,
                              decoration: const InputDecoration(
                                labelText: '扫描档位',
                              ),
                              items: ScanMode.values
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _mode = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _batchSize,
                              decoration: const InputDecoration(
                                labelText: '每批块数',
                              ),
                              items: List.generate(
                                10,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(i == 0 ? '逐块 (1)' : '${i + 1} 块'),
                                ),
                              ),
                              onChanged: (v) {
                                if (v != null) setState(() => _batchSize = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        if (_chapters.isNotEmpty)
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: Text('分析第 1~$_continueFrom 章'),
          ),
      ],
    );
  }
}
