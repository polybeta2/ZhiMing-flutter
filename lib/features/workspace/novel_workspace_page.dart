import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/database/novel_repository.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/models/novel_domain.dart';
import '../editor/auto_write_sheet.dart';
import '../editor/chapter_editor_widget.dart';
import '../outline/outline_and_foreshadow_view.dart';
import '../settings_book/book_settings_view.dart';
import 'stats_and_export_sheet.dart';

/// 作品工作台（响应式收口设计）：
/// - 顶栏清晰 4 分区：写作 / 大纲与伏笔 / 设定集 / 助手 + 右上角「统计与导出」图标
/// - Windows/桌面（>=1024dp）写作区采用经典三栏：左卷章树 + 中增强编辑器 + 右可折叠参考栏
/// - 手机/窄屏采用沉浸式单栏，点击章节进入全屏编辑器
class NovelWorkspacePage extends ConsumerStatefulWidget {
  const NovelWorkspacePage({
    super.key,
    required this.novelId,
    this.assistantBuilder,
    this.onOpenStyleEval,
    this.resolveStyleCard,
    this.resolveSourceWindow,
  });

  final String novelId;
  final Widget Function(BuildContext context, String novelId)? assistantBuilder;
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

  @override
  ConsumerState<NovelWorkspacePage> createState() => _NovelWorkspacePageState();
}

class _NovelWorkspacePageState extends ConsumerState<NovelWorkspacePage> {
  int _section = 0; // 0: 写作, 1: 大纲与伏笔, 2: 设定集, 3: 助手
  String? _selectedChapterId;
  bool _showRightRef = true;
  bool _checkedInitialCreation = false;

  @override
  void initState() {
    super.initState();
    _initSelection();
  }

  Future<void> _initSelection() async {
    final repo = ref.read(novelRepositoryProvider);
    final pendingCreation = await repo.hasPendingCreationThread(widget.novelId);
    if (!mounted) return;
    if (pendingCreation && !_checkedInitialCreation) {
      _checkedInitialCreation = true;
      setState(() => _section = 3);
      return;
    }
    _checkedInitialCreation = true;
    final bundle = await repo.loadBundle(widget.novelId);
    if (!mounted || bundle == null) return;
    final all = bundle.allChaptersInOrder;
    if (all.isNotEmpty && _selectedChapterId == null) {
      // 优先选中最近编辑的非原作章，否则第一章
      final editable = all.where((c) => !c.chapter.isOriginal).toList();
      final target = editable.isNotEmpty ? editable.last : all.first;
      setState(() => _selectedChapterId = target.chapter.id);
    }
  }

