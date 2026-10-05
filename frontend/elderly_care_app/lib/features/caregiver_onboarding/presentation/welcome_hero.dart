import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/care_tokens.dart';

/// Caregiver + elder hero artwork for the onboarding pages, one asset slot per page.
///
/// The approved photographs are NOT in the project yet. Drop each file at its [assetPath]
/// (see `assets/images/caregiver/README.md` for the per-page spec) and it is picked up
/// automatically. Until then — or if a file is missing — [_HeroPlaceholder] draws a neutral
/// illustration in exactly the box the photo will occupy.
class CaregiverHero extends StatelessWidget {
  /// Page 1: caregiver left, elder right, anchored bottom-right; 4:5 portrait box.
  const CaregiverHero.welcome({super.key})
    : assetPath = 'assets/images/caregiver/welcome_hero.png',
      semanticLabel = 'A caregiver in blue scrubs smiling with an elderly woman',
      alignment = Alignment.bottomRight,
      mirrored = false,
      decorated = true;

  /// Page 2: elder left, caregiver right, centred over a decorative backdrop; wide box.
  const CaregiverHero.intro({super.key})
    : assetPath = 'assets/images/caregiver/intro_hero.png',
      semanticLabel = 'An elderly woman and a smiling caregiver holding hands',
      alignment = Alignment.bottomCenter,
      mirrored = true,
      decorated = false;

  /// Caregiver home header: caregiver left, elder right, centred; small square-ish box.
  const CaregiverHero.home({super.key})
    : assetPath = 'assets/images/caregiver/home_hero.png',
      semanticLabel = 'A caregiver and an elderly woman smiling together',
      alignment = Alignment.bottomCenter,
      mirrored = false,
      decorated = false;

  final String assetPath;
  final String semanticLabel;
  final Alignment alignment;

  /// Placeholder only: flip the pair so the elder is on the left.
  final bool mirrored;

  /// Placeholder only: draw its own halo/arc/heart (pages without a separate backdrop).
  final bool decorated;

  /// Width / height of the Page 1 hero box.
  static const welcomeAspectRatio = 0.8;

  /// Asset paths bundled with the app, read once from the asset manifest. Checking it first
  /// means a photo that hasn't been added yet is never requested (no 404 noise on web).
  static final Future<Set<String>> _bundledAssets = AssetManifest.loadFromAssetBundle(rootBundle)
      .then((m) => m.listAssets().toSet(), onError: (Object _) => <String>{});

  @override
  Widget build(BuildContext context) {
    final placeholder = ClipRect(
      child: CustomPaint(
        painter: _HeroPlaceholderPainter(alignX: (alignment.x + 1) / 2, mirrored: mirrored, decorated: decorated),
        size: Size.infinite,
      ),
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: FutureBuilder<Set<String>>(
        future: _bundledAssets,
        builder: (context, snapshot) {
          if (!(snapshot.data?.contains(assetPath) ?? false)) return placeholder;
          return Image.asset(assetPath, fit: BoxFit.contain, alignment: alignment, errorBuilder: (context, error, stackTrace) => placeholder);
        },
      ),
    );
  }
}

/// Drawn in a 100 x 125 design box (4:5), scaled uniformly to fit the real box, anchored to
/// its bottom edge and horizontally by [alignX] (0 = left, 1 = right).
class _HeroPlaceholderPainter extends CustomPainter {
  _HeroPlaceholderPainter({required this.alignX, required this.mirrored, required this.decorated});

  final double alignX;
  final bool mirrored;
  final bool decorated;

  static const _skin = Color(0xFFE3B38E);
  static const _skinElder = Color(0xFFD9A47F);
  static const _scrubs = Color(0xFF3F7FC8);
  static const _scrubsDark = Color(0xFF2F68AE);
  static const _hair = Color(0xFF241714);
  static const _elderHair = Color(0xFFE9E6E2);
  static const _cardigan = Color(0xFFE6D7BF);
  static const _cardiganDark = Color(0xFFD8C6A8);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final s = math.min(size.width / 100, size.height / 125);
    canvas.translate((size.width - 100 * s) * alignX, size.height - 125 * s);
    canvas.scale(s);
    // The pair spans x 30..118 of the 100-wide design box (it bleeds right on purpose for
    // page 1's bottom-right anchoring). When the hero is centred, shift the group to the middle.
    if (mirrored) {
      // Mirror about the group's own centre (74), then centre it.
      canvas.translate(124, 0);
      canvas.scale(-1, 1);
    } else if (alignX == 0.5) {
      canvas.translate(-24, 0);
    }

    if (decorated) {
      // Soft halo and thin decorative arcs behind the pair.
      canvas.drawCircle(const Offset(66, 70), 36, Paint()..color = CareColors.primarySoft.withValues(alpha: 0.9));
      final outline = Paint()
        ..color = CareColors.primary.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      canvas.drawArc(Rect.fromCircle(center: const Offset(96, 60), radius: 18), 3.3, 2.2, false, outline);
      _heart(canvas, const Offset(84, 22), 5, Paint()..color = CareColors.primary.withValues(alpha: 0.55));
    }

    // Caregiver (left, leaning in).
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(30, 62, 80, 140, topLeft: const Radius.circular(24), topRight: const Radius.circular(22)),
      Paint()..color = _scrubs,
    );
    canvas.drawPath(
      Path()
        ..moveTo(47, 62)
        ..lineTo(55, 76)
        ..lineTo(63, 62)
        ..close(),
      Paint()..color = _scrubsDark,
    );
    canvas.drawRect(const Rect.fromLTWH(50, 54, 10, 10), Paint()..color = _skin); // neck
    canvas.drawCircle(const Offset(54, 42), 14.5, Paint()..color = _hair);
    canvas.drawCircle(const Offset(39, 42), 6, Paint()..color = _hair); // ponytail
    canvas.drawCircle(const Offset(56, 46), 11, Paint()..color = _skin);
    final stethoscope = Paint()
      ..color = const Color(0xFF1F2A33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(47, 63)
        ..quadraticBezierTo(44, 82, 52, 90),
      stethoscope,
    );
    canvas.drawPath(
      Path()
        ..moveTo(63, 63)
        ..quadraticBezierTo(66, 76, 62, 84),
      stethoscope,
    );
    canvas.drawCircle(const Offset(62, 86.5), 2.6, Paint()..color = const Color(0xFFB8C2C9));

    // Elder (right, seated, in front).
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(64, 92, 118, 140, topLeft: const Radius.circular(22), topRight: const Radius.circular(22)),
      Paint()..color = _cardigan,
    );
    canvas.drawRect(const Rect.fromLTWH(84, 96, 12, 44), Paint()..color = Colors.white);
    canvas.drawRect(const Rect.fromLTWH(82, 96, 2, 44), Paint()..color = _cardiganDark);
    canvas.drawCircle(const Offset(88, 74), 13.5, Paint()..color = _elderHair);
    canvas.drawCircle(const Offset(86, 78), 10.5, Paint()..color = _skinElder);

    // Caregiver's hand resting on the elder's shoulder.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(71, 97), width: 15, height: 7), const Radius.circular(4)),
      Paint()..color = _skin,
    );
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
  bool shouldRepaint(covariant _HeroPlaceholderPainter oldDelegate) =>
      oldDelegate.alignX != alignX || oldDelegate.mirrored != mirrored || oldDelegate.decorated != decorated;
}
