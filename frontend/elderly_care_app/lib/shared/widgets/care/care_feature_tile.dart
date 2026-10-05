import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

/// A pastel benefit tile: tinted rounded card with a large semantic icon above a centred
/// two-line label.
///
/// The label keeps its designed line breaks (`\n` in [label]) and scales down slightly rather
/// than ever splitting a word, so narrow phones and large system text stay legible.
/// Informational, not tappable — exposed to screen readers as one label.
class CareFeatureTile extends StatelessWidget {
  const CareFeatureTile({super.key, required this.icon, required this.label, required this.iconColor, required this.background});

  final IconData icon;

  /// May contain a `\n` to control the two-line break.
  final String label;
  final Color iconColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label.replaceAll('\n', ' '),
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: CareSpacing.sm + 2, vertical: CareSpacing.sm + 1),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(CareRadius.tile),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
          boxShadow: CareShadows.tile,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), shape: BoxShape.circle),
              child: Icon(icon, size: CareIconSize.feature, color: iconColor),
            ),
            const SizedBox(height: CareSpacing.sm - 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: CareText.tileLabel, textAlign: TextAlign.center, softWrap: false),
            ),
          ],
        ),
      ),
    );
  }
}
