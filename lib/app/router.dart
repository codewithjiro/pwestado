import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/explore/presentation/explore_screen.dart';
import '../features/saved/presentation/saved_analyses_screen.dart';
import '../features/saved/presentation/saved_analysis_detail_screen.dart';
import '../shared/widgets/app_error_view.dart';

abstract final class AppRoutes {
  static const explore = '/';
  static const saved = '/saved';

  static String savedDetail(int id) => '$saved/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.explore,
    routes: [
      GoRoute(
        path: AppRoutes.explore,
        builder: (context, state) => const ExploreScreen(),
      ),
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
                  message: 'This link does not point to a saved analysis.',
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
