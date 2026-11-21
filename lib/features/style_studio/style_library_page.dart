import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/database/novel_repository.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/llm/stream_progress.dart';
import '../../core/platform/background_keep_alive.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/security/api_key_vault.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/text_encoding.dart';
import '../../core/widgets/streaming_status_chip.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/models/style_models.dart';
import '../../domain/style/style_card_renderer.dart';
import '../../domain/style/style_distillation_service.dart';

/// 文风库主页面：蒸馏新档案、多档案融合、JSON 导入导出、档案详情编辑与追加增量蒸馏
class StyleLibraryPage extends ConsumerWidget {
  const StyleLibraryPage({super.key});

  Future<void> _openDistill(
    BuildContext context, {
    StyleProfileData? augmentTarget,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StyleDistillSheet(augmentTarget: augmentTarget),
    );
  }

  Future<void> _exportJson(
    BuildContext context,
    List<StyleProfileData> profiles,
  ) async {
    if (profiles.isEmpty) {
      showZmSnackBar(context, '当前没有可导出的文风档案');
      return;
    }
    final content = const JsonEncoder.withIndent(
      '  ',
    ).convert([for (final p in profiles) p.toJson()]);
    final name =
        'zhiming-styles-${DateTime.now().millisecondsSinceEpoch}.json';
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出全部文风档案',
        fileName: name,
      );
      if (path != null) {
        await File(path).writeAsString(content);
        if (context.mounted) showZmSnackBar(context, '已导出 ${profiles.length} 份文风档案');
      }
    } else {
      final tmp = await getTemporaryDirectory();
      final f = File(p.join(tmp.path, name));
      await f.writeAsString(content);
      await Share.shareXFiles([XFile(f.path)], subject: name);
    }
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = res?.files.single.path;
    if (path == null) return;
    try {
      final raw = jsonDecode(await File(path).readAsString());
      final list = raw is List ? raw : (raw is Map ? [raw] : const []);
      final db = ref.read(appDatabaseProvider);
      final existingIds = (await db.getStyleProfiles()).map((e) => e.id).toSet();
      var added = 0;
      var updated = 0;
      for (final item in list) {
        final profile = StyleProfileData.fromJson(item);
        if (existingIds.contains(profile.id)) {
          updated++;
        } else {
          added++;
        }
        await db.upsertStyleProfile(
          StyleProfilesCompanion.insert(
            id: profile.id,
            name: profile.name,
            payloadJson: profile.toJsonString(),
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (context.mounted) {
        showZmSnackBar(context, '导入成功：新增 $added 份，覆盖 $updated 份');
      }
    } catch (e) {
      if (context.mounted) showZmSnackBar(context, 'JSON 导入失败：$e', isError: true);
    }
  }

  Future<void> _openFusion(
    BuildContext context,
    WidgetRef ref,
    List<StyleProfileData> profiles,
  ) async {
    if (profiles.length < 2) {
      showZmSnackBar(context, '至少需要 2 份文风档案才能融合');
      return;
    }
    var baseId = profiles.first.id;
    var voiceId = baseId;
    var syntaxId = baseId;
    var dictionId = baseId;
    var rhythmId = baseId;
    var dialogueId = baseId;
    var emotionId = baseId;
    final nameCtrl = TextEditingController(text: '融合文风');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          Widget layerPicker(
            String label,
            String val,
            ValueChanged<String> onChanged,
          ) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DropdownButtonFormField<String>(
                initialValue: val,
                decoration: InputDecoration(labelText: label, isDense: true),
                items: [
                  for (final p in profiles)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) {
                  if (v != null) setModal(() => onChanged(v));
                },
              ),
            );
          }

          return AlertDialog(
            title: const Text('多档案按层融合'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: '新档案名称'),
                    ),
                    const SizedBox(height: 10),
                    layerPicker('基底档案（示范与小结）', baseId, (v) {
                      baseId = v;
                      voiceId = v;
                      syntaxId = v;
                      dictionId = v;
                      rhythmId = v;
                      dialogueId = v;
                      emotionId = v;
                    }),
                    layerPicker('叙事声音层', voiceId, (v) => voiceId = v),
                    layerPicker('句法节奏层', syntaxId, (v) => syntaxId = v),
                    layerPicker('词汇意象层', dictionId, (v) => dictionId = v),
                    layerPicker('场景节奏层', rhythmId, (v) => rhythmId = v),
                    layerPicker('对白潜台词层', dialogueId, (v) => dialogueId = v),
                    layerPicker('情绪载体层', emotionId, (v) => emotionId = v),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('生成融合档案'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      final base = profiles.firstWhere((p) => p.id == baseId);
      final fused = StyleFusion.fuse(
        name: nameCtrl.text,
        base: base,
        participants: profiles,
        choices: StyleFusionChoices(
          voiceId: voiceId,
          syntaxId: syntaxId,
          dictionId: dictionId,
          rhythmId: rhythmId,
          dialogueId: dialogueId,
          emotionId: emotionId,
        ),
      );
      if (fused != null) {
        await ref
            .read(appDatabaseProvider)
            .upsertStyleProfile(
              StyleProfilesCompanion.insert(
                id: fused.id,
                name: fused.name,
                payloadJson: fused.toJsonString(),
                updatedAt: DateTime.now(),
              ),
            );
        if (context.mounted) showZmSnackBar(context, '已生成融合档案《${fused.name}》');
      }
    }
    nameCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<StyleProfile>>(
      stream: db.watchStyleProfiles(),
      builder: (context, snap) {
        final rows = snap.data ?? const [];
        final profiles = [
          for (final r in rows)
            StyleProfileData.fromJson(jsonDecode(r.payloadJson)),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('文风库'),
            actions: [
              if (profiles.length >= 2)
                IconButton(
                  tooltip: '多档案按层融合',
                  icon: const Icon(Icons.merge_type_rounded),
                  onPressed: () => _openFusion(context, ref, profiles),
                ),
              PopupMenuButton<String>(
                tooltip: '导入 / 导出',
                onSelected: (v) {
                  if (v == 'import') _importJson(context, ref);
                  if (v == 'export') _exportJson(context, profiles);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.file_upload_outlined),
                      title: Text('导入 JSON 档案'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.file_download_outlined),
                      title: Text('导出全部为 JSON'),
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _openDistill(context),
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('蒸馏文风'),
              ),
              const SizedBox(width: AppTokens.s3),
            ],
          ),
          body: profiles.isEmpty
              ? ZmEmptyState(
                  icon: Icons.text_format_rounded,
                  title: '还没有文风档案',
                  description:
                      '导入小说样本（支持粘贴、txt 文件或书库已有作品），AI 自动蒸馏七层语言机制与反 AI 味风格卡，跨书复用。',
                  action: FilledButton.icon(
                    onPressed: () => _openDistill(context),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('开始蒸馏第一份文风'),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppTokens.s4),
                      itemCount: profiles.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppTokens.s3),
                      itemBuilder: (_, i) {
                        final p = profiles[i];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(AppTokens.s3),
                            title: Row(
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    '置信 ${p.confidence}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (p.fingerprintSummary.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    p.fingerprintSummary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (p.tags.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      for (final t in p.tags.take(6))
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            t,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: cs.primary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              onPressed: () async {
                                final ok = await showZmConfirmDialog(
                                  context,
                                  title: '删除文风档案「${p.name}」？',
                                  message: '所有绑定该档案的作品将自动解绑。',
                                  confirmLabel: '删除',
                                  destructive: true,
                                );
                                if (ok) {
                                  await db.deleteStyleProfileUnbinding(p.id);
                                }
                              },
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _StyleProfileDetailPage(
                                  profile: p,
                                  onAugment: () => _openDistill(
                                    context,
                                    augmentTarget: p,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _StyleDistillSheet extends ConsumerStatefulWidget {
  const _StyleDistillSheet({this.augmentTarget});
  final StyleProfileData? augmentTarget;

  @override
  ConsumerState<_StyleDistillSheet> createState() => _StyleDistillSheetState();
}

class _StyleDistillSheetState extends ConsumerState<_StyleDistillSheet> {
  int _sourceTab = 0; // 0: 粘贴, 1: 导入 txt, 2: 书库选书
  final _textCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _progress = StreamProgressTracker();

  String _loadedText = '';
  int _loadedChars = 0;
  String? _cachedRaw;
  bool _running = false;
  String _stageText = '';
  String? _error;
  CancelToken? _cancel;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    if (widget.augmentTarget != null) return;
    final jsonStr = await ref
        .read(appDatabaseProvider)
        .loadStyleDistillCache();
    if (jsonStr == null || !mounted) return;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _cachedRaw = map['analysisRaw']?.toString();
        _loadedText = map['sourceText']?.toString() ?? '';
        _loadedChars = _loadedText.length;
        _noteCtrl.text = map['sourceNote']?.toString() ?? '';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _progress.dispose();
    _textCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTxt() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md'],
    );
    final path = res?.files.single.path;
    if (path == null) return;
    final text = await TextEncoding.loadFile(path);
    if (!mounted) return;
    setState(() {
      _loadedText = text;
      _loadedChars = text.length;
      if (_noteCtrl.text.trim().isEmpty) {
        _noteCtrl.text = p.basenameWithoutExtension(path);
      }
    });
  }

  Future<void> _pickFromLibrary(Novel novel) async {
    final bundle = await ref.read(novelRepositoryProvider).loadBundle(novel.id);
    if (bundle == null || !mounted) return;
    final full = bundle.allChaptersInOrder
        .where((c) => c.chapter.content.trim().isNotEmpty)
        .map((c) => '${c.chapter.title}\n${c.chapter.content}')
        .join('\n\n');
    setState(() {
      _loadedText = full;
      _loadedChars = full.length;
      _noteCtrl.text = '书库《${novel.title}》';
    });
  }

  String get _effectiveText =>
      _sourceTab == 0 ? _textCtrl.text : _loadedText;

  Future<void> _start({bool useCache = false}) async {
    final provider = ref.read(defaultProviderProvider);
    if (provider == null) {
      setState(() => _error = '请先在「设置 → 模型提供商」配置模型');
      return;
    }
    final text = useCache ? _loadedText : _effectiveText;
    if (text.trim().length < 300) {
      setState(() => _error = '样本文本至少需要 300 字才能稳定提取文风机制');
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _stageText = '准备中…';
    });
    _cancel = CancelToken();
    _progress.begin();
    await BackgroundKeepAliveService.instance.acquire();

    try {
      final client = await createClientForProvider(
        provider,
        ref.read(apiKeyVaultProvider),
      );
      final service = StyleDistillationService(
        client: client,
        library: ref.read(promptLibraryProvider),
        providerExtra: provider.systemPromptExtra,
      );
      final db = ref.read(appDatabaseProvider);

      await for (final ev in service.distill(
        sourceText: text,
        sourceNote: _noteCtrl.text.trim(),
        cachedAnalysisRaw: useCache ? _cachedRaw : null,
        augmentTarget: widget.augmentTarget,
        cancelToken: _cancel,
      )) {
        switch (ev) {
          case StyleDistillStage(:final label):
            if (mounted) setState(() => _stageText = label);
          case StyleDistillStreamDelta(:final event):
            _progress.handle(event);
          case StyleDistillAnalysisReady(:final rawAnalysisJson):
            await db.saveStyleDistillCache(
              jsonEncode({
                'sourceText': text,
                'sourceNote': _noteCtrl.text.trim(),
                'analysisRaw': rawAnalysisJson,
              }),
            );
          case StyleDistillCompleted(:final profile):
            await db.upsertStyleProfile(
              StyleProfilesCompanion.insert(
                id: profile.id,
                name: profile.name,
                payloadJson: profile.toJsonString(),
                updatedAt: DateTime.now(),
              ),
            );
            await db.deleteStyleDistillCache();
            if (mounted) {
              showZmSnackBar(context, '文风档案《${profile.name}》已入库');
              Navigator.of(context).pop();
            }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _progress.finish();
      await BackgroundKeepAliveService.instance.release();
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final novels = ref.watch(novelsStreamProvider).valueOrNull ?? const [];
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(AppTokens.s4),
        children: [
          Text(
            widget.augmentTarget == null
                ? '蒸馏新文风档案'
                : '追加样本增量蒸馏 · ${widget.augmentTarget!.name}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_cachedRaw != null && !_running)
            Card(
              color: cs.primaryContainer.withValues(alpha: 0.4),
              child: ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('检测到上次中断的蒸馏（S2 机制分析已完成）'),
                subtitle: Text('来源：${_noteCtrl.text}（$_loadedChars 字）'),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await ref
                            .read(appDatabaseProvider)
                            .deleteStyleDistillCache();
                        setState(() => _cachedRaw = null);
                      },
                      child: const Text('放弃'),
                    ),
                    FilledButton(
                      onPressed: () => _start(useCache: true),
                      child: const Text('从 S3 恢复'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('粘贴样章')),
              ButtonSegment(value: 1, label: Text('导入 TXT')),
              ButtonSegment(value: 2, label: Text('书库选书')),
            ],
            selected: {_sourceTab},
            onSelectionChanged: _running
                ? null
                : (s) => setState(() => _sourceTab = s.first),
          ),
          const SizedBox(height: 12),
          if (_sourceTab == 0)
            TextField(
              controller: _textCtrl,
              minLines: 6,
              maxLines: 12,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '粘贴样本文本（当前 ${_textCtrl.text.length} 字）',
                hintText: '建议提供 3000 字以上或整本小说，只分析语言机制，不提取情节与设定…',
                alignLabelWithHint: true,
              ),
            )
          else if (_sourceTab == 1)
            Card(
              child: ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: Text(
                  _loadedChars > 0 ? '已载入文件（$_loadedChars 字）' : '选择本地 TXT / MD 文件',
                ),
                subtitle: const Text('自动探测 UTF-8 / UTF-16 / GBK 编码，百万字不卡顿'),
                trailing: FilledButton.tonal(
                  onPressed: _running ? null : _pickTxt,
                  child: const Text('选择文件'),
                ),
              ),
            )
          else
            Card(
              child: novels.isEmpty
                  ? const ListTile(title: Text('书库暂无作品'))
                  : Column(
                      children: [
                        for (final n in novels)
                          ListTile(
                            title: Text(n.title),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _running ? null : () => _pickFromLibrary(n),
                          ),
                      ],
                    ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: '来源备注（可选）',
              hintText: '例如：冷峻推理风样章',
            ),
          ),
          if (_running) ...[
            const SizedBox(height: 14),
            Text(_stageText, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                StreamingStatusChip(tracker: _progress),
                const Spacer(),
                TextButton(
                  onPressed: () => _cancel?.cancel(),
                  child: const Text('停止'),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running ? null : () => _start(),
            icon: const Icon(Icons.science_outlined),
            label: const Text('开始四阶段蒸馏'),
          ),
        ],
      ),
    );
  }
}

class _StyleProfileDetailPage extends ConsumerStatefulWidget {
  const _StyleProfileDetailPage({
    required this.profile,
    required this.onAugment,
  });

  final StyleProfileData profile;
  final VoidCallback onAugment;

  @override
  ConsumerState<_StyleProfileDetailPage> createState() =>
      _StyleProfileDetailPageState();
}

class _StyleProfileDetailPageState
    extends ConsumerState<_StyleProfileDetailPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _fpCtrl;
  late final TextEditingController _mustCtrl;
  late final TextEditingController _avoidCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
    _fpCtrl = TextEditingController(text: widget.profile.fingerprintSummary);
    _mustCtrl = TextEditingController(text: widget.profile.mustRules.join('\n'));
    _avoidCtrl = TextEditingController(
      text: widget.profile.avoidRules.join('\n'),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fpCtrl.dispose();
    _mustCtrl.dispose();
    _avoidCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = widget.profile;
    p.name = _nameCtrl.text.trim().isEmpty ? p.name : _nameCtrl.text.trim();
    p.fingerprintSummary = _fpCtrl.text.trim();
    p.mustRules = _mustCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    p.avoidRules = _avoidCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    p.updatedAt = DateTime.now();

    await ref
        .read(appDatabaseProvider)
        .upsertStyleProfile(
          StyleProfilesCompanion.insert(
            id: p.id,
            name: p.name,
            payloadJson: p.toJsonString(),
            updatedAt: p.updatedAt,
          ),
        );
    if (mounted) {
      showZmSnackBar(context, '文风档案已保存');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          TextButton.icon(
            onPressed: widget.onAugment,
            icon: const Icon(Icons.add_chart_rounded, size: 18),
            label: const Text('追加样本'),
          ),
          FilledButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: AppTokens.s3),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.s4),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s4),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: '档案名称'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _fpCtrl,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '风格指纹小结',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _mustCtrl,
                        minLines: 4,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: '必遵规则（每行一条）',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _avoidCtrl,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: '反面清单（每行一条）',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.s3),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '运行时注入预览（Writing Variant）',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        StyleCardRenderer.render(p, StyleCardVariant.writing),
                        style: const TextStyle(fontSize: 12.5, height: 1.55),
                      ),
                    ],
                  ),
                ),
              ),
              if (p.corrections.isNotEmpty) ...[
                const SizedBox(height: AppTokens.s3),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '增量修正日志（最近 ${p.corrections.length} 条）',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        for (final c in p.corrections.reversed.take(10))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '• ${c.field}: 「${c.before}」→「${c.after}」（${c.reason}）',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
