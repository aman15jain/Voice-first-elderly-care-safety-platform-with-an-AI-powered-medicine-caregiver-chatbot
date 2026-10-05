import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

/// Page indicator for the caregiver onboarding flow: the active step is an elongated pill,
/// the others are dots. Animates when [index] changes.
///
/// Defaults suit a dark (wave) background; use [OnboardingDots.onLight] on light pages.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({super.key, required this.index, required this.count, this.activeColor = Colors.white, this.inactiveColor = const Color(0x73FFFFFF)});

  const OnboardingDots.onLight({super.key, required this.index, required this.count})
    : activeColor = CareColors.primaryDark,
      inactiveColor = CareColors.primaryTint;

  final int index;
  final int count;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 36 : 10,
              height: 10,
              decoration: BoxDecoration(color: i == index ? activeColor : inactiveColor, borderRadius: BorderRadius.circular(10)),
            ),
        ],
      ),
    );
  }
}
