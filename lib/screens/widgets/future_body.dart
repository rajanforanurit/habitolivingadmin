import 'dart:async';

import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/api_client.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';

String friendlyError(Object e) {
  if (e is ApiException) return e.message;
  final text = '$e';
  if (text.contains('SocketException') || text.contains('ClientException')) {
    return 'Cannot reach the server. Check your connection and try again.';
  }
  return text.replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
}

/// Loads one value and renders the standard four states: skeleton, content,
/// empty and error with retry. Pull-to-refresh and [refreshOn] realtime events
/// reload in place (the old content stays visible while the new loads).
///
/// The [builder] must return a scrollable (a `ListView`), so give the parent
/// `AppScaffold` `fillBody: true`.
class FutureBody<T> extends StatefulWidget {
  const FutureBody({
    super.key,
    required this.load,
    required this.builder,
    this.refreshOn = const [],
    this.isEmpty,
    this.emptyIcon = Icons2.empty,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  /// Socket events that trigger a silent reload.
  final List<String> refreshOn;
  final bool Function(T data)? isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;

  @override
  State<FutureBody<T>> createState() => _FutureBodyState<T>();
}

class _FutureBodyState<T> extends State<FutureBody<T>> {
  T? _data;
  bool _has = false;
  String? _error;
  bool _loading = true;
  final List<void Function()> _subs = [];

  @override
  void initState() {
    super.initState();
    for (final event in widget.refreshOn) {
      _subs.add(AppServices.instance.socket.on(event, (_) => _reload(silent: true)));
    }
    _reload();
  }

  @override
  void dispose() {
    for (final cancel in _subs) {
      cancel();
    }
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!mounted) return;
    if (!silent || !_has) setState(() => _loading = !_has);
    try {
      final value = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = value;
        _has = true;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_has) return const LoadingList();
    if (!_has && _error != null) {
      return ErrorState(message: _error!, onRetry: _reload);
    }
    final data = _data as T;
    final empty = widget.isEmpty?.call(data) ??
        (data is List && data.isEmpty) ||
            (data is PageResult && data.items.isEmpty);
    if (empty) {
      return RefreshIndicator(
        onRefresh: _reload,
        color: Tokens.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 420,
              child: EmptyState(
                icon: widget.emptyIcon,
                title: widget.emptyTitle,
                message: widget.emptyMessage,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      color: Tokens.accent,
      child: widget.builder(context, data, _reload),
    );
  }
}

/// A paged list with load-more on scroll. Re-create it with a new `key` to
/// restart from page 1 (for a filter change).
class PagedBody<T> extends StatefulWidget {
  const PagedBody({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.refreshOn = const [],
    this.emptyIcon = Icons2.empty,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.padding = const EdgeInsets.only(bottom: Tokens.space8),
    this.gap = Tokens.space2,
  });

  final Future<PageResult<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item, VoidCallback reload) itemBuilder;
  final List<String> refreshOn;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final EdgeInsets padding;
  final double gap;

  @override
  State<PagedBody<T>> createState() => _PagedBodyState<T>();
}

class _PagedBodyState<T> extends State<PagedBody<T>> {
  final _scroll = ScrollController();
  final List<T> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _initial = true;
  String? _error;
  final List<void Function()> _subs = [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 320) {
        _load();
      }
    });
    for (final event in widget.refreshOn) {
      _subs.add(AppServices.instance.socket.on(event, (_) => refresh()));
    }
    _load();
  }

  @override
  void dispose() {
    for (final cancel in _subs) {
      cancel();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _page = 1;
    _hasMore = true;
    await _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final result = await widget.fetch(_page);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _page++;
        _error = null;
        _initial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _initial = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initial) return const LoadingList();
    if (_items.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: () {
        _hasMore = true;
        _page = 1;
        _initial = true;
        setState(() {});
        _load(reset: true);
      });
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        color: Tokens.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 420,
              child: EmptyState(
                icon: widget.emptyIcon,
                title: widget.emptyTitle,
                message: widget.emptyMessage,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: refresh,
      color: Tokens.accent,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _items.length + (_loading || _error != null ? 1 : 0),
        separatorBuilder: (_, _) => SizedBox(height: widget.gap),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return Padding(
              padding: const EdgeInsets.all(Tokens.space5),
              child: _error != null
                  ? TextButton(onPressed: _load, child: Text('$_error  ·  Retry'))
                  : const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            );
          }
          return widget.itemBuilder(context, _items[i], refresh);
        },
      ),
    );
  }
}

/// A horizontally scrolling row of filter chips.
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (v, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: Tokens.space2),
              child: ChoiceChip(
                label: Text(label),
                selected: v == value,
                selectedColor: Tokens.accentTint,
                onSelected: (_) => onChanged(v),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom-sheet-free text prompt used for reasons and notes.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  bool required = false,
  bool destructive = false,
  int minLength = 3,
}) {
  final controller = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: Tokens.surface,
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: hint, errorText: error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: destructive ? Tokens.danger : Tokens.accent,
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.length < minLength) {
                setState(() => error = 'Enter at least $minLength characters.');
                return;
              }
              Navigator.of(ctx).pop(text);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
}

