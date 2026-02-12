import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_helpers/features/riverpod_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

var isEmbeddedMode = false;

//////////////////////////////////////////////
// route chores - save current route to prefs, load from prefs or from uri(for web)
//////////////////////////////////////////////

final currentRouteProvider = StateNotifierProvider<_CurrentRoute, String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return _CurrentRoute(_CurrentRoute.getWebInitialRoute(prefs), ref);
});

class _CurrentRoute extends StateNotifier<String> {
  static final String name = '__AppCurrentRoutePath';

  _CurrentRoute(super.state, this._ref);

  final Ref _ref;

  void set(String path) {
    if (state == path) return;
    if ('/login' == path || '/splash' == path) return;
    state = path;
    _ref.read(sharedPrefsProvider).setString(_CurrentRoute.name, path);
  }

  static String getWebInitialRoute(SharedPreferences prefs) {
    if (kIsWeb && kReleaseMode) {
      final p = Uri.base.path;
      if (p.isEmpty) return '/';
      return p.startsWith('/') ? p : '/$p';
    }
    final saved = prefs.getString(_CurrentRoute.name) ?? '/';
    return saved.startsWith('/') ? saved : '/$saved';
  }
}

// Optional tri-state
enum AuthStatus { unknown, authenticated, unauthenticated }

String getNormalizeRequestedUri(String p) {
  if (p.isEmpty) return '/';
  if (!p.startsWith('/')) p = '/$p';
  if (p == '/login' || p == '/splash') return '/'; // ignore these
  return p;
}

final authStatusProvider = Provider<AuthStatus>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden in main()!');
  // final async = ref.watch(RefAuthEndpoint.getSelfRole);
  // return async.when(
  //   data: (m) => (m.userId > 0) ? AuthStatus.authenticated : AuthStatus.unauthenticated,
  //   loading: () => AuthStatus.unknown,
  //   error: (_, __) => AuthStatus.unauthenticated,
  // );
});

final requestedPathProvider = Provider<String>((ref) {
  // decide once at startup
  if (kIsWeb && isEmbeddedMode) {
    // one-shot from the browser URL; never updates later
    return getNormalizeRequestedUri(Uri.base.path);
  }
  // otherwise, use the saved route ONCE (no watch)
  return ref.read(currentRouteProvider);
});

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this.ref) {
    // Listen to auth changes; every change triggers a redirect re-evaluation
    _sub = ref.listen<AuthStatus>(authStatusProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref ref;
  late final ProviderSubscription<AuthStatus> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

void registerRouteSaver(GoRouter router, Ref ref, GoRouterRefreshNotifier refreshNotifier) {
  // Persist current route when authenticated.
  void handler() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final status = ref.read(authStatusProvider);
      if (status != AuthStatus.authenticated) return;
      final path = router.routeInformationProvider.value.uri.path;
      if (!ref.exists(currentRouteProvider)) return;
      ref.read(currentRouteProvider.notifier).set(path);
    });
  }

  router.routeInformationProvider.addListener(handler);

  ref.onDispose(() {
    router.routeInformationProvider.removeListener(handler);
    // refreshNotifier.dispose();
    // router.dispose();
  });
}
