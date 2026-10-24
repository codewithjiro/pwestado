import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analysis/presentation/analyze_screen.dart';
import '../features/comparison/presentation/compare_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/saved/presentation/saved_analyses_screen.dart';
import '../features/saved/presentation/saved_analysis_detail_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../shared/widgets/app_error_view.dart';
import 'app_shell.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const explore = '/';
  static const analyze = '/analyze';
  static const compare = '/compare';
  static const saved = '/saved';

  static String savedDetail(int id) => '$saved/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    // Cold start only: the splash replaces itself with the map tab via
    // go(), and nothing navigates back to it. It sits outside the shell, so
    // it never shows the bottom navigation.
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const SplashScreen()),
      ),
      // Four tabs in an IndexedStack: every tab keeps its widget tree while
      // hidden, so the native Mapbox view is created once and never torn
      // down by tab switches.
      StatefulShellRoute.indexedStack(
        // Fades in over the splash; tab switches reuse this one page.
        pageBuilder: (context, state, shell) => CustomTransitionPage(
          key: const ValueKey('app-shell'),
          transitionDuration: const Duration(milliseconds: 380),
          transitionsBuilder: (context, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
          child: AppShell(shell: shell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.analyze,
                builder: (context, state) => const AnalyzeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.compare,
                builder: (context, state) => const CompareScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.saved,
                builder: (context, state) => const SavedAnalysesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) {
                        return AppErrorView(
                          title: 'Saved analysis not found',
                          message:
                              'This link does not point to a saved analysis.',
                          actionLabel: 'Back to saved analyses',
                          onAction: () => context.go(AppRoutes.saved),
                        );
                      }
                      return SavedAnalysisDetailScreen(id: id);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => AppErrorView(
      title: 'Page not found',
      message: 'There is nothing at "${state.uri}".',
      actionLabel: 'Back to map',
      onAction: () => context.go(AppRoutes.explore),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
