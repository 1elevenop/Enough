import 'package:flutter/material.dart';

/// Design tokens. Warm paper canvas, ink text, one magenta accent.
class Tokens {
  const Tokens._({
    required this.canvas,
    required this.surface,
    required this.surfaceSoft,
    required this.ink,
    required this.muted,
    required this.line,
    required this.locked,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceSoft;
  final Color ink;
  final Color muted;
  final Color line;
  final Color locked;

  /// Brand magenta, from the logo.
  static const accent = Color(0xFFFF2BD6);
  static const danger = Color(0xFFE5484D);
  static const radius = 28.0;

  static const light = Tokens._(
    canvas: Color(0xFFF5F4F0),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFEDEBE6),
    ink: Color(0xFF111113),
    muted: Color(0xFF8B8A86),
    line: Color(0xFFE4E2DC),
    locked: Color(0xFFEDECE8),
  );

  static const dark = Tokens._(
    canvas: Color(0xFF0D0D0F),
    surface: Color(0xFF17171A),
    surfaceSoft: Color(0xFF1F1F23),
    ink: Color(0xFFF3F2EE),
    muted: Color(0xFF8C8B90),
    line: Color(0xFF26262B),
    locked: Color(0xFF1B1B1F),
  );

  static Tokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

TextTheme _text(Tokens t) {
  TextStyle display(double size, FontWeight w, double tracking) => TextStyle(
    fontFamily: 'InterTight',
    fontSize: size,
    fontWeight: w,
    letterSpacing: tracking,
    color: t.ink,
    height: 1.05,
  );
  return TextTheme(
        displayLarge: display(56, FontWeight.w700, -2.0),
        displayMedium: display(46, FontWeight.w700, -1.8),
        headlineLarge: display(34, FontWeight.w700, -1.2),
        titleSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      )
      .copyWith(
        displaySmall: display(40, FontWeight.w700, -1.6),
        headlineMedium: display(30, FontWeight.w700, -1.0),
        headlineSmall: display(24, FontWeight.w700, -0.6),
        titleLarge: display(20, FontWeight.w600, -0.4),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          height: 1.4,
          letterSpacing: -0.1,
        ),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, height: 1.4),
        bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 12, height: 1.35),
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      )
      .apply(bodyColor: t.ink, displayColor: t.ink);
}

ThemeData buildTheme(Brightness b) {
  final t = b == Brightness.dark ? Tokens.dark : Tokens.light;
  final scheme = ColorScheme(
    brightness: b,
    primary: t.ink,
    onPrimary: t.canvas,
    secondary: Tokens.accent,
    onSecondary: const Color(0xFF111113),
    error: Tokens.danger,
    onError: Colors.white,
    surface: t.surface,
    onSurface: t.ink,
    onSurfaceVariant: t.muted,
    surfaceContainerHighest: t.surfaceSoft,
    outline: t.line,
    outlineVariant: t.line,
  );
  final text = _text(t);
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.canvas,
    canvasColor: t.canvas,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: t.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: t.ink,
      titleTextStyle: text.titleMedium,
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radius),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: t.line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radius),
      ),
      titleTextStyle: text.titleLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.ink,
        foregroundColor: t.canvas,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: pill,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.ink,
        shape: pill,
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.surfaceSoft,
      selectedColor: t.ink,
      labelStyle: text.labelLarge?.copyWith(fontSize: 13, color: t.ink),
      secondaryLabelStyle: text.labelLarge?.copyWith(
        fontSize: 13,
        color: t.canvas,
      ),
      checkmarkColor: t.canvas,
      side: BorderSide.none,
      shape: pill,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.canvas : t.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.ink : t.surfaceSoft,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: t.ink,
      inactiveTrackColor: t.line,
      thumbColor: t.ink,
      overlayColor: t.ink.withValues(alpha: .08),
      trackHeight: 3,
      showValueIndicator: ShowValueIndicator.onDrag,
      valueIndicatorColor: t.ink,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.ink : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(t.canvas),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: t.ink,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall?.copyWith(color: t.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: t.canvas),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.ink,
      linearTrackColor: t.line,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(pill),
        side: WidgetStatePropertyAll(BorderSide(color: t.line)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.ink : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.canvas : t.ink,
        ),
      ),
    ),
  );
}
