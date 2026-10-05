import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

/// The primary caregiver call-to-action: a tall pill with an arrow. Minimum height
/// [CareSizes.ctaHeight] — a deliberately huge touch target.
///
/// * Default (light): white pill, arrow at the far right — designed to sit on the deep-green
///   wave (onboarding page 1).
/// * [CarePrimaryCta.filled]: deep-green pill, white label with the arrow right beside it —
///   for light page backgrounds (onboarding page 2 onwards).
class CarePrimaryCta extends StatelessWidget {
  const CarePrimaryCta({super.key, required this.label, required this.onPressed, this.icon = Icons.arrow_forward}) : filled = false;

  const CarePrimaryCta.filled({super.key, required this.label, required this.onPressed, this.icon = Icons.arrow_forward}) : filled = true;

  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : CareColors.primaryDark;
    // One line always: the CTA keeps a predictable height (layouts anchor to it) and shrinks
    // its label slightly on very narrow screens instead of wrapping.
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: CareText.cta.copyWith(color: foreground),
      ),
    );

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(CareRadius.pill), boxShadow: filled ? CareShadows.buttonOnLight : CareShadows.button),
        child: Material(
          color: filled ? CareColors.primaryDark : CareColors.surface,
          borderRadius: BorderRadius.circular(CareRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(CareRadius.pill),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CareSizes.ctaHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: filled
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(child: text),
                          const SizedBox(width: CareSpacing.md),
                          Icon(icon, size: 28, color: foreground),
                        ],
                      )
                    : Row(
                        children: [
                          const SizedBox(width: 24), // balances the arrow so the label stays visually centred
                          Expanded(child: text),
                          Icon(icon, size: 28, color: CareColors.textDark),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact soft-green pill (e.g. "Skip"). Padded to a 48dp-high touch target.
class CareSoftPillButton extends StatelessWidget {
  const CareSoftPillButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: CareColors.primarySoft,
        borderRadius: BorderRadius.circular(CareRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(CareRadius.pill),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CareSizes.minTouch, minWidth: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(widthFactor: 1, child: Text(label, style: CareText.pillLabel)),
            ),
          ),
        ),
      ),
    );
  }
}
