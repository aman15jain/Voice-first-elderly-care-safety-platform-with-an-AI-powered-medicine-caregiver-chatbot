import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

/// Sathi brand lockup: heart-and-leaf mark, wordmark and tagline.
///
/// No official logo asset exists in the project yet, so the mark is drawn in code. When the
/// approved logo file arrives, swap [CareConnectMark] for an `Image.asset`/`SvgPicture` and
/// every caregiver page picks it up.
class CareConnectLogo extends StatelessWidget {
  const CareConnectLogo({super.key, this.markSize = 60, this.wordmarkSize = 32, this.showTagline = true, this.trailing});

  final double markSize;

  /// Font size of the wordmark; the tagline scales with it.
  final double wordmarkSize;
  final bool showTagline;

  /// Optional action (e.g. a Skip button) placed at the end of the wordmark line, so the
  /// tagline below can use the full width instead of wrapping beside it.
  final Widget? trailing;

  /// The user-facing product name. Internal identifiers (this class, routes, package id)
  /// predate it and intentionally keep their old names.
  static const brandName = 'Sathi';
  static const _tagline = 'Care Today for a Brighter Tomorrow';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          label: showTagline ? '$brandName. $_tagline' : brandName,
          container: true,
          excludeSemantics: true,
          child: CareConnectMark(size: markSize),
        ),
        SizedBox(width: markSize * 0.2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          brandName,
                          style: CareText.brandName.copyWith(fontSize: wordmarkSize, color: CareColors.primary),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: CareSpacing.sm), trailing!],
                ],
              ),
              if (showTagline)
                ExcludeSemantics(
                  child: Text(_tagline, style: CareText.tagline.copyWith(fontSize: (wordmarkSize * 0.44).clamp(12.5, 15.0)), maxLines: 2),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The heart + leaf mark on its own.
class CareConnectMark extends StatelessWidget {
  const CareConnectMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size * 0.94), painter: _MarkPainter());
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Heart silhouette.
    final heart = Path()
      ..moveTo(w * 0.5, h * 0.98)
      ..cubicTo(w * 0.08, h * 0.66, -w * 0.02, h * 0.34, w * 0.18, h * 0.12)
      ..cubicTo(w * 0.32, -h * 0.02, w * 0.46, h * 0.06, w * 0.5, h * 0.2)
      ..cubicTo(w * 0.54, h * 0.06, w * 0.68, -h * 0.02, w * 0.82, h * 0.12)
      ..cubicTo(w * 1.02, h * 0.34, w * 0.92, h * 0.66, w * 0.5, h * 0.98)
      ..close();
    canvas.drawPath(
      heart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CareColors.primary, CareColors.primaryDark],
        ).createShader(Offset.zero & size),
    );

    // Leaf cut-out in white.
    final leaf = Path()
      ..moveTo(w * 0.40, h * 0.86)
      ..cubicTo(w * 0.22, h * 0.62, w * 0.30, h * 0.30, w * 0.62, h * 0.24)
      ..cubicTo(w * 0.68, h * 0.50, w * 0.60, h * 0.76, w * 0.40, h * 0.86)
      ..close();
    canvas.drawPath(leaf, Paint()..color = Colors.white);

    // Leaf vein.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.40, h * 0.84)
        ..quadraticBezierTo(w * 0.46, h * 0.56, w * 0.60, h * 0.30),
      Paint()
        ..color = CareColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
