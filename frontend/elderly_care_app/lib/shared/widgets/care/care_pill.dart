import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

/// The one status pill (Connected / Pending / Taken / Missed / Active ...): a soft tinted
/// capsule with bold coloured text and an optional leading icon.
class CareStatusPill extends StatelessWidget {
  const CareStatusPill({super.key, required this.label, this.foreground = CareColors.primaryDark, this.background = CareColors.primarySoft, this.icon});

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final size = (Theme.of(context).textTheme.bodySmall?.fontSize ?? 14) + 0.5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(CareRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: size + 4, color: foreground), const SizedBox(width: 6)],
          Text(
            label,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: foreground),
          ),
        ],
      ),
    );
  }
}

/// A soft rounded icon tile — the icon treatment used on Pages 1–2 and across cards.
class CareIconTile extends StatelessWidget {
  const CareIconTile({
    super.key,
    required this.icon,
    this.color = CareColors.primary,
    this.background = CareColors.primarySoft,
    this.size = 52,
    this.circle = false,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.52, color: color),
    );
  }
}
