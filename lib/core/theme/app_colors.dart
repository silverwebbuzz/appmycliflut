import 'package:flutter/material.dart';

/// Font families bundled in `assets/fonts/` and registered in pubspec.yaml.
///
/// Sora carries headings, Manrope body and UI labels. Referenced by family
/// name so nothing is fetched at runtime.
const String kFontHeading = 'Sora';
const String kFontBody = 'Manrope';

/// Design tokens for the eClinicPro patient app.
///
/// Values are transcribed verbatim from the design prototype's CSS custom
/// properties (`:root` for light, `[data-theme="dark"]` for dark) in
/// `Mobile-Design/EClinicPro patient panel/Patient App.dc.html`.
///
/// The system is monochrome near-black: there is no chromatic brand hue.
/// `brand` is the ink-black used for primary actions, `amber` is the single
/// accent (used for lab/report affordances) and `red` is reserved for
/// destructive and overdue states.
///
/// Prefer reading these through [AppTokens] off the current [Theme] so a
/// widget follows light/dark automatically:
///
/// ```dart
/// final t = AppTokens.of(context);
/// Container(color: t.card, ...);
/// ```
///
/// The `static const` members on [AppColors] are the *light* values only.
/// They exist for `const` widget contexts and for screens not yet migrated;
/// they do not respond to dark mode.
class AppColorsLight {
  const AppColorsLight._();

  static const bg = Color(0xFFFFFFFF);
  static const card = Color(0xFFFAFAFA);
  static const ink = Color(0xFF0E0E0F);
  static const sub = Color(0xFF6B6C6F);
  static const line = Color(0xFFE6E6E8);
  static const brand = Color(0xFF111113);
  static const brandDeep = Color(0xFF0E0E10);
  static const brandSoft = Color(0xFFF0F0F2);
  static const amber = Color(0xFF6F5410);
  static const amberSoft = Color(0xFFF4EEDD);
  static const chip = Color(0xFFF1F1F3);
  static const navBg = Color(0xEDFFFFFF); // rgba(255,255,255,0.93)
  static const red = Color(0xFFA33421);
  static const redSoft = Color(0xFFF7E8E4);
  static const onBrand = Color(0xFFF3F3F4);
  static const onAccent = Color(0xFFFFFFFF);

  /// `--shadow`: 0 1px 2px rgba(0,0,0,.05), 0 10px 28px rgba(0,0,0,.06)
  static const shadow = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0F000000), offset: Offset(0, 10), blurRadius: 28),
  ];
}

/// Dark counterparts of [AppColorsLight], from `[data-theme="dark"]`.
class AppColorsDark {
  const AppColorsDark._();

  static const bg = Color(0xFF0B0B0C);
  static const card = Color(0xFF151517);
  static const ink = Color(0xFFF2F2F3);
  static const sub = Color(0xFF9A9B9E);
  static const line = Color(0xFF2A2A2D);
  static const brand = Color(0xFFE9E9EC);
  static const brandDeep = Color(0xFF161618);
  static const brandSoft = Color(0xFF212124);
  static const amber = Color(0xFFD9B46A);
  static const amberSoft = Color(0xFF332A14);
  static const chip = Color(0xFF222225);
  static const navBg = Color(0xED0D0D0E); // rgba(13,13,14,0.93)
  static const red = Color(0xFFE08A72);
  static const redSoft = Color(0xFF3A201C);
  static const onBrand = Color(0xFFECECEE);
  static const onAccent = Color(0xFF111113);

  /// `--shadow`: 0 1px 2px rgba(0,0,0,.5), 0 10px 28px rgba(0,0,0,.35)
  static const shadow = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x59000000), offset: Offset(0, 10), blurRadius: 28),
  ];
}

/// Light-mode token constants, usable in `const` contexts.
///
/// Also carries the legacy names the pre-re-skin screens were written
/// against, remapped onto the monochrome palette so those screens compile
/// and look correct until each is rebuilt.
class AppColors {
  const AppColors._();

  // Design tokens (light).
  static const bg = AppColorsLight.bg;
  static const card = AppColorsLight.card;
  static const ink = AppColorsLight.ink;
  static const sub = AppColorsLight.sub;
  static const line = AppColorsLight.line;
  static const brand = AppColorsLight.brand;
  static const brandDeep = AppColorsLight.brandDeep;
  static const brandSoft = AppColorsLight.brandSoft;
  static const amber = AppColorsLight.amber;
  static const amberSoft = AppColorsLight.amberSoft;
  static const chip = AppColorsLight.chip;
  static const navBg = AppColorsLight.navBg;
  static const red = AppColorsLight.red;
  static const redSoft = AppColorsLight.redSoft;
  static const onBrand = AppColorsLight.onBrand;
  static const onAccent = AppColorsLight.onAccent;
  static const shadow = AppColorsLight.shadow;

  // ---------------------------------------------------------------------
  // Legacy aliases. The green brand is gone; these now point at the
  // monochrome equivalents. Remove each as its screen is rebuilt.
  // ---------------------------------------------------------------------

  /// Was #00A86B. Primary action colour is now near-black ink.
  static const primary = brand;
  static const primaryDark = brandDeep;
  static const primarySoft = brandSoft;
  static const secondary = sub;
  static const background = bg;
  static const surface = card;
  static const textPrimary = ink;
  static const textSecondary = sub;
  static const error = red;

