import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../chat/chat_screen.dart'; // Adjust path
import '../events/event_list_screen.dart'; // Adjust path
import '../preferences/preferences_screen.dart'; // Adjust path
import '../auth/auth_provider.dart'; // Adjust path
import '../auth/login_screen.dart'; // Adjust path // Adjust path
import '../navigation/main_tabs_screen.dart'; // Adjust path

// For root navigator key, useful for global navigation context
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
      initialLocation: '/chat', // Default initial location if authenticated
      debugLogDiagnostics: true, // Helpful for debugging navigation
      refreshListenable: authProvider, // Re-evaluate routes when AuthProvider notifies
      redirect: _redirectLogic, // Step 6.5: Implement redirect logic
      routes: <RouteBase>[
        // --- Login Route (Step 6.3, 6.6) ---
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (BuildContext context, GoRouterState state) {
            return const LoginScreen();
          },
        ),
        // --- Main App Shell Route with Bottom Navigation (Step 6.4) ---
        StatefulShellRoute.indexedStack(
          builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
            // Return the MainTabsScreen that wraps the navigationShell
            return MainTabsScreen(navigationShell: navigationShell);
          },
          branches: <StatefulShellBranch>[
            // Branch for the Chat tab
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
            // Branch for the Events tab
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
            // Branch for the Preferences tab
            StatefulShellBranch(
              navigatorKey: _shellNavigatorKeyPrefs,
              routes: <RouteBase>[
                GoRoute(
                  path: '/preferences',
                  name: 'preferences',
                  builder: (BuildContext context, GoRouterState state) => const PreferencesScreen(),
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

  // --- Step 6.5: Redirect Logic ---
  FutureOr<String?> _redirectLogic(BuildContext context, GoRouterState state) {
    final bool isAuthenticated = authProvider.isAuthenticated;
    final bool isLoading = authProvider.isLoading; // Check if still loading initial auth state
    final String loginLocation = '/login';
    final String homeLocation = '/chat'; // Default screen after login

    print('AppRouter Redirect: isAuthenticated=$isAuthenticated, isLoading=$isLoading, location=${state.matchedLocation}');

    if (isLoading) {
      // If still loading initial auth state, don't redirect yet.
      // GoRouter might show a blank screen or initial route briefly.
      // Consider a dedicated loading route or handling in App.
      return null; // No redirect while loading initial state
    }

    final bool isLoggingIn = state.matchedLocation == loginLocation;

    if (!isAuthenticated && !isLoggingIn) {
      print('AppRouter Redirect: Not authenticated and not on login page, redirecting to $loginLocation');
      return loginLocation; // Redirect to login if not authenticated and not already on login
    }
    if (isAuthenticated && isLoggingIn) {
      print('AppRouter Redirect: Authenticated and on login page, redirecting to $homeLocation');
      return homeLocation; // Redirect to home if authenticated and currently on login
    }

    print('AppRouter Redirect: No redirect needed.');
    return null; // No redirect needed
  }
}