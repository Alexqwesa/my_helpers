import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_helpers/features/route_chores.dart';
import 'package:my_helpers/my_helpers.dart';
import 'package:riverpod/riverpod.dart';

final navigatorKey = GlobalKey<NavigatorState>();
class RoutePersistenceObserver extends RouteObserver<PageRoute<dynamic>> {
  RoutePersistenceObserver(this.read);

  final T Function<T>(ProviderListenable<T> provider) read;

  void _persistFromRoute(Route<dynamic>? route) {
    final status = read(authStatusProvider);
    if (status != AuthStatus.authenticated) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      String? path;

      // 1) If this is a "real" PageRoute with a meaningful name, use it.
      if (route is PageRoute && route.settings.name != null) {
        path = route.settings.name;
      }

      // 2) Otherwise, ask GoRouter for its current matched location.
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        final router = GoRouter.of(ctx);
        final matches = router.routerDelegate.currentConfiguration;
        if (matches.isNotEmpty) {
          // This is basically the "current screen" path.
          path = matches.last.matchedLocation;
        }
      }

      if (path == null) return;
      if (!path.startsWith('/')) path = '/$path';

      final current = read(currentRouteProvider);
      if (current != path) {
        if (path.contains(':')) path = '/';
        read(currentRouteProvider.notifier).set(path);
      }
    });
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _persistFromRoute(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _persistFromRoute(previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _persistFromRoute(newRoute);
  }
}
