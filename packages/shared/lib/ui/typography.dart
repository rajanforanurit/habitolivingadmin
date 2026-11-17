import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Project text styles that do not fit inside shadcn's fixed `Typography` set.
///
/// shadcn's [Typography] is a closed list of roles, so the handful of extra
/// styles the app needs (figures, captions, section labels, buttons) live here
/// and are reached through [context.st].
///
/// Sizes come from [Tokens]; nothing here should hardcode a size.
@immutable
class AppTextStyles {
  const AppTextStyles({
    required this.display,
    required this.title,
    required this.figure,
    required this.figureLarge,
    required this.caption,
    required this.label,
    required this.sectionLabel,
    required this.button,
    required this.navLabel,
    required this.mono,
  });

  /// Big money/metric figure. Used once per screen at most.
  final TextStyle display;

  /// Section title figure, one step down from [display].
  final TextStyle title;

  /// Tabular figure for tables, invoice lines and counters.
  final TextStyle figure;

  /// Same as [figure] but a step larger, for dashboard numbers.
  final TextStyle figureLarge;

  /// Meta text under a title. Faint by default.
  final TextStyle caption;

  /// Form labels and field names.
  final TextStyle label;

  /// Small sentence-case label above a group. Never all-caps.
  final TextStyle sectionLabel;

  /// Button and action labels.
  final TextStyle button;

  /// Navigation labels (bottom nav, rail).
  final TextStyle navLabel;

  /// Tabular figures for ids, phone numbers, plates.
  final TextStyle mono;

  static final String _sans = Tokens.fontFamily;
  static final String _figure = Tokens.fontFamilyFigure;

  static AppTextStyles of(BuildContext context) {
    final provided = context
        .dependOnInheritedWidgetOfExactType<_AppTextStylesScope>();
    return provided?.styles ?? light();
  }

  /// Light build. Figures use the variable weight range of Plus Jakarta Sans.
  static AppTextStyles light() {
    final sans = TextStyle(fontFamily: _sans, color: Tokens.ink);
    return AppTextStyles(
      display: sans.copyWith(
        fontFamily: _figure,
        fontSize: Tokens.type3Xl,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      title: sans.copyWith(
        fontFamily: _figure,
        fontSize: Tokens.type2Xl,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      figure: sans.copyWith(
        fontFamily: _figure,
        fontSize: Tokens.typeBase,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      figureLarge: sans.copyWith(
        fontFamily: _figure,
        fontSize: Tokens.type2Xl,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      caption: sans.copyWith(
        fontSize: Tokens.typeXs,
        height: 1.35,
        color: Tokens.inkFaint,
      ),
      label: sans.copyWith(
        fontSize: Tokens.typeSm,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: Tokens.inkMuted,
      ),
      sectionLabel: sans.copyWith(
        fontSize: Tokens.typeXs,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: Tokens.inkFaint,
      ),
      button: sans.copyWith(
        fontSize: Tokens.typeBase,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
      navLabel: sans.copyWith(
        fontSize: Tokens.typeXs,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
      mono: sans.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }

  /// Dark build. Only the ink colours change; metrics stay identical so a theme
  /// switch does not move anything.
  static AppTextStyles dark() {
    final base = light();
    final ink = Tokens.inkDark;
    return AppTextStyles(
      display: base.display.copyWith(color: ink),
      title: base.title.copyWith(color: ink),
      figure: base.figure.copyWith(color: ink),
      figureLarge: base.figureLarge.copyWith(color: ink),
      caption: base.caption.copyWith(color: Tokens.inkFaintDark),
      label: base.label.copyWith(color: Tokens.inkMutedDark),
      sectionLabel: base.sectionLabel.copyWith(color: Tokens.inkFaintDark),
      button: base.button.copyWith(color: ink),
      navLabel: base.navLabel.copyWith(color: ink),
      mono: base.mono.copyWith(color: ink),
    );
  }
}

/// Provides [AppTextStyles] to the tree. Mounted once in `app.dart` under the
/// shadcn theme so every screen can read styles with `context.st`.
class AppTextStylesScope extends InheritedWidget {
  const AppTextStylesScope({
    super.key,
    required this.styles,
    required super.child,
  });

  final AppTextStyles styles;

  @override
  bool updateShouldNotify(AppTextStylesScope old) => old.styles != styles;
}

class _AppTextStylesScope extends InheritedWidget {
  const _AppTextStylesScope({required this.styles, required super.child});
  final AppTextStyles styles;
  @override
  bool updateShouldNotify(_AppTextStylesScope old) => old.styles != styles;
}
