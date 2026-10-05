import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

/// The standard caregiver surface: white, generously rounded, softly elevated. Optionally
/// tappable (with a ripple and button semantics).
class CareCard extends StatelessWidget {
  const CareCard({
    super.key,
    required this.child,
    this.onTap,
    this.color = CareColors.surface,
    this.padding = const EdgeInsets.all(CareSpacing.lg + 2),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry padding;

  /// When tappable, what a screen reader announces for the whole card.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CareRadius.card);
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: CareShadows.tile),
      child: Material(
        color: color,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : Semantics(
                button: true,
                label: semanticLabel,
                child: InkWell(onTap: onTap, child: content),
              ),
      ),
    );
  }
}

/// Section title with an optional trailing text action ("See all →"), 48dp tall.
class CareSectionHeader extends StatelessWidget {
  const CareSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: CareSizes.minTouch),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: CareText.sectionTitle)),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: CareColors.primary,
                minimumSize: const Size(48, CareSizes.minTouch),
                visualDensity: VisualDensity.standard,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Text(actionLabel!), const SizedBox(width: 4), const Icon(Icons.arrow_forward, size: 18)]),
            ),
        ],
      ),
    );
  }
}
