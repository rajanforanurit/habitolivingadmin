import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';

/// A list backed by a paged endpoint.
///
/// Every list screen in the app does the same four things: fetch page 1, show
/// skeletons, show a real empty state, and fetch the next page when the user
/// reaches the end. That logic is identical everywhere, so it lives here rather
/// than being copied into twenty screens and drifting.
///
/// The fetch is keyed by [fetch], and the widget re-fetches whenever that
/// function's identity changes — which is how the caller wires a filter or a
/// refresh.
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyIcon,
    this.separator = true,
    this.header,
    this.padding = EdgeInsets.zero,
    this.autoLoadMore = true,
  });

  /// Fetches one page. Page 1 is fetched on mount and on refresh.
  final Future<PageResult<T>> Function(int page) fetch;

  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final bool separator;

  /// Shown above the list, inside the scroll view, before the rows.
  final Widget? header;

  final EdgeInsets padding;

  /// Load the next page when the user nears the end. Off for short lists.
  final bool autoLoadMore;

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  final List<T> _items = [];
  final _scroll = ScrollController();

  int _page = 1;
  bool _hasMore = false;
  bool _loading = false;
  bool _firstLoad = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.autoLoadMore) {
      _scroll.addListener(_maybeLoadMore);
    }
  }

  @override
  void didUpdateWidget(PagedList<T> old) {
    super.didUpdateWidget(old);
    if (!identical(old.fetch, widget.fetch)) {
      _reload();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 320) {
      loadMore();
    }
  }

  Future<void> _reload() async {
    await _fetch(page: 1, reset: true);
  }

  /// Public so a screen's pull-to-refresh can call it without rebuilding.
  Future<void> refresh() => _reload();

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    await _fetch(page: _page);
  }

  Future<void> _fetch({required int page, bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.fetch(page);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _page = result.page + 1;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _firstLoad = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_firstLoad && _loading) return LoadingList();
    if (_error != null && _items.isEmpty) {
      return ErrorState(message: '$_error', onRetry: _reload);
    }
    if (_items.isEmpty && !_loading) {
      return EmptyState(
        title: widget.emptyTitle,
        message: widget.emptyMessage,
        icon: widget.emptyIcon,
      );
    }

    final rows = <Widget>[
      if (widget.header != null) widget.header!,
      for (var i = 0; i < _items.length; i++)
        widget.separator
            ? Column(
                key: ValueKey(_items[i]),
                children: [
                  if (i > 0) const Hairline(indent: Tokens.space4),
                  widget.itemBuilder(context, _items[i], i),
                ],
              )
            : widget.itemBuilder(context, _items[i], i),
    ];

    final content = widget.separator
        ? Container(
            decoration: BoxDecoration(
              color: Tokens.surface,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              border: Border.all(color: Tokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          );

    return RefreshIndicator(
      onRefresh: _reload,
      color: Tokens.accent,
      // shrinkWrap: when PagedList is embedded in a scrollable page (an
      // AppScaffold non-ScrollView body wraps in a scroll view), the inner
      // ListView must size to its content instead of requiring unbounded
      // height — otherwise the list collapses to zero and the screen is blank.
      child: ListView(
        controller: _scroll,
        padding: widget.padding,
        physics: AlwaysScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          content,
          if (_loading && _items.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: Tokens.space4),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Tokens.accent,
                  ),
                ),
              ),
            ),
          if (_error != null && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.space3),
              child: Center(
                child: Text(
                  'Could not load more',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    color: Tokens.inkFaint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Convenience wrapper: [PagedList] inside an [AppScaffold] with a title.
class PagedListScreen<T> extends StatefulWidget {
  const PagedListScreen({
    super.key,
    required this.title,
    required this.fetch,
    required this.itemBuilder,
    this.subtitle,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon,
    this.actions = const [],
    this.floatingAction,
    this.showBack = true,
    this.separator = true,
    this.refreshKey,
  });

  final String title;
  final String? subtitle;
  final Future<PageResult<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String? emptyTitle;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final List<Widget> actions;
  final Widget? floatingAction;
  final bool showBack;

  /// Draw a hairline between rows inside one bordered container (the default),
  /// or lay the rows out as separate items with no divider — for lists whose
  /// items are already cards.
  final bool separator;

  /// Changes whenever a list mutation happened, so the list re-fetches.
  /// Callers that add/edit/delete rows pass this; without it a mutation leaves
  /// a stale row on screen until the user pulls to refresh.
  final Object? refreshKey;

  @override
  State<PagedListScreen<T>> createState() => _PagedListScreenState<T>();
}

class _PagedListScreenState<T> extends State<PagedListScreen<T>> {
  /// Keyed on [PagedListScreen.refreshKey]: when the caller changes it the list
  /// is rebuilt, which re-fetches page 1. Without this, a create/edit/delete
  /// leaves a stale row on screen until the user pulls to refresh.
  Key get _key => ValueKey<Object?>(widget.refreshKey);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.background,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                // Same rule as [AppScaffold]: the back circle starts on the
                // page gutter, not at the raw edge.
                Tokens.gutter,
                Tokens.space4 + MediaQuery.of(context).padding.top,
                Tokens.gutter,
                Tokens.space6,
              ),
              child: _Header(
                title: widget.title,
                subtitle: widget.subtitle,
                showBack: widget.showBack,
                actions: widget.actions,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              left: Tokens.gutter,
              right: Tokens.gutter,
              bottom:
                  (widget.floatingAction != null
                      ? Tokens.space9
                      : Tokens.space6) +
                  MediaQuery.of(context).padding.bottom,
            ),
            sliver: SliverToBoxAdapter(
              child: PagedList<T>(
                key: _key,
                fetch: widget.fetch,
                itemBuilder: widget.itemBuilder,
                emptyTitle: widget.emptyTitle ?? 'Nothing here yet',
                emptyMessage: widget.emptyMessage,
                emptyIcon: widget.emptyIcon,
                separator: widget.separator,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingAction,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.showBack,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();
    return Row(
      children: [
        if (canPop) ...[
          _Back(onPressed: () => Navigator.of(context).maybePop()),
          const SizedBox(width: Tokens.space4),
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
        ...actions,
      ],
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.surfaceAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Center(child: AppIcon(Icons2.back, size: IconSize.row)),
        ),
      ),
    );
  }
}
