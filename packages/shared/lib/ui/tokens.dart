import 'package:flutter/widgets.dart';

/// Habito Living design tokens.
///
/// These are the single source of truth for colour, type and spacing. Every
/// screen reads from here (or from the shadcn ThemeData derived from it) so a
/// change here is the only change needed.
///
/// The palette is intentionally quiet: a near-white neutral ground, dark green
/// ink, and one accent used sparingly. Colour lives in the data (charts, status
/// dots, invoice amounts), never spread across chrome.
class Tokens {
  Tokens._();

  // ---------------------------------------------------------------- surfaces
  // Colour is resolved through a [Palette] instead of being a constant, so the
  // same `Tokens.ink` reads as near-black in light mode and near-white in dark
  // mode. The palette is swapped once per frame by the app root; spacing, type
  // and radii stay const (they are brightness-independent).
  static Palette _palette = Palette.light;

  /// The palette every colour getter below resolves against.
  static Palette get palette => _palette;

  /// Switches the active palette. Called by the app root when the theme mode
  /// changes; the whole tree is rebuilt right after, so no widget is left
  /// holding a stale colour.
  static void apply(Palette palette) => _palette = palette;

  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceAlt => _palette.surfaceAlt; // rows, wells, chips
  static Color get surfaceSunken => _palette.surfaceSunken;

  // --------------------------------------------------------------------- ink
  static Color get ink => _palette.ink; // headings, body copy
  static Color get inkMuted => _palette.inkMuted; // secondary copy
  static Color get inkFaint => _palette.inkFaint; // labels, captions, meta

  // ------------------------------------------------------------------ lines
  static Color get line => _palette.line; // hairline borders
  static Color get lineStrong => _palette.lineStrong;

  // ----------------------------------------------------------------- accent
  // One accent: the brand colour. Reserved for the primary action, the selected
  // state, and the single number that matters on a screen.
  static Color get accent => _palette.accent;
  static Color get accentHover => _palette.accentHover;
  static Color get accentPressed => _palette.accentPressed;
  static Color get accentOn => _palette.accentOn; // text on accent
  static Color get accentTint => _palette.accentTint; // soft accent background

  // -------------------------------------------------------------- semantic
  static Color get positive => _palette.positive;
  static Color get positiveTint => _palette.positiveTint;
  static Color get warning => _palette.warning;
  static Color get warningTint => _palette.warningTint;
  static Color get danger => _palette.danger;
  static Color get dangerTint => _palette.dangerTint;
  static Color get info => _palette.info;
  static Color get infoTint => _palette.infoTint;
  static Color get neutralTag => _palette.neutralTag;
  static Color get neutralTagTint => _palette.neutralTagTint;

  // The dark ramp, exposed under its own names for the few places that need a
  // fixed colour regardless of the active mode (splash screens, illustrations).
  static Color get backgroundDark => Palette.dark.background;
  static Color get surfaceDark => Palette.dark.surface;
  static Color get surfaceAltDark => Palette.dark.surfaceAlt;
  static Color get surfaceSunkenDark => Palette.dark.surfaceSunken;
  static Color get inkDark => Palette.dark.ink;
  static Color get inkMutedDark => Palette.dark.inkMuted;
  static Color get inkFaintDark => Palette.dark.inkFaint;
  static Color get lineDark => Palette.dark.line;
  static Color get lineStrongDark => Palette.dark.lineStrong;
  static Color get accentDark => Palette.dark.accent;
  static Color get accentOnDark => Palette.dark.accentOn;
  static Color get accentTintDark => Palette.dark.accentTint;

  // ------------------------------------------------------------- radii (px)
  // Small radii. Nothing on a card or input exceeds 16.
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusFull = 999;

  // ----------------------------------------------------------- spacing (px)
  // 4px grid. Use these, never ad-hoc values.
  //
  // The vertical rhythm the screens follow:
  //   header bottom gap      space6 (20)
  //   section label → content space2 (8)
  //   card → card / form gap space5 (16)
  //   card inner padding     space5 (16)
  //   scroll bottom padding  kScreenBottomPadding (24)
  //
  // space4 is the workhorse gap/padding step inside cards and rows: 12 reads
  // as a single step, while a page gutter (20) plus any inner padding would
  // stack to 32+ per side and make the layout look empty.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 10;
  static const double space4 = 12;
  static const double space5 = 16;
  static const double space6 = 20;
  static const double space7 = 28;
  static const double space8 = 36;
  static const double space9 = 44;

  // Page gutters — the single horizontal grid every screen aligns to.
  //
  // The header, section labels, cards, form fields, list items and the primary
  // bottom action all start and end on this line. It was 12, which read as a
  // narrow strip on modern phones; 20 matches Material 3's large-screen
  // margins and leaves the thumb-reach clear.
  static const double gutter = 20;
  static const double gutterWide = 24;

