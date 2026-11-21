import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/novel_repository.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/models/novel_domain.dart';
import '../../domain/tools/export_service.dart';
import '../../domain/tools/statistics_service.dart';

/// 作品「统计与导出」统一面板（收口到作品顶栏图标，避免占主导航 Tab）
class StatsAndExportSheet extends ConsumerStatefulWidget {
  const StatsAndExportSheet({super.key, required this.novelId});
  final String novelId;

  @override
  ConsumerState<StatsAndExportSheet> createState() =>
      _StatsAndExportSheetState();
}

class _StatsAndExportSheetState extends ConsumerState<StatsAndExportSheet> {
  NovelBundle? _bundle;
  ExportFormat _format = ExportFormat.txt;
  int _scopeIdx = 0; // 0: 全书, 1: 单卷, 2: 仅大纲
  String? _selectedVolumeId;
  bool _onlyIncomplete = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(novelRepositoryProvider);
    await repo.ensureDailyStatsBaseline(widget.novelId);
    final bundle = await repo.loadBundle(widget.novelId);
    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _selectedVolumeId = bundle?.volumes.firstOrNull?.volume.id;
    });
  }

  Future<void> _exportNow() async {
    final bundle = _bundle;
    if (bundle == null) return;
    setState(() => _exporting = true);
    try {
      final scope = switch (_scopeIdx) {
        1 when _selectedVolumeId != null => SingleVolumeScope(_selectedVolumeId!),
        2 => const OutlineOnlyScope(),
        _ => const FullNovelScope(),
      };
      final text = ExportService.export(
        bundle: bundle,
        scope: scope,
        format: _format,
      );
      final name = ExportService.fileName(
        bundle: bundle,
        scope: scope,
        format: _format,
      );

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: '导出作品',
          fileName: name,
        );
        if (savePath != null) {
          await File(savePath).writeAsString(text);
          if (mounted) showZmSnackBar(context, '已导出到 $savePath');
        }
      } else {
        final tmp = await getTemporaryDirectory();
        final file = File(p.join(tmp.path, name));
        await file.writeAsString(text);
        await Share.shareXFiles([XFile(file.path)], subject: name);
      }
    } catch (e) {
      if (mounted) showZmSnackBar(context, '导出失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    if (bundle == null) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final stats = StatisticsService.calculate(bundle);
    final cs = Theme.of(context).colorScheme;
    final maxWords = stats.chapterWordCounts.isEmpty
        ? 1
        : stats.chapterWordCounts
              .map((e) => e.wordCount)
              .reduce((a, b) => a > b ? a : b)
              .clamp(1, 1 << 30);

    final displayedCounts = _onlyIncomplete
        ? stats.chapterWordCounts
              .where((e) => e.wordCount < StatisticsService.completedThreshold)
              .toList()
        : stats.chapterWordCounts;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => CustomScrollView(
        controller: scrollCtrl,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.s4,
              AppTokens.s4,
              AppTokens.s4,
              AppTokens.s2,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '数据统计与导出',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatMetric('全书总字数', '${stats.totalWordCount}', cs.primary),
                      _StatMetric('今日新增', '+${stats.todayWordCount}', Colors.green),
                      _StatMetric(
                        '章节完成度',
                        '${stats.completedChapters} / ${stats.totalChapters}',
                        Colors.indigo,
                      ),
                      _StatMetric(
                        '均章字数',
                        '${stats.averageChapterWords}',
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.s4),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '导出作品（3 范围 × 2 格式）',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: AppTokens.s3),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('全书')),
                              ButtonSegment(value: 1, label: Text('单卷')),
                              ButtonSegment(value: 2, label: Text('仅大纲')),
                            ],
                            selected: {_scopeIdx},
                            onSelectionChanged: (s) =>
                                setState(() => _scopeIdx = s.first),
                          ),
                          if (_scopeIdx == 1 && bundle.volumes.isNotEmpty) ...[
                            const SizedBox(height: AppTokens.s3),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedVolumeId,
                              decoration: const InputDecoration(labelText: '选择卷'),
                              items: [
                                for (final v in bundle.volumes)
                                  DropdownMenuItem(
                                    value: v.volume.id,
                                    child: Text(v.volume.name),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedVolumeId = v),
                            ),
                          ],
                          const SizedBox(height: AppTokens.s3),
                          SegmentedButton<ExportFormat>(
                            segments: const [
                              ButtonSegment(
                                value: ExportFormat.txt,
                                label: Text('TXT'),
                              ),
                              ButtonSegment(
                                value: ExportFormat.markdown,
                                label: Text('Markdown'),
                              ),
                            ],
                            selected: {_format},
                            onSelectionChanged: (s) =>
                                setState(() => _format = s.first),
                          ),
                          const SizedBox(height: AppTokens.s4),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _exporting ? null : _exportNow,
                              icon: const Icon(Icons.download_rounded),
                              label: Text(_exporting ? '导出中…' : '立即导出'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (stats.chapterWordCounts.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.s4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '各章字数分布（共 ${stats.totalChapters} 章 · 完成 ${stats.completedChapters} · 草稿 ${stats.draftChapters} · 空 ${stats.emptyChapters}）',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        FilterChip(
                          label: const Text('仅看短/空章', style: TextStyle(fontSize: 12)),
                          selected: _onlyIncomplete,
                          visualDensity: VisualDensity.compact,
                          onSelected: (v) =>
                              setState(() => _onlyIncomplete = v),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (displayedCounts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.s4,
                AppTokens.s2,
                AppTokens.s4,
                AppTokens.s4,
              ),
              sliver: SliverList.builder(
                itemCount: displayedCounts.length,
                itemBuilder: (context, index) {
                  final item = displayedCounts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 148,
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: item.wordCount / maxWords,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '${item.wordCount}',
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else if (stats.chapterWordCounts.isNotEmpty)
            const SliverPadding(
              padding: EdgeInsets.all(AppTokens.s4),
              sliver: SliverToBoxAdapter(
                child: Center(child: Text('所有章节均已达到完成字数标准')),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatMetric extends StatelessWidget {
  const _StatMetric(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
