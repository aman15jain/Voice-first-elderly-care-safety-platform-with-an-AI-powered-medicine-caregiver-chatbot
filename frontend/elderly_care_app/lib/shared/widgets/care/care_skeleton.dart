import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

/// Loading placeholder: soft rounded blocks that gently pulse (static when the platform asks
/// for reduced motion). Announced once as "Loading" rather than as empty content.
class CareSkeleton extends StatefulWidget {
  const CareSkeleton({super.key, required this.child});

  /// Layout built from [CareSkeletonBlock]s.
  final Widget child;

  @override
  State<CareSkeleton> createState() => _CareSkeletonState();
}

class _CareSkeletonState extends State<CareSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      excludeSemantics: true,
      child: FadeTransition(opacity: Tween<double>(begin: 0.55, end: 1).animate(_pulse), child: widget.child),
    );
  }
}

class CareSkeletonBlock extends StatelessWidget {
  const CareSkeletonBlock({super.key, this.width, required this.height, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: CareColors.primarySoft, borderRadius: BorderRadius.circular(radius)),
  );
}
