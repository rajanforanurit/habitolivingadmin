import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'tokens.dart';

/// Builds the shadcn ThemeData from [Tokens].
///
/// shadcn's ColorScheme expects the full 24-role set, so each token is mapped
/// to the role that fits it: brand green becomes `primary`, the neutral ramp
/// becomes background/card/muted, and the semantic colours become the chart and
/// status roles.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: Tokens.background,
    surface: Tokens.surface,
    surfaceAlt: Tokens.surfaceAlt,
    ink: Tokens.ink,
    inkMuted: Tokens.inkMuted,
    inkFaint: Tokens.inkFaint,
    line: Tokens.line,
    accent: Tokens.accent,
    onAccent: Tokens.accentOn,
    destructive: Tokens.danger,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: Tokens.backgroundDark,
    surface: Tokens.surfaceDark,
    surfaceAlt: Tokens.surfaceAltDark,
    ink: Tokens.inkDark,
    inkMuted: Tokens.inkMutedDark,
    inkFaint: Tokens.inkFaintDark,
    line: Tokens.lineDark,
    accent: Tokens.accentDark,
    onAccent: Tokens.accentOnDark,
    destructive: const Color(0xFFF2837B),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color ink,
    required Color inkMuted,
    required Color inkFaint,
    required Color line,
    required Color accent,
    required Color onAccent,
    required Color destructive,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      colorScheme: ColorScheme(
        brightness: brightness,
        background: background,
        foreground: ink,
        card: surface,
        cardForeground: ink,
        popover: surface,
        popoverForeground: ink,
        primary: accent,
        primaryForeground: onAccent,
        secondary: surfaceAlt,
        secondaryForeground: ink,
        muted: surfaceAlt,
        mutedForeground: inkMuted,
        accent: accent,
        accentForeground: onAccent,
        destructive: destructive,
        destructiveForeground: const Color(0xFFFFFFFF),
        border: line,
        input: line,
        ring: accent,
        chart1: accent,
        chart2: isDark ? const Color(0xFF7FB2E8) : const Color(0xFF2E6DA4),
        chart3: isDark ? const Color(0xFFD9A441) : const Color(0xFF9A6508),
        chart4: isDark ? const Color(0xFFB98BD8) : const Color(0xFF6B4A8F),
        chart5: isDark ? const Color(0xFF6FC3B0) : const Color(0xFF1C7A54),
      ),
      // shadcn multiplies this base radius for every component. 0.5 * 16 = 8px
      // on a medium control; small enough to read as precise rather than soft.
      radius: 0.5,
      scaling: 1,
      typography: _typography(),
      surfaceOpacity: isDark ? 0.12 : 0.04,
      surfaceBlur: 8,
      density: Density.defaultDensity, // 16px container / 8px gap base
    );
  }

  /// Instrument Sans for everything, Plus Jakarta Sans for figures and the
  /// wordmark. Sizes follow the tokens; body copy is capped at 15-17px so list
  /// rows stay compact without feeling cramped.
  static Typography _typography() {
    final sans = TextStyle(fontFamily: Tokens.fontFamily, color: Tokens.ink);

    return Typography(
      sans: sans,
      mono: const TextStyle(
        fontFamily: Tokens.fontFamily,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      xSmall: sans.copyWith(fontSize: Tokens.typeXs, height: 1.35),
      small: sans.copyWith(fontSize: Tokens.typeSm, height: 1.4),
      base: sans.copyWith(fontSize: Tokens.typeBase, height: 1.45),
      large: sans.copyWith(fontSize: Tokens.typeMd, height: 1.4),
      xLarge: sans.copyWith(fontSize: Tokens.typeLg, height: 1.3),
      x2Large: sans.copyWith(
        fontSize: Tokens.typeXl,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      x3Large: sans.copyWith(
        fontSize: Tokens.type2Xl,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      x4Large: sans.copyWith(
        fontSize: Tokens.type3Xl,
        height: 1.15,
        fontWeight: FontWeight.w600,
      ),
      x5Large: sans.copyWith(
        fontSize: 48,
        height: 1.1,
        fontWeight: FontWeight.w600,
      ),
      x6Large: sans.copyWith(
        fontSize: 60,
        height: 1.05,
        fontWeight: FontWeight.w600,
      ),
      x7Large: sans.copyWith(
        fontSize: 72,
        height: 1.05,
        fontWeight: FontWeight.w600,
      ),
      x8Large: sans.copyWith(
        fontSize: 96,
        height: 1,
        fontWeight: FontWeight.w600,
      ),
      x9Large: sans.copyWith(
        fontSize: 144,
        height: 1,
        fontWeight: FontWeight.w600,
      ),

      thin: const TextStyle(fontWeight: FontWeight.w100),
      extraLight: const TextStyle(fontWeight: FontWeight.w200),
      light: const TextStyle(fontWeight: FontWeight.w300),
      normal: const TextStyle(fontWeight: FontWeight.w400),
      medium: const TextStyle(fontWeight: FontWeight.w500),
      semiBold: const TextStyle(fontWeight: FontWeight.w600),
      bold: const TextStyle(fontWeight: FontWeight.w700),
      extraBold: const TextStyle(fontWeight: FontWeight.w800),
      black: const TextStyle(fontWeight: FontWeight.w900),
      italic: const TextStyle(fontStyle: FontStyle.italic),

      h1: sans.copyWith(
        fontSize: Tokens.type2Xl,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      h2: sans.copyWith(
        fontSize: Tokens.typeXl,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
      ),
      h3: sans.copyWith(
        fontSize: Tokens.typeLg,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      h4: sans.copyWith(
        fontSize: Tokens.typeMd,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      p: sans.copyWith(fontSize: Tokens.typeBase, height: 1.5),
      lead: sans.copyWith(
        fontSize: Tokens.typeMd,
        height: 1.5,
        color: Tokens.inkMuted,
      ),
      textLarge: sans.copyWith(fontSize: Tokens.typeMd, height: 1.4),
      textSmall: sans.copyWith(fontSize: Tokens.typeSm, height: 1.4),
      textMuted: sans.copyWith(
        fontSize: Tokens.typeSm,
        height: 1.4,
        color: Tokens.inkFaint,
      ),
      blockQuote: sans.copyWith(
        fontSize: Tokens.typeBase,
        height: 1.5,
        fontStyle: FontStyle.italic,
      ),
      inlineCode: sans.copyWith(
        fontSize: Tokens.typeSm,
        fontFamily: Tokens.fontFamily,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
