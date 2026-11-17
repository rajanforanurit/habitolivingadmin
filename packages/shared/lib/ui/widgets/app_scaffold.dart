import 'package:flutter/material.dart';

import '../../state/async_view.dart';
import '../icons.dart';
import '../spacing.dart';
import '../tokens.dart';
import 'primitives.dart';
import 'states.dart';

/// The standard screen frame.
///
/// Every screen in the app is an [AppScaffold]: a header with a title and
/// optional actions, a scrollable body, an optional floating primary action, and
/// a pull-to-refresh that works on the whole page.
///
/// Two deliberate choices:
/// - The header is part of the scroll view, so the title scrolls away and the
///   body gets the space. Nested scrolling headers are the default in the
///   Material template and they waste a thumb-reach of vertical space.
/// - There is no bottom app bar by default. Actions live in the body or the
///   floating button, so a screen has one obvious thing to do.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.floatingAction,
    this.onRefresh,
    this.padding = kScreenPadding,
    this.showBack = true,
    this.fillBody = false,
    this.header,
    this.bottom,
  });

  final String title;
  final Widget body;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? floatingAction;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;

  /// Whether to show a back button when there is a route to go back to.
  final bool showBack;

  /// Lay the body out with a bounded height (it fills the space below the
  /// header) instead of scrolling it. Required for a body that contains an
  /// `Expanded`/`Spacer`, a ListView, a TabBarView or a PageView: those cannot
  /// be laid out inside a scroll view. Set automatically when the body contains
  /// one of them; set it by hand for a body that builds such a widget inside a
  /// closure the analyzer cannot see into (a `FutureBuilder`, say).
  final bool fillBody;

  /// Optional widget above the title (a segmented control, a search field).
  final Widget? header;

  /// Optional widget pinned below the scroll view (a sticky action bar).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();
    final media = MediaQuery.of(context);
    // Per-side values: EdgeInsets.horizontal/vertical are the SUMS of both
    // sides, which is what double-padded every header before this.
    final headerPadding = EdgeInsets.fromLTRB(
      padding.left,
      padding.top + media.padding.top,
      padding.right,
      Tokens.space6,
    );
    final headerBlock = Padding(
      padding: headerPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canPop) ...[
                _IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: Tokens.space4),
              ] else if (leading != null) ...[
                leading!,
                const SizedBox(width: Tokens.space3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.type2Xl,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: Tokens.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: Tokens.space1),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: Tokens.fontFamily,
                          fontSize: Tokens.typeSm,
                          height: 1.4,
                          color: Tokens.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: Tokens.space3),
                ...actions,
              ],
            ],
          ),
          if (header != null) ...[
            const SizedBox(height: Tokens.space4),
            header!,
          ],
        ],
      ),
    );

    // The body gets one of two layouts:
    //
    //  * Fill the remaining height (`fillBody` or a body that contains a flex
    //    or scrollable widget). A Column with `Expanded`, a ListView or a
    //    TabBarView cannot be laid out with an unbounded height — that throws
    //    and, in a release build, paints an empty box: the "blank screen" bug.
    //  * Scroll (`SingleChildScrollView` + `ConstrainedBox(minHeight: …)`) for
    //    ordinary content, which is how a form or detail page should behave.
    final Widget safeBody = _BodyLayout(
      fill: fillBody || _needsBoundedHeight(body),
      padding: EdgeInsets.fromLTRB(
        padding.left,
        0,
        padding.right,
        (floatingAction != null ? Tokens.space9 : kScreenBottomPadding) +
            media.padding.bottom,
      ),
      child: body,
    );

    final content = onRefresh == null
        ? safeBody
        : RefreshIndicator(
            onRefresh: onRefresh!,
            color: Tokens.accent,
            child: safeBody,
          );

    return Scaffold(
      backgroundColor: Tokens.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          headerBlock,
          Expanded(child: content),
        ],
      ),
      floatingActionButton: floatingAction,
      bottomNavigationBar: bottom,
    );
  }
}

/// A list page: header plus a scrolling list, with the standard states.
class AppListScaffold<T> extends StatelessWidget {
  const AppListScaffold({
    super.key,
    required this.title,
    required this.view,
    required this.itemBuilder,
    this.subtitle,
    this.actions = const [],
    this.floatingAction,
    this.onRefresh,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyAction,
    this.onEmptyAction,
    this.onLoadMore,
    this.padding = kScreenPadding,
    this.separator = true,
    this.header,
  });

  final String title;
  final String? subtitle;
  final AsyncView<List<T>> view;
  final Widget Function(BuildContext, T) itemBuilder;
  final List<Widget> actions;
  final Widget? floatingAction;
  final Future<void> Function()? onRefresh;
  final String emptyTitle;
  final String? emptyMessage;
  final String? emptyAction;
  final VoidCallback? onEmptyAction;
  final Future<void> Function()? onLoadMore;
  final EdgeInsets padding;
  final bool separator;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: view,
      builder: (context, _) {
        return AppScaffold(
          title: title,
          subtitle: subtitle,
          actions: actions,
          header: header,
          floatingAction: floatingAction,
          padding: padding,
          onRefresh: onRefresh,
          body: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    if (view.isLoading) return const LoadingList();
    if (view.hasError) {
      return ErrorState(message: view.error ?? '', onRetry: view.refresh);
    }
    final items = view.data;
    if (items.isEmpty) {
      return EmptyState(
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: emptyAction,
        onAction: onEmptyAction,
      );
    }

    if (!separator) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final item in items) itemBuilder(context, item)],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Hairline(indent: Tokens.space4),
            itemBuilder(context, items[i]),
          ],
        ],
      ),
    );
  }
}

