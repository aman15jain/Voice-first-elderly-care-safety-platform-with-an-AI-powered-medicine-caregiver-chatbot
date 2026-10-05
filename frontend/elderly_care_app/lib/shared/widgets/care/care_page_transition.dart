import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route page for caregiver onboarding steps: a short fade with a slight slide in from the
/// right, so moving between steps feels like one continuous flow. Instant when the platform
/// asks for reduced motion.
CustomTransitionPage<void> careOnboardingPage({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) return child;
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