  void _openAutoWrite() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AutoWriteSheet(
        novelId: widget.novelId,
        resolveStyleCard: widget.resolveStyleCard == null
            ? null
            : (b) =>
                  widget.resolveStyleCard!(b, const FollowBookStyle(), 'writing'),
        resolveSourceWindow: widget.resolveSourceWindow,
      ),
    );
  }

  void _openStatsExport() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StatsAndExportSheet(novelId: widget.novelId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncNovel = ref.watch(novelStreamProvider(widget.novelId));
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppTokens.desktopBreakpoint;

    return asyncNovel.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ZmEmptyState(
          icon: Icons.error_outline,
          title: '加载作品失败',
          description: '$e',
        ),
      ),
      data: (novel) {
        if (novel == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ZmEmptyState(
              icon: Icons.book_outlined,
              title: '作品不存在或已被删除',
            ),
          );
        }

        final sectionSwitcher = SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('写作')),
            ButtonSegment(value: 1, label: Text('大纲伏笔')),
            ButtonSegment(value: 2, label: Text('设定集')),
            ButtonSegment(value: 3, label: Text('助手')),
          ],
          selected: {_section},
          onSelectionChanged: (s) => setState(() => _section = s.first),
        );

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: '返回书架',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/library');
                }
              },
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    novel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (novel.r18Enabled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTokens.r18Accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'R18',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.r18Accent,
                      ),
                    ),
                  ),
                ],
                if (isDesktop) ...[
                  const SizedBox(width: 24),
                  sectionSwitcher,
                ],
              ],
            ),
            actions: [
              IconButton(
                tooltip: '数据统计与导出',
                icon: const Icon(Icons.bar_chart_rounded),
                onPressed: _openStatsExport,
              ),
              const SizedBox(width: 4),
            ],
            bottom: isDesktop
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: sectionSwitcher,
                      ),
                    ),
                  ),
          ),
          body: switch (_section) {
            0 => _buildWritingSection(isDesktop),
            1 => OutlineAndForeshadowView(novelId: widget.novelId),
            2 => BookSettingsView(novelId: widget.novelId),
            _ =>
              widget.assistantBuilder?.call(context, widget.novelId) ??
                  const ZmEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: '立项共创 & 写作助手',
                    description: '将在 Phase 3 接入完整五阶段立项状态机与 zm-patch 写作助手。',
                  ),
          },
        );
      },
    );
  }

  Widget _buildWritingSection(bool isDesktop) {
    final chapterTree = _ChapterTreePane(
      novelId: widget.novelId,
      selectedChapterId: _selectedChapterId,
      onSelectChapter: (ch) {
        if (isDesktop) {
          setState(() => _selectedChapterId = ch.id);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(ch.title)),
                body: ChapterEditorWidget(
                  novelId: widget.novelId,
                  chapterId: ch.id,
                  onOpenStyleEval: widget.onOpenStyleEval,
                  resolveStyleCard: widget.resolveStyleCard,
                  resolveSourceWindow: widget.resolveSourceWindow,
                ),
              ),
            ),
          );
        }
      },
      onAutoWrite: _openAutoWrite,
    );

    if (!isDesktop) return chapterTree;

    return Row(
      children: [
        SizedBox(width: 248, child: chapterTree),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedChapterId == null
              ? const ZmEmptyState(
                  icon: Icons.edit_document,
                  title: '选择或新建一个章节开始写作',
                )
              : ChapterEditorWidget(
                  novelId: widget.novelId,
                  chapterId: _selectedChapterId!,
                  onOpenStyleEval: widget.onOpenStyleEval,
                  resolveStyleCard: widget.resolveStyleCard,
                  resolveSourceWindow: widget.resolveSourceWindow,
                  referencePaneOpen: _showRightRef,
                  onToggleReferencePane: () =>
                      setState(() => _showRightRef = !_showRightRef),
                ),
        ),
        if (_showRightRef && _selectedChapterId != null) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: 300,
            child: _DesktopReferencePane(
              novelId: widget.novelId,
              chapterId: _selectedChapterId!,
            ),
          ),
        ],
      ],
    );
  }
}

class _ChapterTreePane extends ConsumerWidget {
  const _ChapterTreePane({
    required this.novelId,
    required this.selectedChapterId,
    required this.onSelectChapter,
    required this.onAutoWrite,
  });

