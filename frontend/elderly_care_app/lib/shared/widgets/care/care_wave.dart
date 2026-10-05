import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

/// One layer of the flowing green wave that anchors the bottom of caregiver screens.
///
/// The wave is drawn as two separate layers so content can be slotted between them:
/// put the [CareWaveLayer.back] (soft mint) first, then any hero imagery, then the
/// [CareWaveLayer.front] (deep teal) — the image then stands in front of the light wave but
/// sinks behind the dark one, which is what integrates it with the page.
///
/// Both layers must be given the same box. [baseline] is the y (from the top of that box)
/// where the content sitting on the wave (e.g. pagination + CTA) begins; the curves are laid
/// out above it, and everything below it is solid dark teal.
class CareWaveLayer extends StatelessWidget {
  const CareWaveLayer.back({super.key, required this.baseline}) : front = false;
  const CareWaveLayer.front({super.key, required this.baseline}) : front = true;

  final bool front;
  final double baseline;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _WavePainter(front: front, baseline: baseline),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.front, required this.baseline});

  final bool front;
  final double baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = baseline;

    if (!front) {
      // Soft hill rising on the left, sweeping down behind the hero.
      final light = Path()
        ..moveTo(0, t * 0.30)
        ..cubicTo(w * 0.12, t * 0.04, w * 0.30, -t * 0.04, w * 0.46, t * 0.28)
        ..cubicTo(w * 0.60, t * 0.54, w * 0.80, t * 0.62, w, t * 0.52)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        light,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [CareColors.primaryTint.withValues(alpha: 0.85), CareColors.primarySoft],
          ).createShader(Rect.fromLTWH(0, 0, w, t)),
      );
      return;
    }

    // Deep teal base: high on the left, dipping under the hero on the right.
    final dark = Path()
      ..moveTo(0, t * 0.56)
      ..cubicTo(w * 0.22, t * 0.42, w * 0.42, t * 0.62, w * 0.62, t * 0.86)
      ..cubicTo(w * 0.78, t * 1.04, w * 0.92, t * 0.98, w, t * 0.80)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      dark,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CareColors.primary, CareColors.primaryDark, CareColors.primaryDeepest],
          stops: [0.0, 0.4, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.front != front || oldDelegate.baseline != baseline;
}
