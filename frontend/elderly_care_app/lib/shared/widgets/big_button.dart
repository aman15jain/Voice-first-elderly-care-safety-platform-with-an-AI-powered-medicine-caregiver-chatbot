import 'package:flutter/material.dart';

/// The standard tappable action across the app: large, high-contrast, a clear label,
/// and a visible loading state so an elder never has to guess whether a tap registered.
class BigButton extends StatelessWidget {
  const BigButton({required this.label, required this.onPressed, super.key, this.icon, this.isLoading = false, this.color});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 28), const SizedBox(width: 12)],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      // Shape, height and type come from the Sathi theme; [color] only swaps the fill (e.g. SOS red),
      // keeping a matching tint while loading.
      style: color != null ? FilledButton.styleFrom(backgroundColor: color, disabledBackgroundColor: color!.withValues(alpha: 0.55)) : null,
      child: child,
    );
  }
}

/// A secondary, less prominent action (e.g. "Cancel", "Skip") — still a large touch target.
class BigOutlinedButton extends StatelessWidget {
  const BigOutlinedButton({required this.label, required this.onPressed, super.key, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Height, shape and type come from the Sathi theme (64dp in the elder comfort theme).
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 26), const SizedBox(width: 10)],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