  // -------------------------------------------------------------- type scale
  static const String fontFamily = 'InstrumentSans';
  static const String fontFamilyFigure = 'PlusJakartaSans';

  /// Pass codes, references and invoice numbers. A platform monospace: no mono
  /// face is vendored, and the system one is the right default for codes.
  static const String fontMono = 'monospace';

  static const double typeXs = 12;
  static const double typeSm = 13;
  static const double typeBase = 15;
  static const double typeMd = 17;
  static const double typeLg = 20;
  static const double typeXl = 24;
  static const double type2Xl = 30;
  static const double type3Xl = 36;

  // --------------------------------------------------------- component sizes
  static const double controlHeight = 44; // inputs, buttons
  static const double rowHeight = 56; // list rows
  static const double compactRowHeight = 44;
  static const double tabBarHeight = 64;
  static const double navRailWidth = 248;
  static const double bottomNavHeight = 64;

  // ------------------------------------------------------------- motion (ms)
  static const int motionFast = 120;
  static const int motionBase = 200;
  static const int motionSlow = 320;

  // ------------------------------------------------------------ breakpoints
  static const double breakpointCompact = 600;
  static const double breakpointMedium = 905;
  static const double breakpointExpanded = 1280;
}

/// A complete set of colour roles for one brightness.
///
/// The light palette is the brand: a near-white neutral ground, dark green ink
/// and one accent. The dark palette is the same ramp inverted — not a pure
/// black, and not a colour-shifted copy, so the two read as the same product.
class Palette {
  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.accentOn,
    required this.accentTint,
    required this.positive,
    required this.positiveTint,
    required this.warning,
    required this.warningTint,
    required this.danger,
    required this.dangerTint,
    required this.info,
    required this.infoTint,
    required this.neutralTag,
    required this.neutralTagTint,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSunken;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color line;
  final Color lineStrong;
  final Color accent;
  final Color accentHover;
  final Color accentPressed;
  final Color accentOn;
  final Color accentTint;
  final Color positive;
  final Color positiveTint;
  final Color warning;
  final Color warningTint;
  final Color danger;
  final Color dangerTint;
  final Color info;
  final Color infoTint;
  final Color neutralTag;
  final Color neutralTagTint;

  static const Palette light = Palette(
    background: Color(0xFFFBFAF8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F3F0),
    surfaceSunken: Color(0xFFEFEDE9),
    ink: Color(0xFF141B19),
    inkMuted: Color(0xFF4A534F),
    inkFaint: Color(0xFF5A625E),
    line: Color(0xFFE3DFD9),
    lineStrong: Color(0xFFCFCAC2),
    accent: Color(0xFF0E6B52),
    accentHover: Color(0xFF0B5844),
    accentPressed: Color(0xFF084535),
    accentOn: Color(0xFFFFFFFF),
    accentTint: Color(0xFFE7F1EC),
    positive: Color(0xFF1C7A54),
    positiveTint: Color(0xFFE5F3EC),
    warning: Color(0xFF855507),
    warningTint: Color(0xFFFBF0DA),
    danger: Color(0xFFB3261E),
    dangerTint: Color(0xFFFCEBE9),
    info: Color(0xFF27568F),
    infoTint: Color(0xFFE8EFF8),
    neutralTag: Color(0xFF4A534F),
    neutralTagTint: Color(0xFFEFEDE9),
  );

  static const Palette dark = Palette(
    background: Color(0xFF101413),
    surface: Color(0xFF161B1A),
    surfaceAlt: Color(0xFF1E2423),
    surfaceSunken: Color(0xFF0B0F0E),
    ink: Color(0xFFF2F0EC),
    inkMuted: Color(0xFFB4BAB6),
    inkFaint: Color(0xFF9AA29C),
    line: Color(0xFF2A302E),
    lineStrong: Color(0xFF3B423F),
    accent: Color(0xFF5BC9A5),
    accentHover: Color(0xFF74D6B6),
    accentPressed: Color(0xFF46B48F),
    accentOn: Color(0xFF07120E),
    accentTint: Color(0xFF14312A),
    positive: Color(0xFF6FC3A0),
    positiveTint: Color(0xFF16302A),
    warning: Color(0xFFD9A441),
    warningTint: Color(0xFF2E2517),
    danger: Color(0xFFF2837B),
    dangerTint: Color(0xFF351B1A),
    info: Color(0xFF7FB2E8),
    infoTint: Color(0xFF17253A),
    neutralTag: Color(0xFFB4BAB6),
    neutralTagTint: Color(0xFF242A28),
  );
}
