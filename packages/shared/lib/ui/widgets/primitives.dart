// Layout primitives (Row, Column, Padding, InkWell, Text) come from Flutter's
// widget layer. shadcn is aliased because it re-exports several of the same
// names with different semantics.
// Flutter's widget + material layers supply layout primitives and InkWell.
// `widgets.dart` is imported first so that where shadcn re-exports a name
// (Card, Button, Scaffold, Row) the Flutter one is shadowed by the shadcn one
// only if it is also exported; to keep that unambiguous we hide the shadcn
// layout re-exports that collide and let Flutter own structure.
import 'package:flutter/material.dart';

import '../icons.dart';
import '../spacing.dart';
import '../tokens.dart';

/// A sentence-case section label.
///
/// Small, faint and quiet. This replaces the all-caps tracked eyebrow that
/// reads as generated scaffolding; a label says what the group is and nothing
/// more.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: Tokens.inkFaint,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A label/value pair for detail screens and settings rows.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.valueStyle,
    this.icon,
    this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final TextStyle? valueStyle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: kCompactRowPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: IconSize.row),
            const SizedBox(width: Tokens.space3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeXs,
                    height: 1.3,
                    color: Tokens.inkFaint,
                  ),
                ),
                SizedBox(height: Tokens.space1),
                Text(
                  value,
                  style:
                      valueStyle ??
                      TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeBase,
                        height: 1.4,
                        color: Tokens.ink,
                      ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// A one-line list row: leading icon, title, optional subtitle, trailing.
///
/// Every list in the app uses this so row heights and text alignment stay
/// identical everywhere.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = false,
    this.titleStyle,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;
  final TextStyle? titleStyle;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final height = dense ? Tokens.compactRowHeight : Tokens.rowHeight;

    // A minimum, not a fixed height: a subtitle that wraps to a second line
    // grows the row instead of being cut off with an ellipsis. Long labels
    // ("Notification preferences" / "Visitors, dues, deliveries and more")
    // would otherwise truncate on a 360dp screen.
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: Tokens.space3),
          ] else if (icon != null) ...[
            AppIcon(icon!, size: IconSize.row),
            const SizedBox(width: Tokens.space3),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      titleStyle ??
                      TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeBase,
                        height: 1.3,
                        color: Tokens.ink,
                      ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      height: 1.3,
                      color: Tokens.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Tokens.space3),
            trailing!,
          ],
          if (showChevron && onTap != null) ...[
            const SizedBox(width: Tokens.space2),
            const AppIcon(Icons2.forward, size: IconSize.inline),
          ],
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
        child: content,
      ),
    );
  }
}

/// One metric on a dashboard: a figure and a label, nothing else.
///
/// Used sparingly: one per card, never a grid of them.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.tone,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? hint;

  /// Colour of the figure. Null means ink.
  final Color? tone;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: Padding(
        padding: EdgeInsets.all(compact ? Tokens.space3 : Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                height: 1.3,
                color: Tokens.inkFaint,
              ),
            ),
            SizedBox(height: Tokens.space2),
            Text(
              value,
              style: TextStyle(
                fontFamily: Tokens.fontFamilyFigure,
                fontSize: compact ? Tokens.typeLg : Tokens.typeXl,
                height: 1.1,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: tone ?? Tokens.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (hint != null) ...[
              SizedBox(height: Tokens.space1),
              Text(
                hint!,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  height: 1.3,
                  color: Tokens.inkFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A tinted panel used to group related content without a card.
///
/// A flat fill and no border: nested cards are the tell of a generated layout,
/// and a tinted panel reads as grouping instead.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = kCardPadding,
    this.color,
    this.radius = Tokens.radiusMd,
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  /// Only pass this when the panel is used inside a list that has no padding of
  /// its own. Every screen already gutters its body.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (onTap == null) return panel;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: panel,
    );
  }
}

/// Hairline divider. Uses the theme border colour at full strength so it reads
/// as a line, not a shadow.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.thickness = 1});

  final double indent;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: indent),
      height: thickness,
      color: Tokens.line,
    );
  }
}

/// An avatar that falls back to initials, so the app never depends on a photo
/// being present.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.tone,
    this.imageProvider,
  });

  final String name;
  final double size;

  /// Tint of the fallback circle. Defaults to the accent tint.
  final Color? tone;

  /// Optional photo. When null, initials are shown.
  final ImageProvider? imageProvider;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    if (imageProvider != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: Image(
          image: imageProvider!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone ?? Tokens.accentTint,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: tone == null ? Tokens.accent : Tokens.accentOn,
        ),
      ),
    );
  }
}

/// A small amount of vertical breathing room used between blocks.
class VGap extends StatelessWidget {
  const VGap(this.height, {super.key});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// A compact switch.
///
/// Material's [Switch] draws a 52×32 track with a 48px tap target, which reads
/// as oversized next to a 15px row label. This one is 36×22 with a 16px thumb —
/// the size the design calls for — while keeping a 44×32 hit area so it is
/// still comfortable to tap.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;

  /// Null disables the switch (it still reflects [value]).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final active = value && enabled;

    return Semantics(
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: 44,
          height: 32,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: Tokens.motionFast),
              curve: Curves.easeOut,
              width: 36,
              height: 22,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: active ? Tokens.accent : Tokens.surfaceSunken,
                borderRadius: BorderRadius.circular(Tokens.radiusFull),
                border: Border.all(
                  color: active
                      ? Tokens.accent
                      : (enabled ? Tokens.lineStrong : Tokens.line),
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: Tokens.motionFast),
                curve: Curves.easeOut,
                alignment: active
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: active
                        ? Tokens.accentOn
                        : (enabled ? Tokens.inkFaint : Tokens.lineStrong),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shared form-field look: a soft rounded card input.
///
/// Every text field in the app uses this so a field on one screen reads the
/// same as the same field on another — 14px radius, hairline border, 12px inner
/// padding, and the accent outline when focused. A bare underlined [TextField]
/// reads as unfinished next to it, which is why the complaint and invite forms
/// were rebuilt onto this.
InputDecoration appFieldDecoration({
  String? label,
  String? hint,
  bool multiline = false,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  alignLabelWithHint: multiline,
  filled: true,
  fillColor: Tokens.surface,
  contentPadding: EdgeInsets.symmetric(
    horizontal: Tokens.space4,
    vertical: Tokens.space4,
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(Tokens.radiusMd),
    borderSide: BorderSide(color: Tokens.line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(Tokens.radiusMd),
    borderSide: BorderSide(color: Tokens.line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(Tokens.radiusMd),
    borderSide: BorderSide(color: Tokens.accent, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(Tokens.radiusMd),
    borderSide: BorderSide(color: Tokens.danger),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(Tokens.radiusMd),
    borderSide: BorderSide(color: Tokens.danger, width: 1.5),
  ),
);
