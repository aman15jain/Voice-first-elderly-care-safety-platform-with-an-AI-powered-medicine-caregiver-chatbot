import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

/// Soft organic decoration behind a centred hero image: a pale green disc, leaf sprigs on
/// either side, a peach heart badge with rays, and a small outlined heart.
///
/// Pure decoration — excluded from semantics. It paints in its own box, so give it the same
/// box as the hero it sits behind.
class CareHeroBackdrop extends StatelessWidget {
  const CareHeroBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: CustomPaint(painter: _BackdropPainter(), size: Size.infinite),
  );
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = math.min(w * 0.47, h * 0.56);
    final centre = Offset(w / 2, h * 0.52);

    // Pale disc.
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(colors: [CareColors.primarySoft, CareColors.primarySoft.withValues(alpha: 0.55)])
            .createShader(Rect.fromCircle(center: centre, radius: r)),
    );

    // Soft leaf blobs low on either side.
    final blob = Paint()..color = CareColors.leafSoft.withValues(alpha: 0.75);
    canvas.drawOval(Rect.fromCenter(center: Offset(centre.dx - r * 0.86, centre.dy + r * 0.42), width: r * 0.62, height: r * 0.5), blob);
    canvas.drawOval(Rect.fromCenter(center: Offset(centre.dx + r * 0.9, centre.dy + r * 0.5), width: r * 0.5, height: r * 0.42), blob);

    // Leaf sprigs.
    _sprig(canvas, Offset(centre.dx - r * 0.78, centre.dy + r * 0.2), r * 0.62, -0.32, mirrored: false);
    _sprig(canvas, Offset(centre.dx + r * 0.86, centre.dy + r * 0.42), r * 0.44, 0.3, mirrored: true);

    // Heart badge with rays, upper left of centre.
    final badge = Offset(centre.dx - r * 0.12, centre.dy - r * 0.68);
    final badgeR = r * 0.17;
    canvas.drawCircle(badge, badgeR, Paint()..color = CareColors.accentPeachSoft);
    final ray = Paint()
      ..color = CareColors.accentPeach.withValues(alpha: 0.8)
      ..strokeWidth = math.max(1.5, r * 0.012)
      ..strokeCap = StrokeCap.round;
    for (final angle in [-2.6, -2.1, -1.6, 2.9]) {
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(badge + dir * badgeR * 1.3, badge + dir * badgeR * 1.65, ray);
    }
    _heart(canvas, badge, badgeR * 0.5, Paint()..color = CareColors.accentPeach);

    // Small outlined heart.
    _heart(
      canvas,
      Offset(centre.dx - r * 0.56, centre.dy - r * 0.42),
      r * 0.06,
      Paint()
        ..color = CareColors.leaf
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * 0.012),
    );
  }

  void _sprig(Canvas canvas, Offset base, double length, double tilt, {required bool mirrored}) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    if (mirrored) canvas.scale(-1, 1);
    final stem = Paint()
      ..color = CareColors.leaf
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, length * 0.02)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(length * 0.08, -length * 0.5, 0, -length),
      stem,
    );
    final leaf = Paint()..color = CareColors.leaf.withValues(alpha: 0.85);
    for (var i = 0; i < 4; i++) {
      final y = -length * (0.25 + i * 0.22);
      final side = i.isEven ? 1.0 : -1.0;
      final size = length * (0.26 - i * 0.03);
      canvas.save();
      canvas.translate(length * 0.03, y);
      canvas.rotate(side * 0.9);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(size * 0.45, -size * 0.32, size, 0)
          ..quadraticBezierTo(size * 0.45, size * 0.32, 0, 0)
          ..close(),
        leaf,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _heart(Canvas canvas, Offset c, double r, Paint paint) {
    final p = Path()
      ..moveTo(c.dx, c.dy + r)
      ..cubicTo(c.dx - r * 1.6, c.dy - r * 0.2, c.dx - r * 0.6, c.dy - r * 1.4, c.dx, c.dy - r * 0.4)
      ..cubicTo(c.dx + r * 0.6, c.dy - r * 1.4, c.dx + r * 1.6, c.dy - r * 0.2, c.dx, c.dy + r)
      ..close();
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
