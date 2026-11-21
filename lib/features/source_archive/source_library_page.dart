import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/storage/blob_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/text_encoding.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/models/source_profile_models.dart';
import 'source_injection_helper.dart';
import 'source_profile_detail_dialog.dart';
import 'source_scan_dialogs.dart';

final sourceProfilesStreamProvider = StreamProvider<List<SourceProfile>>((ref) {
  return ref.watch(appDatabaseProvider).watchSourceProfiles();
});

final scanTasksStreamProvider = StreamProvider<List<ScanTask>>((ref) {
  return ref.watch(appDatabaseProvider).watchScanTasks();
});

/// 顶层「原作库」页：断点续跑横幅 + 导入原作分析（API 自动 / 批量复制外包）+ 续写导入 + 档案卡片列表。
class SourceLibraryPage extends ConsumerStatefulWidget {
  const SourceLibraryPage({super.key});

  @override
  ConsumerState<SourceLibraryPage> createState() => _SourceLibraryPageState();
}

class _SourceLibraryPageState extends ConsumerState<SourceLibraryPage> {
  Future<void> _importFanficSource() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    String decoded;
    try {
      decoded = await TextEncoding.loadFile(path);
    } catch (e) {
      if (mounted) showZmSnackBar(context, '读取文件失败：$e', isError: true);
      return;
    }
    if (!mounted) return;

    final defaultTitle = result!.files.single.name.replaceAll(
      RegExp(r'\.(txt|md)$', caseSensitive: false),
      '',
    );
    final titleCtrl = TextEditingController(text: defaultTitle);
    var useBatchCopy = false;
    var mode = ScanMode.evidence;
    var batchSize = 3;
    var concurrency = 3;

