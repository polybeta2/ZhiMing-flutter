import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/style/style_card_renderer.dart';
import '../../features/app_settings/appearance_settings_page.dart';
import '../../features/app_settings/developer_tools_page.dart';
import '../../features/app_settings/provider_edit_page.dart';
import '../../features/app_settings/provider_list_page.dart';
import '../../features/app_settings/settings_page.dart';
import '../../features/assistant/assistant_chat_view.dart';
import '../../features/editor/chapter_editor_widget.dart';
import '../../features/library/library_page.dart';
import '../../features/source_archive/source_injection_helper.dart';
import '../../features/source_archive/source_library_page.dart';
import '../../features/style_studio/style_eval_sheet.dart';
import '../../features/style_studio/style_library_page.dart';
import '../../features/workspace/novel_workspace_page.dart';
import '../database/novel_repository.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/library',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/styles',
                builder: (context, state) => const StyleLibraryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sources',
                builder: (context, state) => const SourceLibraryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'providers',
                    builder: (context, state) => const ProviderListPage(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const ProviderEditPage(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => ProviderEditPage(
                          providerId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'appearance',
                    builder: (context, state) =>
                        const AppearanceSettingsPage(),
                  ),
                  GoRoute(
                    path: 'developer',
                    builder: (context, state) => const DeveloperToolsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/novel/:novelId',
        builder: (context, state) => _WiredNovelWorkspacePage(
          novelId: state.pathParameters['novelId']!,
        ),
      ),
    ],
  );
});

class _WiredNovelWorkspacePage extends ConsumerWidget {
  const _WiredNovelWorkspacePage({required this.novelId});

  final String novelId;

  static StyleCardVariant _parseVariant(String raw) => switch (raw) {
    'outline' || 'compact' => StyleCardVariant.outline,
    'antiAI' || 'rewrite' => StyleCardVariant.antiAI,
    'eval' => StyleCardVariant.eval,
    _ => StyleCardVariant.writing,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bridge = ref.read(sourceAndStyleBridgeProvider);
    final repo = ref.read(novelRepositoryProvider);

    return NovelWorkspacePage(
      novelId: novelId,
      assistantBuilder: (ctx, id) => AssistantChatView(
        novelId: id,
        resolveStyleCard: (bundle) => bridge.resolveStyleCard(
          bundle.novel.activeStyleProfileId,
          variant: StyleCardVariant.outline,
        ),
        resolveSourceContext: (bundle) => bridge.resolveSourceContext(
          bundle.novel.sourceProfileId,
          maxChars: 6000,
        ),
      ),
      resolveStyleCard: (bundle, mode, variant) async {
        final effectiveId = switch (mode) {
          FollowBookStyle() => bundle.novel.activeStyleProfileId,
          OffSessionStyle() => null,
          CustomSessionStyle(:final profileId) => profileId,
        };
        if (effectiveId == null) return null;
        return bridge.resolveStyleCard(
          effectiveId,
          variant: _parseVariant(variant),
        );
      },
      resolveSourceWindow: (bundle, ch) {
        return bridge.resolveSourceWindow(
          bundle.novel.sourceProfileId,
          target: ch.volumeName,
          maxChars: 3000,
        );
      },
      onOpenStyleEval: (draftText, chapterTitle, provider, onApply) async {
        final bundle = await repo.loadBundle(novelId);
        final card =
            await bridge.resolveStyleCard(
              bundle?.novel.activeStyleProfileId,
              variant: StyleCardVariant.eval,
            ) ??
            '【通用文学体检基准】\n'
                '核心原则：克制说明腔、去 AI 翻译腔与套话，重视场景感、具象细节、节奏张力与人物潜台词。';
        if (!context.mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => FractionallySizedBox(
            heightFactor: 0.9,
            child: StyleEvalSheet(
              draft: draftText,
              chapterTitle: chapterTitle,
              evalCard: card,
              provider: provider,
              onApply: onApply,
            ),
          ),
        );
      },
    );
  }
}
