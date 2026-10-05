import 'package:flutter/material.dart';

/// Entrance animation shared by the caregiver screens: fade + slight slide (and optionally a
/// gentle scale-up), driven by a slice of a parent controller so a page can stagger several
/// elements off one [AnimationController].
///
/// The owning page skips the controller straight to its end value when the platform asks
/// for reduced motion (`MediaQuery.disableAnimations`) — see [startCareEntrance].
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
    this.offset = const Offset(0, 0.08),
    this.scaleFrom = 1.0,
  });

  final Animation<double> controller;
  final double begin;
  final double end;
  final Offset offset;

  /// Starting scale; 1.0 means no scale animation.
  final double scaleFrom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    Widget result = SlideTransition(
      position: Tween<Offset>(begin: offset, end: Offset.zero).animate(curved),
      child: child,
    );
    if (scaleFrom != 1.0) {
      result = ScaleTransition(
        scale: Tween<double>(begin: scaleFrom, end: 1).animate(curved),
        child: result,
      );
    }
    return FadeTransition(opacity: curved, child: result);
  }
}

/// Starts a page's entrance [controller], or jumps it to the end when the platform asks for
/// reduced motion. Call once from `didChangeDependencies`.
void startCareEntrance(BuildContext context, AnimationController controller) {
  if (MediaQuery.of(context).disableAnimations) {
    controller.value = 1;
  } else {
    controller.forward();
  }
}
