import 'package:flutter/material.dart';

import 'care_tokens.dart';

/// The one Sathi ThemeData for the whole app — built only from [care_tokens.dart], the same
/// tokens as onboarding pages 1 and 2, so every themed Material widget (app bars, cards,
/// buttons, inputs, chips, dialogs, sheets, snackbars, switches, navigation) matches them.
///
/// [comfort] is the same design at elder-friendly sizes: larger type and 64dp buttons.
/// The app uses it while an elder is signed in (see app.dart); everything else is identical.
class CareTheme {
  const CareTheme._();

  static ThemeData data({bool comfort = false}) {
    double sz(double standard, double large) => comfort ? large : standard;

    final scheme = ColorScheme.fromSeed(seedColor: CareColors.primary, brightness: Brightness.light).copyWith(
      primary: CareColors.primaryDark,
      onPrimary: Colors.white,
      primaryContainer: CareColors.primarySoft,
      onPrimaryContainer: CareColors.primaryDeepest,
      secondary: CareColors.primary,
      secondaryContainer: CareColors.primarySoft,
      onSecondaryContainer: CareColors.primaryDeepest,
      tertiary: CareColors.accentWarm,
      tertiaryContainer: CareColors.accentWarmSoft,
      surface: CareColors.surface,
      onSurface: CareColors.textDark,
      onSurfaceVariant: CareColors.textMuted,
      surfaceContainerLowest: CareColors.surface,
      surfaceContainerLow: CareColors.background,
      surfaceContainer: CareColors.background,
      surfaceContainerHigh: CareColors.primarySoft,
      outline: CareColors.primaryTint,
      outlineVariant: CareColors.primarySoft,
      error: CareColors.danger,
      errorContainer: CareColors.dangerSoft,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    const pill = StadiumBorder();
    final fieldRadius = BorderRadius.circular(CareRadius.tile);
    final buttonHeight = sz(CareSizes.buttonHeight, 64);
    final buttonText = TextStyle(fontSize: sz(18, 21), fontWeight: FontWeight.w800);

    return base.copyWith(
      scaffoldBackgroundColor: CareColors.background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: CareColors.primarySoft,
      textTheme: base.textTheme.copyWith(
        // Typed text in every field is drawn with bodyLarge — its colour MUST be explicit,
        // or entered text renders invisible (covered by tests).
        bodyLarge: TextStyle(fontSize: sz(18, 21), height: 1.4, color: CareColors.inputText),
        bodyMedium: TextStyle(fontSize: sz(16, 19), height: 1.4, color: CareColors.textMuted),
        bodySmall: TextStyle(fontSize: sz(14, 16.5), height: 1.35, color: CareColors.textMuted),
        titleLarge: TextStyle(fontSize: sz(22, 25), fontWeight: FontWeight.w800, letterSpacing: -0.3, color: CareColors.textDark),
        titleMedium: TextStyle(fontSize: sz(18, 21), fontWeight: FontWeight.w700, color: CareColors.textDark),
        titleSmall: TextStyle(fontSize: sz(16, 18), fontWeight: FontWeight.w700, color: CareColors.textDark),
        headlineMedium: TextStyle(fontSize: sz(30, 32), fontWeight: FontWeight.w800, letterSpacing: -0.6, color: CareColors.textDark),
        headlineSmall: TextStyle(fontSize: sz(24, 27), fontWeight: FontWeight.w800, letterSpacing: -0.4, color: CareColors.textDark),
        labelLarge: TextStyle(fontSize: sz(17, 20), fontWeight: FontWeight.w700),
      ),
      iconTheme: const IconThemeData(color: CareColors.primaryDark),
      appBarTheme: AppBarTheme(
        backgroundColor: CareColors.background,
        foregroundColor: CareColors.textDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: sz(64, 68),
        // Lines titles up with the 20dp content edge used across screens.
        titleSpacing: CareSpacing.screenH - 4,
        titleTextStyle: TextStyle(fontSize: sz(26, 28), fontWeight: FontWeight.w800, letterSpacing: -0.5, color: CareColors.textDark),
        iconTheme: IconThemeData(color: CareColors.textDark, size: sz(26, 28)),
        actionsIconTheme: IconThemeData(color: CareColors.primaryDark, size: sz(26, 28)),
      ),
      cardTheme: CardThemeData(
        color: CareColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: CareSpacing.sm - 2),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CareRadius.card),
          side: const BorderSide(color: CareColors.cardBorder),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: CareColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: CareSpacing.lg + 2, vertical: CareSpacing.xs),
        minTileHeight: sz(64, 72),
        titleTextStyle: TextStyle(fontSize: sz(17.5, 20), fontWeight: FontWeight.w700, color: CareColors.textDark),
        subtitleTextStyle: TextStyle(fontSize: sz(15.5, 17.5), height: 1.35, color: CareColors.textMuted),
        leadingAndTrailingTextStyle: TextStyle(fontSize: sz(17, 20), fontWeight: FontWeight.w800, color: CareColors.textDark),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(CareRadius.card))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CareColors.primaryDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CareColors.primaryTint,
          disabledForegroundColor: Colors.white,
          minimumSize: Size(64, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: CareSpacing.xl),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CareColors.primaryDark,
          foregroundColor: Colors.white,
          minimumSize: Size(64, buttonHeight),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CareColors.primaryDark,
          backgroundColor: CareColors.primarySoft,
          minimumSize: Size(64, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: CareSpacing.xl),
          shape: pill,
          side: BorderSide.none,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CareColors.primary,
          minimumSize: const Size(48, CareSizes.minTouch),
          shape: pill,
          textStyle: TextStyle(fontSize: sz(16.5, 18.5), fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: CareColors.primaryDark, minimumSize: const Size(CareSizes.minTouch, CareSizes.minTouch)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: CareColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 6,
        shape: const StadiumBorder(),
        extendedTextStyle: TextStyle(fontSize: sz(17, 19), fontWeight: FontWeight.w800),
        extendedPadding: const EdgeInsets.symmetric(horizontal: CareSpacing.xl),
        extendedSizeConstraints: BoxConstraints(minHeight: buttonHeight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CareColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: CareSpacing.lg + 2, vertical: CareSpacing.lg + 2),
        labelStyle: TextStyle(fontSize: sz(17, 19), color: CareColors.textMuted),
        floatingLabelStyle: TextStyle(fontSize: sz(17, 19), fontWeight: FontWeight.w600, color: CareColors.primaryDark),
        hintStyle: TextStyle(fontSize: sz(17, 19), color: const Color(0xFF7D8B94)),
        helperStyle: TextStyle(fontSize: sz(14, 16), color: CareColors.textMuted),
        // Guidance and validation messages wrap instead of being cut off.
        helperMaxLines: 3,
        errorMaxLines: 3,
        errorStyle: TextStyle(fontSize: sz(14.5, 16.5), fontWeight: FontWeight.w600),
        prefixIconColor: CareColors.primary,
        suffixIconColor: CareColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: CareColors.primaryTint),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: CareColors.primaryTint),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: CareColors.primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: CareColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: CareColors.danger, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: CareColors.primarySoft),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: CareColors.primaryDark,
        selectionColor: CareColors.primaryTint,
        selectionHandleColor: CareColors.primaryDark,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CareColors.primarySoft,
        selectedColor: CareColors.primaryDark,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(fontSize: sz(14.5, 17), fontWeight: FontWeight.w700, color: CareColors.primaryDark),
        secondaryLabelStyle: TextStyle(fontSize: sz(14.5, 17), fontWeight: FontWeight.w700, color: Colors.white),
        side: BorderSide.none,
        shape: pill,
        padding: const EdgeInsets.symmetric(horizontal: CareSpacing.sm, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: CareColors.surface,
          foregroundColor: CareColors.primaryDark,
          selectedBackgroundColor: CareColors.primarySoft,
          selectedForegroundColor: CareColors.primaryDeepest,
          side: const BorderSide(color: CareColors.primaryTint),
          minimumSize: Size(48, sz(48, 56)),
          textStyle: TextStyle(fontSize: sz(15.5, 18), fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : CareColors.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? CareColors.primary : CareColors.primarySoft),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : CareColors.primaryTint),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? CareColors.primaryDark : Colors.transparent),
        side: const BorderSide(color: CareColors.primary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CareColors.primary,
        linearTrackColor: CareColors.primarySoft,
        circularTrackColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CareColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: TextStyle(fontSize: sz(22, 25), fontWeight: FontWeight.w800, color: CareColors.textDark),
        contentTextStyle: TextStyle(fontSize: sz(17, 20), height: 1.45, color: CareColors.textMuted),
        actionsPadding: const EdgeInsets.fromLTRB(CareSpacing.xl, 0, CareSpacing.xl, CareSpacing.xl),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: CareColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        dialBackgroundColor: CareColors.primarySoft,
        hourMinuteColor: CareColors.primarySoft,
        hourMinuteTextColor: CareColors.primaryDeepest,
        dayPeriodColor: CareColors.primaryTint,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CareColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CareColors.primaryDeepest,
        contentTextStyle: TextStyle(fontSize: sz(16, 18), fontWeight: FontWeight.w600, color: Colors.white),
        actionTextColor: CareColors.primaryTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CareRadius.tile)),
        insetPadding: const EdgeInsets.fromLTRB(CareSpacing.lg, 0, CareSpacing.lg, CareSpacing.lg),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CareColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: sz(76, 82),
        indicatorColor: CareColors.primarySoft,
        indicatorShape: pill,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: sz(26, 28), color: s.contains(WidgetState.selected) ? CareColors.primaryDark : CareColors.textMuted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: sz(13.5, 15),
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? CareColors.primaryDark : CareColors.textMuted,
          ),
        ),
      ),
    );
  }
}