  /// The design has no green success colour; success reads as plain ink.
  static const success = ink;
  static const border = line;
  static const splashBg = brandDeep;
}

/// Theme-aware access to the design tokens.
///
/// Registered on both [ThemeData]s, so `AppTokens.of(context)` returns the
/// set matching the active brightness.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.card,
    required this.ink,
    required this.sub,
    required this.line,
    required this.brand,
    required this.brandDeep,
    required this.brandSoft,
    required this.amber,
    required this.amberSoft,
    required this.chip,
    required this.navBg,
    required this.red,
    required this.redSoft,
    required this.onBrand,
    required this.onAccent,
    required this.shadow,
  });

  final Color bg;
  final Color card;
  final Color ink;
  final Color sub;
  final Color line;
  final Color brand;
  final Color brandDeep;
  final Color brandSoft;
  final Color amber;
  final Color amberSoft;
  final Color chip;
  final Color navBg;
  final Color red;
  final Color redSoft;
  final Color onBrand;
  final Color onAccent;
  final List<BoxShadow> shadow;

  static const light = AppTokens(
    bg: AppColorsLight.bg,
    card: AppColorsLight.card,
    ink: AppColorsLight.ink,
    sub: AppColorsLight.sub,
    line: AppColorsLight.line,
    brand: AppColorsLight.brand,
    brandDeep: AppColorsLight.brandDeep,
    brandSoft: AppColorsLight.brandSoft,
    amber: AppColorsLight.amber,
    amberSoft: AppColorsLight.amberSoft,
    chip: AppColorsLight.chip,
    navBg: AppColorsLight.navBg,
    red: AppColorsLight.red,
    redSoft: AppColorsLight.redSoft,
    onBrand: AppColorsLight.onBrand,
    onAccent: AppColorsLight.onAccent,
    shadow: AppColorsLight.shadow,
  );

  static const dark = AppTokens(
    bg: AppColorsDark.bg,
    card: AppColorsDark.card,
    ink: AppColorsDark.ink,
    sub: AppColorsDark.sub,
    line: AppColorsDark.line,
    brand: AppColorsDark.brand,
    brandDeep: AppColorsDark.brandDeep,
    brandSoft: AppColorsDark.brandSoft,
    amber: AppColorsDark.amber,
    amberSoft: AppColorsDark.amberSoft,
    chip: AppColorsDark.chip,
    navBg: AppColorsDark.navBg,
    red: AppColorsDark.red,
    redSoft: AppColorsDark.redSoft,
    onBrand: AppColorsDark.onBrand,
    onAccent: AppColorsDark.onAccent,
    shadow: AppColorsDark.shadow,
  );

  /// Tokens for the theme in scope. Falls back to [light] if the extension
  /// is missing, so a widget used outside the app theme still renders.
  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? light;

  @override
  AppTokens copyWith({
    Color? bg,
    Color? card,
    Color? ink,
    Color? sub,
    Color? line,
    Color? brand,
    Color? brandDeep,
    Color? brandSoft,
    Color? amber,
    Color? amberSoft,
    Color? chip,
    Color? navBg,
    Color? red,
    Color? redSoft,
    Color? onBrand,
    Color? onAccent,
    List<BoxShadow>? shadow,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      sub: sub ?? this.sub,
      line: line ?? this.line,
      brand: brand ?? this.brand,
      brandDeep: brandDeep ?? this.brandDeep,
      brandSoft: brandSoft ?? this.brandSoft,
      amber: amber ?? this.amber,
      amberSoft: amberSoft ?? this.amberSoft,
      chip: chip ?? this.chip,
      navBg: navBg ?? this.navBg,
      red: red ?? this.red,
      redSoft: redSoft ?? this.redSoft,
      onBrand: onBrand ?? this.onBrand,
      onAccent: onAccent ?? this.onAccent,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      sub: Color.lerp(sub, other.sub, t)!,
      line: Color.lerp(line, other.line, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberSoft: Color.lerp(amberSoft, other.amberSoft, t)!,
      chip: Color.lerp(chip, other.chip, t)!,
      navBg: Color.lerp(navBg, other.navBg, t)!,
      red: Color.lerp(red, other.red, t)!,
      redSoft: Color.lerp(redSoft, other.redSoft, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      shadow: BoxShadow.lerpList(shadow, other.shadow, t)!,
    );
  }
}

/// Decoration helpers for surfaces the prototype styles by hand.
extension AppTokensDecoration on AppTokens {
  /// The standard elevated card: `--card` fill, 1px `--line` border,
  /// radius 16, `--shadow`.
  BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: line),
        boxShadow: shadow,
      );

  /// The dark hero surface ("next appointment", promo tiles): `--brand-deep`
  /// plus the prototype's `inset 0 1px 0 rgba(255,255,255,0.09)` hairline,
  /// which is what keeps this card legible against a dark background.
  BoxDecoration heroDecoration({double radius = AppRadii.xl}) => BoxDecoration(
        color: brandDeep,
        borderRadius: BorderRadius.circular(radius),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
        boxShadow: shadow,
      );
}

/// Corner radii from the prototype. Cards are 16, feature surfaces 18–20,
/// pills fully rounded. The old 12px default is deliberately not here.
class AppRadii {
  const AppRadii._();

  static const sm = 11.0;
  static const md = 14.0;
  static const card = 16.0;
  static const lg = 18.0;
  static const xl = 20.0;
  static const pill = 999.0;
}
