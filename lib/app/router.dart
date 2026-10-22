import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/explore/presentation/explore_screen.dart';
import '../shared/widgets/app_error_view.dart';

abstract final class AppRoutes {
  static const explore = '/';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.explore,
    routes: [
      GoRoute(
        path: AppRoutes.explore,
        builder: (context, state) => const ExploreScreen(),
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
