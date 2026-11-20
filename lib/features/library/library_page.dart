import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/database/novel_repository.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/zm_widgets.dart';
import 'novel_create_dialog.dart';

/// 书库首页：干净的作品卡片列表 + 搜索 + 唯一「新建作品」入口
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String _query = '';

  Future<void> _openCreateWizard() async {
    final createdId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const NovelCreateSheet(),
    );
    if (createdId != null && mounted) {
      context.push('/novel/$createdId');
    }
  }

  Future<void> _renameNovel(Novel novel) async {
    final ctrl = TextEditingController(text: novel.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名作品'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '书名'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName != null && newName.isNotEmpty) {
      await ref
          .read(novelRepositoryProvider)
          .updateNovelMeta(novel.id, title: newName);
    }
  }

  Future<void> _deleteNovel(Novel novel) async {
    final ok = await showZmConfirmDialog(
      context,
      title: '删除「${novel.title}」？',
      message: '作品下的全部卷章正文、快照、角色卡、世界观、伏笔与聊天记录将一并级联删除，无法恢复。',
      confirmLabel: '确认删除',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(appDatabaseProvider).deleteNovelCascade(novel.id);
    if (mounted) showZmSnackBar(context, '已删除《${novel.title}》');
  }

  @override
  Widget build(BuildContext context) {
    final asyncNovels = ref.watch(novelsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('织命 · 书库'),
        actions: [
          FilledButton.icon(
            onPressed: _openCreateWizard,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新建作品'),
          ),
          const SizedBox(width: AppTokens.s3),
        ],
      ),
      body: asyncNovels.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ZmEmptyState(
          icon: Icons.error_outline,
          title: '读取书库失败',
          description: '$e',
        ),
        data: (novels) {
          if (novels.isEmpty) {
            return ZmEmptyState(
              icon: Icons.auto_stories_outlined,
              title: '开始你的第一部长篇',
              description: '支持空白建书、一句话立项共创、完整思路规划、同人创作与小说续写。',
              action: FilledButton.icon(
                onPressed: _openCreateWizard,
                icon: const Icon(Icons.add),
                label: const Text('新建作品'),
              ),
            );
          }
          final filtered = _query.trim().isEmpty
              ? novels
              : novels
                    .where(
                      (n) =>
                          n.title.toLowerCase().contains(
                            _query.toLowerCase(),
                          ) ||
                          n.synopsis.toLowerCase().contains(
                            _query.toLowerCase(),
                          ),
                    )
                    .toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                children: [
                  if (novels.length >= 4)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.s4,
                        AppTokens.s2,
                        AppTokens.s4,
                        0,
                      ),
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '搜索书名或梗概…',
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 680;
                        if (filtered.isEmpty) {
                          return const ZmEmptyState(
                            icon: Icons.search_off,
                            title: '未找到匹配作品',
                          );
                        }
                        if (!isWide) {
                          return ListView.separated(
                            padding: const EdgeInsets.all(AppTokens.s4),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppTokens.s3),
                            itemBuilder: (_, i) => _NovelCard(
                              novel: filtered[i],
                              onTap: () =>
                                  context.push('/novel/${filtered[i].id}'),
                              onRename: () => _renameNovel(filtered[i]),
                              onDelete: () => _deleteNovel(filtered[i]),
                            ),
                          );
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.all(AppTokens.s4),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: AppTokens.s3,
                                crossAxisSpacing: AppTokens.s3,
                                mainAxisExtent: 108,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _NovelCard(
                            novel: filtered[i],
                            onTap: () =>
                                context.push('/novel/${filtered[i].id}'),
                            onRename: () => _renameNovel(filtered[i]),
                            onDelete: () => _deleteNovel(filtered[i]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NovelCard extends StatelessWidget {
  const _NovelCard({
    required this.novel,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Novel novel;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  Color get _badgeColor {
    if (novel.r18Enabled) return AppTokens.r18Accent;
    return AppTokens.parseHex(novel.accentColorHex) ??
        AppTokens.accentPresets.first.color;
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _badgeColor;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s3),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0.76)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.book_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTokens.s3),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            novel.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (novel.r18Enabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.r18Accent.withValues(
                                alpha: 0.12,
                              ),
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
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      novel.synopsis.trim().isEmpty
                          ? '暂无梗概'
                          : novel.synopsis.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(novel.updatedAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('重命名'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline, color: cs.error),
                      title: Text('删除', style: TextStyle(color: cs.error)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
