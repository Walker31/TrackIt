import 'package:go_router/go_router.dart';
import 'package:trackit/pages/splash_screen.dart';
import 'package:trackit/layout.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/home', builder: (context, state) => const Layout()),
  ],
);
