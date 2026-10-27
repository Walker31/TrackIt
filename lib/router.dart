import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trackit/pages/splash_screen.dart';
import 'package:trackit/layout.dart';
import 'package:trackit/pages/settings_page.dart';
import 'package:trackit/pages/auth/login_page.dart';
import 'package:trackit/pages/auth/welcome_page.dart';
import 'package:trackit/pages/auth/register_page.dart';
import 'package:trackit/providers/auth_provider.dart';
import 'package:trackit/theme/app_transitions.dart';

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
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => appPage(state, const Layout()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => appPage(state, const SettingsPage()),
      ),
    ],
  );
});
