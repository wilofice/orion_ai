import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:orion_ai/src/auth/google_auth.dart';
import 'package:provider/provider.dart';

// Adjust paths as per your project structure
import '../chat/chat_screen.dart';
import '../events/event_list_screen.dart';
import '../preferences/preferences_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../navigation/main_tabs_screen.dart';
// --- IMPORT THE NEW GOOGLE AUTH SCREEN ---
import '../auth/google_auth.dart'; // Adjust path as needed

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
      initialLocation: '/link-google-calendar', // Default initial location if authenticated
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
        // --- ADDED ROUTE FOR GOOGLE AUTH SCREEN ---
        GoRoute(
          path: '/link-google-calendar', // You can choose any path you prefer
          name: 'linkGoogleCalendar',
          builder: (BuildContext context, GoRouterState state) {
            // GoogleAuthScreen is the widget we created previously.
            // Ensure you have the correct import for it.
            return const GoogleAuthScreen();
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

  FutureOr<String?> _redirectLogic(BuildContext context, GoRouterState state) {
    final bool isAuthenticated = authProvider.isAuthenticated;
    final bool isLoading = authProvider.isLoading;
    final String loginLocation = '/login';
    final String homeLocation = '/chat';
    // The location for the Google Calendar linking screen
    final String linkGoogleCalendarLocation = '/link-google-calendar';

    print('AppRouter Redirect: isAuthenticated=$isAuthenticated, isLoading=$isLoading, location=${state.matchedLocation}');

    if (isLoading) {
      return null; // No redirect while loading initial auth state
    }

    final bool isLoggingIn = state.matchedLocation == loginLocation;
    final bool isLinkingCalendar = state.matchedLocation == linkGoogleCalendarLocation;

    // If the user is not authenticated:
    if (!isAuthenticated) {
      // Allow access to login and the Google Calendar linking screen (if it's part of a flow accessible without full app login)
      // If /link-google-calendar should ONLY be accessible AFTER app login, then remove `|| isLinkingCalendar`
      if (isLoggingIn || isLinkingCalendar) {
        print('AppRouter Redirect: Not authenticated but on a public route ($loginLocation or $linkGoogleCalendarLocation). No redirect.');
        return null;
      }
      print('AppRouter Redirect: Not authenticated, redirecting to $loginLocation');
      return loginLocation;
    }

    // If the user IS authenticated:
    if (isAuthenticated) {
      if (isLoggingIn) {
        // If authenticated and on login page, redirect to home
        print('AppRouter Redirect: Authenticated and on login page, redirecting to $linkGoogleCalendarLocation');
        return linkGoogleCalendarLocation;
      }
      if(state.matchedLocation == linkGoogleCalendarLocation && !authProvider.isCalendarLinked) {
        // If authenticated and on link-google-calendar page, redirect to home
        print('AppRouter Redirect: Not Authenticated and on link-google-calendar page, redirecting to link-google-calendar page.');
        return linkGoogleCalendarLocation;
      } 
      else if(state.matchedLocation == linkGoogleCalendarLocation && authProvider.isCalendarLinked) {
        print('AppRouter Redirect: Authenticated and on link-google-calendar page, redirecting to home.');
        return homeLocation;
      }
    }

    print('AppRouter Redirect: No redirect needed for location: ${state.matchedLocation}');
    return null; // No redirect needed
  }
}
