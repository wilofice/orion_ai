import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Adjust paths as per your project structure
import '../chat/chat_screen.dart';
import '../events/event_list_screen.dart';
import '../preferences/parameters_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../navigation/main_tabs_screen.dart';

// Navigator keys
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKeyChat = GlobalKey<NavigatorState>(debugLabel: 'shellChat');
final GlobalKey<NavigatorState> _shellNavigatorKeyEvent = GlobalKey<NavigatorState>(debugLabel: 'shellEvent');
final GlobalKey<NavigatorState> _shellNavigatorKeyPrefs = GlobalKey<NavigatorState>(debugLabel: 'shellPrefs');


class AppRouter {
  final AuthProvider authProvider;
  GoRouter? _router;

  AppRouter({required this.authProvider});

  GoRouter get router {
    _router ??= GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/login',
      debugLogDiagnostics: true,
      refreshListenable: authProvider,
      redirect: _redirectLogic,
      routes: <RouteBase>[
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (BuildContext context, GoRouterState state) {
            return const LoginScreen();
          },
        ),
        // ---@ Main App Shell Route with Bottom Navigation ---
        StatefulShellRoute.indexedStack(
          builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
            return MainTabsScreen(navigationShell: navigationShell);
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              navigatorKey: _shellNavigatorKeyChat,
              routes: <RouteBase>[
                GoRoute(
                  path: '/chat',
                  name: 'chat',
                  builder: (BuildContext context, GoRouterState state) => const ChatScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _shellNavigatorKeyEvent,
              routes: <RouteBase>[
                GoRoute(
                  path: '/events',
                  name: 'events',
                  builder: (BuildContext context, GoRouterState state) => const EventListScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _shellNavigatorKeyPrefs,
              routes: <RouteBase>[
                GoRoute(
                  path: '/parameters',
                  name: 'parameters',
                  builder: (BuildContext context, GoRouterState state) => const ParametersScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
      // Optional: Error page
      // errorBuilder: (context, state) => ErrorScreen(error: state.error),
    );
    return _router!;
  }

  FutureOr<String?> _redirectLogic(BuildContext context, GoRouterState state) {
    final bool isAuthenticated = authProvider.isAuthenticated;
    final bool isLoading = authProvider.isLoading;
    const String loginLocation = '/login';
    const String homeLocation = '/chat';

    if (isLoading) {
      return null; // No redirect while loading initial auth state
    }

    final bool isLoggingIn = state.matchedLocation == loginLocation;

    if (!isAuthenticated) {
      return isLoggingIn ? null : loginLocation;
    }

    if (isLoggingIn) {
      return homeLocation;
    }

    return null;
  }
}
