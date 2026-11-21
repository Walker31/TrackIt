import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trackit/pages/splash_screen.dart';
import 'package:trackit/layout.dart';
import 'package:trackit/pages/settings_page.dart';
import 'package:trackit/pages/progress_pages.dart';
import 'package:trackit/pages/auth/login_page.dart';
import 'package:trackit/pages/auth/welcome_page.dart';
import 'package:trackit/pages/auth/register_page.dart';
import 'package:trackit/providers/auth_provider.dart';
import 'package:trackit/theme/app_transitions.dart';

const _shellKey = ValueKey('app-shell');

final routerProvider = Provider<GoRouter>((ref) {
  // read, not watch: watching a ChangeNotifierProvider rebuilds on every
  // notify (even an isLoading toggle), which created a fresh GoRouter and
  // wiped the navigation stack and page state. refreshListenable below
  // re-runs the redirects instead.
  final authNotifier = ref.read(authProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = authNotifier.state;
      final isLoggingIn = const {
        '/welcome',
        '/login',
        '/register',
      }.contains(state.matchedLocation);

      if (authState.status == AuthStatus.initial) return null;

      if (authState.status == AuthStatus.unauthenticated) {
        return isLoggingIn ? null : '/welcome';
      }

      // Local mode may still visit the login page to connect to a server.
      if (authState.status == AuthStatus.local) return null;

      if (authState.status == AuthStatus.authenticated && isLoggingIn) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => appPage(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => appPage(state, const WelcomePage()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => appPage(state, const LoginPage()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => appPage(state, const RegisterPage()),
      ),
      // One route per tab so the address bar, back button, refresh and
      // bookmarks follow the tab. They share a page key, so switching tabs
      // updates the one shell in place instead of pushing a new page.
      for (final tab in AppTab.values)
        GoRoute(
          path: tab.path,
          pageBuilder: (context, state) =>
              appPage(state, Layout(tab: tab), key: _shellKey),
        ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) =>
            appPage(state, const WorkoutHistoryPage()),
      ),
      GoRoute(
        path: '/history/:id',
        pageBuilder: (context, state) => appPage(
          state,
          WorkoutDetailPage(
            workoutId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
            justFinished: state.uri.queryParameters['done'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/records',
        pageBuilder: (context, state) => appPage(state, const RecordsPage()),
      ),
      GoRoute(
        path: '/exercise',
        pageBuilder: (context, state) => appPage(
          state,
          ExerciseProgressPage(name: state.uri.queryParameters['name'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => appPage(state, const SettingsPage()),
      ),
    ],
  );
});
