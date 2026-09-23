import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';


TextStyle _sora({
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
  double? height,
  Color? color,
}) =>
    TextStyle(
      fontFamily: kFontHeading,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );

TextStyle _manrope({
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
  double? height,
  Color? color,
}) =>
    TextStyle(
      fontFamily: kFontBody,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );

/// Builds the light and dark themes from the design tokens in
/// [AppColors] / [AppTokens].
///
/// Type follows the prototype: Sora for headings (w700/w800, tight
/// tracking) and Manrope for body and UI labels (w400–w800). Radii are
/// 16–20, never the Material default 12.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// Small-caps label style used for the prototype's section eyebrows,
  /// e.g. "NEXT APPOINTMENT" — `font:800 11px; letter-spacing:.12em`.
  static TextStyle eyebrow(BuildContext context) {
    final t = AppTokens.of(context);
    return _manrope(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.12 * 11,
      color: t.sub,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final t = isDark ? AppTokens.dark : AppTokens.light;

    // Monochrome scheme: the "primary" is ink, not a hue. Built by hand
    // rather than fromSeed so Material cannot reintroduce a tint.
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.brand,
      onPrimary: t.onAccent,
      primaryContainer: t.brandSoft,
      onPrimaryContainer: t.ink,
      secondary: t.amber,
      onSecondary: t.onAccent,
      secondaryContainer: t.amberSoft,
      onSecondaryContainer: t.amber,
      surface: t.bg,
      onSurface: t.ink,
      surfaceContainerLowest: t.bg,
      surfaceContainerLow: t.card,
      surfaceContainer: t.card,
      surfaceContainerHigh: t.chip,
      surfaceContainerHighest: t.chip,
      onSurfaceVariant: t.sub,
      outline: t.line,
      outlineVariant: t.line,
      error: t.red,
      onError: t.onAccent,
      errorContainer: t.redSoft,
      onErrorContainer: t.red,
    );

    final textTheme = _textTheme(t);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      dividerColor: t.line,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[t],
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _sora(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.02 * 18,
          color: t.ink,
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: t.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: t.line),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.brand,
          foregroundColor: t.onAccent,
          disabledBackgroundColor: t.chip,
          disabledForegroundColor: t.sub,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: _manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: t.line),
          textStyle: _manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.ink,
          textStyle: _manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.card,
        hintStyle: _manrope(fontSize: 15, color: t.sub),
        labelStyle: _manrope(fontSize: 15, color: t.sub),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: _inputBorder(t.line),
        enabledBorder: _inputBorder(t.line),
        focusedBorder: _inputBorder(t.brand, width: 1.5),
        errorBorder: _inputBorder(t.red),
        focusedErrorBorder: _inputBorder(t.red, width: 1.5),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: t.chip,
        selectedColor: t.brand,
        side: BorderSide(color: t.line),
        labelStyle: _manrope(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: t.ink,
        ),
        shape: const StadiumBorder(),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.navBg,
        selectedItemColor: t.ink,
        unselectedItemColor: t.sub,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle:
            _manrope(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            _manrope(fontSize: 10, fontWeight: FontWeight.w700),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.navBg,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => _manrope(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected) ? t.ink : t.sub,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected) ? t.ink : t.sub,
          ),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: t.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.brandDeep,
        contentTextStyle: _manrope(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColorsLight.onBrand,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),

      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: t.ink, size: 21),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.brand),

      listTileTheme: ListTileThemeData(
        iconColor: t.sub,
        textColor: t.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onAccent : t.sub,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.brand : t.chip,
        ),
        trackOutlineColor: WidgetStateProperty.all(t.line),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Sora for display/headline/title, Manrope for body and labels.
  static TextTheme _textTheme(AppTokens t) {
    TextStyle sora(double size, FontWeight weight, {Color? color}) =>
        _sora(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: -0.02 * size,
          height: 1.2,
          color: color ?? t.ink,
        );

    TextStyle manrope(double size, FontWeight weight, {Color? color}) =>
        _manrope(
          fontSize: size,
          fontWeight: weight,
          height: 1.5,
          color: color ?? t.ink,
        );

    return TextTheme(
      displayLarge: sora(30, FontWeight.w800),
      displayMedium: sora(26, FontWeight.w800),
      displaySmall: sora(24, FontWeight.w800),
      headlineLarge: sora(22, FontWeight.w800),
      headlineMedium: sora(20, FontWeight.w800),
      headlineSmall: sora(18, FontWeight.w800),
      titleLarge: sora(17, FontWeight.w800),
      titleMedium: sora(15, FontWeight.w700),
      titleSmall: sora(13, FontWeight.w800),
      bodyLarge: manrope(15, FontWeight.w500),
      bodyMedium: manrope(13.5, FontWeight.w600),
      bodySmall: manrope(12.5, FontWeight.w600, color: t.sub),
      labelLarge: manrope(13.5, FontWeight.w700),
      labelMedium: manrope(12, FontWeight.w700, color: t.sub),
      labelSmall: manrope(11, FontWeight.w800, color: t.sub),
    );
  }
}
