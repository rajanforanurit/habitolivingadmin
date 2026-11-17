import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Spacing helpers on the 4px grid.
///
/// Screens use these instead of raw numbers so the rhythm cannot drift: `gap16`
/// is a gap, `pad16` is padding on all sides, `padH20` is horizontal padding.
/// Every value is a multiple of 4 (or exactly half a step for a nudge inside a
/// control).
extension AppSpacing on num {
  // Gaps between items in a Column/Row.
  SizedBox get gap1 => SizedBox(height: Tokens.space1, width: Tokens.space1);
  SizedBox get gap2 => SizedBox(height: Tokens.space2, width: Tokens.space2);
  SizedBox get gap3 => SizedBox(height: Tokens.space3, width: Tokens.space3);
  SizedBox get gap4 => SizedBox(height: Tokens.space4, width: Tokens.space4);
  SizedBox get gap5 => SizedBox(height: Tokens.space5, width: Tokens.space5);
  SizedBox get gap6 => SizedBox(height: Tokens.space6, width: Tokens.space6);
  SizedBox get gap7 => SizedBox(height: Tokens.space7, width: Tokens.space7);
  SizedBox get gap8 => SizedBox(height: Tokens.space8, width: Tokens.space8);
  SizedBox get gap9 => SizedBox(height: Tokens.space9, width: Tokens.space9);
}

/// Padding helpers. `pad4`, `pad8`, … for all sides; `padH` / `padV` for one
/// axis; `padOnly` for a specific set.
extension AppPadding on num {
  EdgeInsets get pad1 => const EdgeInsets.all(Tokens.space1);
  EdgeInsets get pad2 => const EdgeInsets.all(Tokens.space2);
  EdgeInsets get pad3 => const EdgeInsets.all(Tokens.space3);
  EdgeInsets get pad4 => const EdgeInsets.all(Tokens.space4);
  EdgeInsets get pad5 => const EdgeInsets.all(Tokens.space5);
  EdgeInsets get pad6 => const EdgeInsets.all(Tokens.space6);
  EdgeInsets get pad7 => const EdgeInsets.all(Tokens.space7);
  EdgeInsets get pad8 => const EdgeInsets.all(Tokens.space8);
  EdgeInsets get pad9 => const EdgeInsets.all(Tokens.space9);

  EdgeInsets get padH1 => const EdgeInsets.symmetric(horizontal: Tokens.space1);
  EdgeInsets get padH2 => EdgeInsets.symmetric(horizontal: Tokens.space2);
  EdgeInsets get padH3 => EdgeInsets.symmetric(horizontal: Tokens.space3);
  EdgeInsets get padH4 => const EdgeInsets.symmetric(horizontal: Tokens.space4);
  EdgeInsets get padH5 => const EdgeInsets.symmetric(horizontal: Tokens.space5);
  EdgeInsets get padH6 => const EdgeInsets.symmetric(horizontal: Tokens.space6);
  EdgeInsets get padH7 => const EdgeInsets.symmetric(horizontal: Tokens.space7);
  EdgeInsets get padHGutter =>
      const EdgeInsets.symmetric(horizontal: Tokens.gutter);

  EdgeInsets get padV1 => const EdgeInsets.symmetric(vertical: Tokens.space1);
  EdgeInsets get padV2 => const EdgeInsets.symmetric(vertical: Tokens.space2);
  EdgeInsets get padV3 => const EdgeInsets.symmetric(vertical: Tokens.space3);
  EdgeInsets get padV4 => const EdgeInsets.symmetric(vertical: Tokens.space4);
  EdgeInsets get padV5 => const EdgeInsets.symmetric(vertical: Tokens.space5);
  EdgeInsets get padV6 => const EdgeInsets.symmetric(vertical: Tokens.space6);
  EdgeInsets get padV7 => const EdgeInsets.symmetric(vertical: Tokens.space7);
  EdgeInsets get padV8 => const EdgeInsets.symmetric(vertical: Tokens.space8);
}

/// The standard page gutter for a scrolling screen.
///
/// [Tokens.gutter] is the horizontal grid: the header, section labels, cards,
/// form fields, list items and the primary bottom action all start and end on
/// this line, left and right.
const EdgeInsets kScreenPadding = EdgeInsets.symmetric(
  horizontal: Tokens.gutter,
  vertical: Tokens.space4,
);

/// Bottom padding of a scrolling screen, below the last content.
///
/// Big enough that the final helper caption (the "the gate validates the pass
/// code" line on Invite a visitor, the save note on Notification preferences)
/// clears the bottom navigation and the gesture bar.
const double kScreenBottomPadding = 24;

/// The standard gutter for a wider surface (expanded layouts, detail panes).
const EdgeInsets kWideScreenPadding = EdgeInsets.symmetric(
  horizontal: Tokens.gutterWide,
  vertical: Tokens.space5,
);

/// Padding inside a card or sheet body.
const EdgeInsets kCardPadding = EdgeInsets.all(Tokens.space5);

/// Padding for a compact row (list items, table rows).
const EdgeInsets kCompactRowPadding = EdgeInsets.symmetric(
  horizontal: Tokens.space4,
  vertical: Tokens.space3,
);

/// A section of content separated from the next by [Tokens.space7].
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.child,
    this.label,
    this.action,
    this.padding = kScreenPadding,
    this.spacing = Tokens.space2,
  });

  final Widget child;

  /// Optional small sentence-case label above the section.
  final String? label;

  /// Optional trailing action next to the label ("See all").
  final Widget? action;

  final EdgeInsets padding;

  /// Gap between the label and the content.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final content = label == null
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label!, style: context.sectionLabelStyle),
                  ),
                  ?action,
                ],
              ),
              SizedBox(height: spacing),
              child,
            ],
          );

    return Padding(padding: padding, child: content);
  }
}

/// Small helper so a section label can be rendered without a `Section`.
extension SectionLabelStyle on BuildContext {
  TextStyle get sectionLabelStyle => TextStyle(
    fontFamily: Tokens.fontFamily,
    fontSize: Tokens.typeXs,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: Tokens.inkFaint,
  );
}