  final String novelId;
  final String? selectedChapterId;
  final ValueChanged<Chapter> onSelectChapter;
  final VoidCallback onAutoWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Text(
                '章节目录',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: '自动撰写流水线',
                icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                onPressed: onAutoWrite,
              ),
              IconButton(
                tooltip: '新增卷',
                icon: const Icon(Icons.create_new_folder_outlined, size: 19),
                onPressed: () =>
                    ref.read(novelRepositoryProvider).addVolume(novelId),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<Volume>>(
            stream: db.watchVolumes(novelId),
            builder: (context, snap) {
              final vols = snap.data ?? const [];
              if (vols.isEmpty) {
                return ZmEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: '暂无章节',
                  description: '先新增一卷或前往「助手」完成立项蓝图。',
                  action: FilledButton.tonal(
                    onPressed: () =>
                        ref.read(novelRepositoryProvider).addVolume(novelId),
                    child: const Text('新增第一卷'),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: vols.length,
                itemBuilder: (_, idx) {
                  final vol = vols[idx];
                  return StreamBuilder<List<Chapter>>(
                    stream: db.watchChaptersByVolume(vol.id),
                    builder: (context, chSnap) {
                      final chs = chSnap.data ?? const [];
                      return ExpansionTile(
                        initiallyExpanded: true,
                        dense: true,
                        title: Text(
                          vol.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: '新增章',
                          icon: const Icon(Icons.add, size: 17),
                          onPressed: () async {
                            final id = await ref
                                .read(novelRepositoryProvider)
                                .addChapter(novelId, vol.id);
                            final ch = await db.getChapter(id);
                            if (ch != null) onSelectChapter(ch);
                          },
                        ),
                        children: [
                          for (final ch in chs)
                            ListTile(
                              dense: true,
                              selected: ch.id == selectedChapterId,
                              selectedTileColor: cs.primary.withValues(
                                alpha: 0.1,
                              ),
                              title: Text(
                                ch.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                ch.isOriginal
                                    ? '原作 · ${ch.wordCount} 字'
                                    : '${ch.wordCount} 字',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => onSelectChapter(ch),
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 桌面三栏右侧实时对照栏（细纲与场景卡 / 活跃角色与未回收伏笔）
class _DesktopReferencePane extends ConsumerWidget {
  const _DesktopReferencePane({
    required this.novelId,
    required this.chapterId,
  });

  final String novelId;
  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '本章细纲'),
              Tab(text: '角色与伏笔'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                StreamBuilder<Chapter?>(
                  stream: db.watchChapter(chapterId),
                  builder: (context, snap) {
                    final ch = snap.data;
                    if (ch == null) return const SizedBox.shrink();
                    final cards = SceneCard.decodeList(ch.sceneCardsJson);
                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Text(
                          ch.isOriginal ? '原作章节信息' : '细纲',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        if ((ch.detailedOutline ?? '').trim().isNotEmpty)
                          Text(
                            ch.detailedOutline!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.55,
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        else if (ch.isOriginal)
                          StreamBuilder<List<Volume>>(
                            stream: db.watchVolumes(novelId),
                            builder: (context, volSnap) {
                              final vol = (volSnap.data ?? const [])
                                  .where((v) => v.id == ch.volumeId)
                                  .firstOrNull;
                              final volOutline = (vol?.outline ?? '').trim();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest
                                          .withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '本章为只读原作章，仅用于阅读与续写衔接锚定；请在左侧切换至后续卷（如「第一卷」）撰写新章。',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.45,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  if (volOutline.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      '原作剧情脉络总览',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      volOutline,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.55,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          )
                        else
                          Text(
                            '（尚未填写细纲，可前往「大纲伏笔」页补全）',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.55,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        if (cards.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            '场景卡',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          for (var i = 0; i < cards.length; i++)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  '卡${i + 1}\n目标：${cards[i].goal}\n阻力：${cards[i].obstacle}\n钩子：${cards[i].hook}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      '活跃角色',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<List<Character>>(
                      stream: db.watchCharacters(novelId),
                      builder: (_, snap) {
                        final list = (snap.data ?? const [])
                            .where((c) => c.isSceneRelevant)
                            .toList();
                        if (list.isEmpty) {
                          return Text(
                            '暂无活跃角色',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final c in list)
                              Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      if ((c.currentGoal ?? '').isNotEmpty)
                                        '目标：${c.currentGoal}',
                                      if ((c.currentLocation ?? '').isNotEmpty)
                                        '位置：${c.currentLocation}',
                                    ].join(' · '),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '未回收伏笔',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<List<Foreshadowing>>(
                      stream: db.watchForeshadowings(novelId),
                      builder: (_, snap) {
                        final list = (snap.data ?? const [])
                            .where((f) => f.status == 'open')
                            .toList();
                        if (list.isEmpty) {
                          return Text(
                            '暂无未回收伏笔',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final f in list)
                              Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    f.title,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  subtitle: (f.plannedResolve ?? '').isNotEmpty
                                      ? Text(
                                          '计划：${f.plannedResolve}',
                                          style: const TextStyle(fontSize: 11),
                                        )
                                      : null,
                                ),
                              ),
                          ],
                        );
                      },
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
}
