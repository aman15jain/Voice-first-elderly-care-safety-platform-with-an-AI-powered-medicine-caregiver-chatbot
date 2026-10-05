import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';

typedef CarePageBuilder = Widget Function(BuildContext context, Size viewport, EdgeInsets insets);

/// The responsive shell every caregiver page is built in.
///
/// * Phones: [builder] gets the real viewport and system insets (status/nav bar).
/// * Wide windows (desktop browsers, tablets — [framedMinWidth] and up): the phone composition
///   is shown as a centred column scaled to the window height instead of being stretched
///   sideways, so the page is seen exactly as designed with nothing pushed below the fold.
/// * Very large system text is capped at 1.3x so tuned compositions never collide; pages stay
///   scrollable, so nothing is ever clipped.
class CareResponsivePage extends StatelessWidget {
  const CareResponsivePage({super.key, required this.builder});

  static const framedMinWidth = 600.0;
  static const frameDesignSize = Size(430, 932);

  final CarePageBuilder builder;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          if (viewport.width < framedMinWidth) return builder(context, viewport, MediaQuery.paddingOf(context));

          final scale = math.min(viewport.height / frameDesignSize.height, viewport.width / frameDesignSize.width);
          return ColoredBox(
            color: CareColors.primarySoft,
            child: Center(
              child: DecoratedBox(
                decoration: const BoxDecoration(boxShadow: CareShadows.card),
                child: SizedBox(
                  width: frameDesignSize.width * scale,
                  height: frameDesignSize.height * scale,
                  child: FittedBox(
                    child: SizedBox.fromSize(
                      size: frameDesignSize,
                      child: ClipRect(child: Builder(builder: (context) => builder(context, frameDesignSize, EdgeInsets.zero))),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Vertical spacing that adapts to screen height: [gap] returns the tight value on a
/// 568dp-tall phone and the spacious one at 844dp and above, interpolating between. Short
/// screens therefore tighten spacing — not element sizes — before they start to scroll.
class CareRhythm {
  CareRhythm(double viewportHeight) : roomy = ((viewportHeight - 568) / (844 - 568)).clamp(0.0, 1.0);

  /// 0 (cramped) … 1 (roomy).
  final double roomy;

  double gap(double tight, double spacious) => tight + (spacious - tight) * roomy;
}