/// A small round icon button with a tooltip, used in headers.
class _IconButton extends StatelessWidget {
  const _IconButton({
    this.icon = Icons2.back,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // 36×36 is the header circle everywhere in the app: big enough to hit,
    // small enough that the title still dominates the row.
    final button = Material(
      color: Tokens.surfaceAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: AppIcon(icon, size: IconSize.row)),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// A header action: a round icon button for the top-right of a screen.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Tokens.space2),
      child: _IconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: onPressed ?? () {},
      ),
    );
  }
}

/// A search field that reports changes after the user pauses typing.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
    this.controller,
    this.autofocus = false,
  });

  final ValueChanged<String> onChanged;
  final String? hint;
  final TextEditingController? controller;
  final bool autofocus;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Tokens.controlHeight,
      padding: EdgeInsets.symmetric(horizontal: Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
      ),
      child: Row(
        children: [
          AppIcon(Icons2.search, size: IconSize.row),
          SizedBox(width: Tokens.space2),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeBase,
                color: Tokens.ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.hint ?? 'Search',
                hintStyle: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeBase,
                  color: Tokens.inkFaint,
                ),
              ),
            ),
          ),
          if (_hasText)
            GestureDetector(
              onTap: () {
                _controller.clear();
                widget.onChanged('');
              },
              child: const AppIcon(Icons2.close, size: IconSize.inline),
            ),
        ],
      ),
    );
  }
}

/// Chooses between "fill the remaining height" and "scroll" for a screen body.
///
/// The distinction matters: a scroll view lays its child out with an unbounded
/// height, and a `Column` with `Expanded` (or any ListView/TabBarView) throws
/// when it is given one. In a release build that exception paints an empty box,
/// which is exactly what a blank screen with a working header looks like.
class _BodyLayout extends StatelessWidget {
  const _BodyLayout({
    required this.fill,
    required this.padding,
    required this.child,
  });

  final bool fill;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (child is ScrollView) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (fill) {
          // Same horizontal gutter as the scroll path, so a screen does not
          // change its margins depending on which path it took. Vertical space
          // belongs to the body: it owns its own bottom padding.
          return Padding(
            padding: EdgeInsets.only(left: padding.left, right: padding.right),
            child: SizedBox(height: constraints.maxHeight, child: child),
          );
        }
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}

/// Whether [widget] has to be laid out with a bounded height.
///
/// The question is only ever about the body's *own* layout: does it need a real
/// height to divide (a flex child) or to fill (a viewport)? A flex or scrollable
/// widget buried inside a list row does not count — that row is bounded by its
/// own parent, and treating it as the body's problem is what pushed the invoice
/// detail into the bounded path and overflowed it at the bottom.
///
/// So: unwrap the transparent wrappers (padding, container, form, refresh
/// indicator, …) and look at the first real widget. Anything deeper is
/// irrelevant.
bool _needsBoundedHeight(Widget widget) {
  Widget current = widget;

  for (var depth = 0; depth < 24; depth++) {
    // A viewport needs a bounded main axis, or it never lays out at all.
    if (current is ScrollView ||
        current is Scrollable ||
        current is PageView ||
        current is TabBarView ||
        current is IndexedStack ||
        current is ListBody) {
      return true;
    }

    // Builders create their child in a closure, so the shape is unknown: a
    // snapshot body is a list, empty or error state, and all of those want a
    // real height.
    if (current is FutureBuilder ||
        current is StreamBuilder ||
        current is AnimatedBuilder ||
        current is ValueListenableBuilder) {
      return true;
    }

    if (current is Flex) {
      final children = current.children;
      // Flex children of this flex, or a viewport among its children: those are
      // the cases where the body itself needs a height to divide. An Expanded
      // inside one of those children (a list row's value column, say) is that
      // child's business, not the body's.
      final hasFlex = children.any(
        (child) =>
            child is Expanded ||
            child is Spacer ||
            (child is Flexible && child.flex > 0),
      );
      return hasFlex || children.any(_isViewport);
    }

    final next = _transparentChild(current);
    if (next == null) return false;
    current = next;
  }
  return false;
}

/// The single child of a wrapper that does not change how the body is laid out.
Widget? _transparentChild(Widget widget) {
  if (widget is SingleChildRenderObjectWidget) {
    return widget.child;
  }
  if (widget is ProxyWidget) return widget.child;
  if (widget is Form) return widget.child;
  if (widget is RefreshIndicator) return widget.child;
  if (widget is Scrollbar) return widget.child;
  if (widget is Hero) return widget.child;
  if (widget is Container) return widget.child;
  return null;
}

/// Whether [widget] is (or wraps) a viewport.
///
/// Only wrappers are unwrapped: a viewport nested two cards deep is that card's
/// problem, and treating it as the body's is what overflowed the invoice detail.
bool _isViewport(Widget widget) {
  Widget current = widget;
  for (var depth = 0; depth < 12; depth++) {
    if (current is ScrollView ||
        current is Scrollable ||
        current is PageView ||
        current is TabBarView ||
        current is IndexedStack ||
        current is ListBody ||
        current is CustomScrollView) {
      return true;
    }
    final next = _transparentChild(current);
    if (next == null) return false;
    current = next;
  }
  return false;
}