    final start = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('导入原作分析'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '已读取 ${decoded.length} 字（自动解码完成）',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '原作书名'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('API 自动扫描')),
                    ButtonSegment(value: true, label: Text('批量复制（外部 AI）')),
                  ],
                  selected: {useBatchCopy},
                  onSelectionChanged: (s) =>
                      setLocal(() => useBatchCopy = s.first),
                ),
                if (!useBatchCopy) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<ScanMode>(
                          initialValue: mode,
                          decoration: const InputDecoration(labelText: '扫描档位'),
                          items: ScanMode.values
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.label),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setLocal(() => mode = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: batchSize,
                          decoration: const InputDecoration(labelText: '每批块数'),
                          items: List.generate(
                            10,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(i == 0 ? '逐块 (1)' : '${i + 1} 块'),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null) setLocal(() => batchSize = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (mode != ScanMode.evidence) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: concurrency,
                      decoration: const InputDecoration(
                        labelText: '并发扫描通道数（提速用）',
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 路串行（最稳）')),
                        DropdownMenuItem(value: 2, child: Text('2 路并发')),
                        DropdownMenuItem(value: 3, child: Text('3 路并发（推荐）')),
                        DropdownMenuItem(value: 4, child: Text('4 路并发（极速）')),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => concurrency = v);
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('开始分析'),
            ),
          ],
        ),
      ),
    );
    final title = titleCtrl.text.trim().isEmpty
        ? defaultTitle
        : titleCtrl.text.trim();
    titleCtrl.dispose();
    if (start != true || !mounted) return;

    if (useBatchCopy) {
      final profile = await BatchCopyOutsourceDialog.show(
        context,
        sourceText: decoded,
        bookTitle: title,
      );
      if (mounted && profile != null) {
        showZmSnackBar(context, '已生成原作档案《${profile.title}》');
      }
    } else {
      final provider = ref.read(defaultProviderProvider);
      if (provider == null) {
        showZmSnackBar(context, '请先在「设置 → 模型提供商」配置模型', isError: true);
        return;
      }
      final profile = await SourceScanProgressDialog.show(
        context,
        sourceText: decoded,
        title: title,
        mode: mode,
        batchSize: batchSize,
        concurrency: concurrency,
        isContinuation: false,
        initialProvider: provider,
      );
      if (mounted && profile != null) {
        showZmSnackBar(context, '已生成原作档案《${profile.title}》');
      }
    }
  }

  Future<void> _openContinuationImport() async {
    final profile = await ContinuationImportDialog.show(context);
    if (profile == null || !mounted) return;
    final novelId = await ref
        .read(sourceAndStyleBridgeProvider)
        .createContinuationNovel(profile: profile);
    if (!mounted) return;
    showZmSnackBar(context, '已创建续写作品《${profile.title}》续写');
    context.push('/novel/$novelId');
  }

  Future<void> _resumeScanTask(ScanTask task) async {
    final blobs = ref.read(blobStoreProvider);
    final text = await blobs.loadText(BlobKinds.scanTask, task.profileId);
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      showZmSnackBar(context, '找不到该任务的原文缓存，建议放弃后重新导入', isError: true);
      return;
    }
    final provider = ref.read(defaultProviderProvider);
    if (provider == null) {
      showZmSnackBar(context, '请先配置模型提供商', isError: true);
      return;
    }
    await SourceScanProgressDialog.show(
      context,
      sourceText: text,
      title: task.title,
      mode: ScanMode.fromRaw(task.mode),
      batchSize: task.batchSize,
      isContinuation: task.isContinuation,
      initialProvider: provider,
      presetProfileId: task.profileId,
    );
  }

  Future<void> _discardScanTask(ScanTask task) async {
    final ok = await showZmConfirmDialog(
      context,
      title: '放弃未完成的分析任务？',
      message: '「${task.title}」的已完成分块缓存与原文临时文件将被清除。',
      confirmLabel: '放弃并清理',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(appDatabaseProvider).clearScanCheckpoints(task.profileId);
    await ref
        .read(blobStoreProvider)
        .delete(BlobKinds.scanTask, task.profileId);
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(sourceProfilesStreamProvider);
    final tasksAsync = ref.watch(scanTasksStreamProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('原作库'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: _openContinuationImport,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('续写导入'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _importFanficSource,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('导入原作分析'),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 响应式断点续跑横幅（彻底修复原版 B8 放弃任务不刷新问题）
          if (tasksAsync.valueOrNull != null &&
              tasksAsync.valueOrNull!.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              sliver: SliverList.separated(
                itemCount: tasksAsync.valueOrNull!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final task = tasksAsync.valueOrNull![index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history_toggle_off, color: cs.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '未完成的分析任务：${task.title}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                '${task.isContinuation ? "续写深度分析" : "原作同人分析"} · '
                                '${ScanMode.fromRaw(task.mode).label} · 共 ${task.totalChunks} 块',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _discardScanTask(task),
                          child: Text(
                            '放弃',
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.tonal(
                          onPressed: () => _resumeScanTask(task),
                          child: const Text('继续分析'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          profilesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                SliverFillRemaining(child: Center(child: Text('加载失败：$e'))),
            data: (rows) {
              if (rows.isEmpty) {
                return SliverFillRemaining(
                  child: ZmEmptyState(
                    icon: Icons.collections_bookmark_outlined,
                    title: '原作档案库还是空的',
                    description:
                        '导入任意长篇 txt 小说（自动识别 UTF-8 / GBK），通过滚动并发 Map-Reduce 或批量复制外包生成人物、时间线、世界观与伏笔档案，用于同人创作或断更续写。',
                    action: Wrap(
                      spacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _importFanficSource,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('导入原作分析'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openContinuationImport,
                          icon: const Icon(Icons.edit_note),
                          label: const Text('续写断更小说'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final profiles = rows
                  .map((r) {
                    try {
                      return SourceNovelProfileData.fromJsonString(
                        r.payloadJson,
                      );
                    } catch (_) {
                      return SourceNovelProfileData(
                        id: r.id,
                        title: r.title,
                        author: r.author,
                      );
                    }
                  })
                  .toList();

              return SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 176,
                  ),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final p = profiles[index];
                    final isCont = p.continuationFromChapter != null;
                    return ZmCard(
                      onTap: () => SourceProfileDetailDialog.show(
                        context,
                        profile: p,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (isCont ? Colors.indigo : cs.primary)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isCont
                                      ? '续写 · 第${p.continuationFromChapter}章'
                                      : '同人档案',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: isCont
                                            ? Colors.indigo
                                            : cs.primary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${p.meta.totalChapters} 章 · '
                            '人物 ${p.characters.length} · '
                            '事件 ${p.timeline.length} · '
                            '世界观 ${p.worldbuilding.length}'
                            '${p.openThreads.isNotEmpty ? " · 伏笔 ${p.openThreads.length}" : ""}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Token ${(p.scanState.tokensIn / 1000).toStringAsFixed(1)}k 入 / '
                            '${(p.scanState.tokensOut / 1000).toStringAsFixed(1)}k 出'
                            '${p.styleProfileId != null ? " · 已绑文风" : ""}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => SourceProfileDetailDialog.show(
                                  context,
                                  profile: p,
                                ),
                                child: const Text('查看/编辑'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton.tonal(
                                onPressed: () async {
                                  final nid = await ref
                                      .read(sourceAndStyleBridgeProvider)
                                      .createFanficNovel(
                                        profile: p,
                                        styleProfileId: p.styleProfileId,
                                      );
                                  if (context.mounted) {
                                    context.push('/novel/$nid');
                                  }
                                },
                                child: const Text('同人立项'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
