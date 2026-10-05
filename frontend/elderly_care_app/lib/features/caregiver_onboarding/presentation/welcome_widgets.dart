import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

/// One trust indicator: soft circular icon backdrop + two-line label.
class WelcomeBenefit extends StatelessWidget {
  const WelcomeBenefit({super.key, required this.icon, required this.label, required this.iconColor, required this.backdrop});

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color backdrop;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label.replaceAll('\n', ' '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: CareIconSize.featureBackdrop,
            height: CareIconSize.featureBackdrop,
            decoration: BoxDecoration(color: backdrop, shape: BoxShape.circle),
            child: Icon(icon, size: CareIconSize.feature, color: iconColor),
          ),
          const SizedBox(width: CareSpacing.md),
          Flexible(child: Text(label, style: CareText.featureLabel)),
        ],
      ),
    );
  }
}

/// Small floating social-proof card ("10,000+ Families Trust Us").
///
/// [value] and [label] are inputs, not business logic: the figure is demo content from the
/// design and must be replaced with a real, verifiable number before release.
class TrustStatCard extends StatelessWidget {
  const TrustStatCard({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
        decoration: BoxDecoration(
          color: CareColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(CareRadius.card),
          boxShadow: CareShadows.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: CareColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.diversity_3, size: 26, color: CareColors.primary),
            ),
            const SizedBox(width: CareSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1, color: CareColors.primary),
                    ),
                  ),
                  Text(label, style: const TextStyle(fontSize: 13, height: 1.25, color: CareColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
