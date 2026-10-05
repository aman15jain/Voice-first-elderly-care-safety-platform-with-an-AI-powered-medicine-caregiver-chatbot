import 'package:flutter/material.dart';

/// Design tokens for the whole Sathi app (elder and caregiver).
///
/// Onboarding pages 1 and 2 are the visual foundation, so every colour, radius, spacing step
/// and text style they use lives here. Screens reuse these (directly or through [CareTheme])
/// rather than hard-coding values.
class CareColors {
  const CareColors._();

  /// Brand teal/green — headline accent, icons, links.
  static const primary = Color(0xFF1B7F5E);

  /// Deeper green used for the wave base, button text and strong emphasis.
  static const primaryDark = Color(0xFF0F5C45);

  /// Deepest green at the very bottom of the wave gradient.
  static const primaryDeepest = Color(0xFF0A4635);

  /// Soft green tint — Skip pill, icon backdrops, light wave layer.
  static const primarySoft = Color(0xFFE3F1EA);
  static const primaryTint = Color(0xFFBFE0D0);

  static const textDark = Color(0xFF0B1F2A);
  static const textMuted = Color(0xFF4A5B66);

  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFFAF8F4);
  static const backgroundTop = Color(0xFFFFFFFF);

  // Semantic accents used by the benefit icons.
  static const accentWarm = Color(0xFFD9622B);
  static const accentWarmSoft = Color(0xFFFCE9DC);
  static const accentBlue = Color(0xFF2B6CB0);
  static const accentBlueSoft = Color(0xFFE2EDF9);
  static const accentViolet = Color(0xFF7A4FC4);
  static const accentVioletSoft = Color(0xFFF0E9FB);

  /// Warm peach used for heart/care decoration.
  static const accentPeach = Color(0xFFF08A4B);
  static const accentPeachSoft = Color(0xFFFDE6D4);

  /// Warm amber (game colours, highlights).
  static const accentAmber = Color(0xFFE0A100);

  /// Leaf greens for organic decoration.
  static const leaf = Color(0xFF7DB98F);
  static const leafSoft = Color(0xFFCFE6D6);

  /// Entered text in every input — plain black for maximum legibility.
  static const inputText = Color(0xFF000000);

  // Status colours (taken / due / missed, SOS, connection, ...). Always paired with an icon
  // or label, never colour alone.
  static const success = primary;
  static const successSoft = primarySoft;
  static const warning = Color(0xFFB4441C);
  static const warningSoft = accentWarmSoft;
  static const danger = Color(0xFFC62828);
  static const dangerSoft = Color(0xFFFDECEA);
  static const dangerBorder = Color(0xFFF5C2BF);
  static const info = accentBlue;
  static const infoSoft = accentBlueSoft;
  static const neutral = textMuted;
  static const neutralSoft = Color(0xFFEDEFF1);

  /// Hairline border for white cards on the warm background.
  static const cardBorder = Color(0x1A0F5C45);
}

class CareSpacing {
  const CareSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal gutter for caregiver screens.
  static const double screenH = 24;
}

class CareRadius {
  const CareRadius._();

  static const double card = 24;
  static const double tile = 20;
  static const double pill = 999;
}

class CareIconSize {
  const CareIconSize._();

  static const double feature = 28;
  static const double featureBackdrop = 56;
}

class CareSizes {
  const CareSizes._();

  /// Primary CTA height (68–72dp target).
  static const double ctaHeight = 70;

  /// Minimum height for any secondary tappable (Skip, Sign In).
  static const double minTouch = 48;

  /// Standard button height inside caregiver screens (primary/secondary actions).
  static const double buttonHeight = 56;
}

class CareShadows {
  const CareShadows._();

  static const card = [
    BoxShadow(color: Color(0x1A0B1F2A), blurRadius: 24, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0D0B1F2A), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const button = [BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 10))];

  /// Softer, green-tinted elevation for a filled CTA on a light background.
  static const buttonOnLight = [BoxShadow(color: Color(0x400F5C45), blurRadius: 20, offset: Offset(0, 8))];

  /// Barely-there lift for tiles.
  static const tile = [BoxShadow(color: Color(0x0F0B1F2A), blurRadius: 12, offset: Offset(0, 4))];
}

class CareText {
  const CareText._();

  static const TextStyle brandName = TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.6, color: CareColors.primaryDark);

  static const TextStyle tagline = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.25, color: CareColors.textMuted);

  static const TextStyle body = TextStyle(fontSize: 17.5, fontWeight: FontWeight.w400, height: 1.5, color: CareColors.textMuted);

  static const TextStyle featureLabel = TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500, height: 1.25, color: CareColors.textDark);

  static const TextStyle sectionTitle = TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3, color: CareColors.textDark);

  static const TextStyle cardTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25, color: CareColors.textDark);

  /// Secondary copy inside cards (smaller than [body], still comfortably readable).
  static const TextStyle cardBody = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4, color: CareColors.textMuted);

  static const TextStyle tileLabel = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.25, color: CareColors.textDark);

  static const TextStyle pillLabel = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CareColors.primaryDark);

  static const TextStyle cta = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: CareColors.primaryDark);

  /// Responsive hero headline. Scales with width, and with height on short screens, but never
  /// drops below a large display size.
  static TextStyle headline(Size screen) => TextStyle(
    fontSize: [screen.width * 0.102, screen.height * 0.05].reduce((a, b) => a < b ? a : b).clamp(32.0, 46.0),
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1.0,
    color: CareColors.textDark,
  );
}
