import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The app's page transition: the new page fades in while sliding up a
/// little; the page underneath fades back slightly.
Widget appPageTransition(
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final incoming = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final outgoing = CurvedAnimation(
    parent: secondaryAnimation,
    curve: Curves.easeOutCubic,
  );
  return FadeTransition(
    opacity: Tween<double>(begin: 1, end: 0.6).animate(outgoing),
    child: FadeTransition(
      opacity: incoming,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(incoming),
        child: child,
      ),
    ),
  );
}

/// [appPageTransition] for Navigator routes (MaterialPageRoute etc.).
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => appPageTransition(animation, secondaryAnimation, child);
}

/// [appPageTransition] for go_router routes.
CustomTransitionPage<void> appPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        appPageTransition(animation, secondaryAnimation, child),
    child: child,
  );
}
