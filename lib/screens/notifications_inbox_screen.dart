import 'dart:async';

import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import '../services/notification_router.dart';
import 'package:habitoliving_shared/services/socket_service.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import '../app.dart';

/// The notification inbox: the durable record of everything the app pushed.
///
/// Push messages are a delivery channel, not storage — a notification the user
/// misses is still here. Tapping a row marks it read and routes through
/// [PushRouter] when the payload carries a deep link, so the inbox and a tapped
/// push behave identically.
class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  final _api = AppServices.instance.notifications;
  PageResult<AppNotification>? _page;
  bool _loading = true;
  bool _loadingMore = false;
  bool _unreadOnly = false;
  Object? _error;
  Timer? _liveReload;
  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _load();
    _unsubscribe = AppServices.instance.socket.on(Events.notification, (_) {
      // Debounce: a burst of pushes (visitor + delivery + chat) should not
      // spawn five list fetches.
      _liveReload?.cancel();
      _liveReload = Timer(const Duration(milliseconds: 400), _load);
    });
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _liveReload?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.list(unreadOnly: _unreadOnly);
      if (mounted) setState(() => _page = page);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final next = _page?.nextPage;
    if (next == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _api.list(page: next, unreadOnly: _unreadOnly);
      if (mounted) {
        setState(() {
          _page = PageResult(
            items: [...?_page?.items, ...more.items],
            page: more.page,
            total: more.total,
            totalPages: more.totalPages,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(AppNotification note) async {
    if (note.readAt == null) {
      try {
        await _api.markRead(note.id);
      } catch (_) {
        // A failed mark-read must not block opening the item.
      }
      if (mounted) {
        setState(() {
          _page = PageResult(
            items: [
              for (final n in _page?.items ?? const <AppNotification>[])
                n.id == note.id ? _readCopy(n) : n,
            ],
            page: _page?.page ?? 1,
            total: _page?.total ?? 0,
            totalPages: _page?.totalPages ?? 0,
          );
        });
      }
    }
    if (!mounted) return;
    await NotificationRouter.open(context, note.data);
  }

  AppNotification _readCopy(AppNotification n) => AppNotification(
    id: n.id,
    type: n.type,
    title: n.title,
    body: n.body,
    readAt: DateTime.now(),
    createdAt: n.createdAt,
    data: n.data,
    societyId: n.societyId,
  );

  Future<void> _markAllRead() async {
    try {
      final count = await _api.markAllRead();
      await _load();
      if (mounted) showMessage(context, '$count marked read');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Notifications',
      showBack: true,
      actions: [
        if ((_page?.items ?? const []).any((n) => n.readAt == null))
          HeaderAction(
            icon: Icons2.save,
            tooltip: 'Mark all read',
            onPressed: _markAllRead,
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              // Tighter than the page gutter: the rows are a dense list, and the
              // full 20px on top of the row's own inner padding pushed the text
              // further in than the header above it.
              Tokens.space4,
              Tokens.space2,
              Tokens.space4,
              Tokens.space2,
            ),
            child: Row(
              children: [
                _Filter(
                  label: 'All',
                  selected: !_unreadOnly,
                  onTap: () {
                    setState(() => _unreadOnly = false);
                    _load();
                  },
                ),
                const SizedBox(width: Tokens.space2),
                _Filter(
                  label: 'Unread',
                  selected: _unreadOnly,
                  onTap: () {
                    setState(() => _unreadOnly = true);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingPage();
    if (_error != null) {
      return ErrorState(message: '$_error', onRetry: _load);
    }
    final items = _page?.items ?? const [];
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons2.notifications,
        title: _unreadOnly ? 'Nothing unread' : 'No notifications',
        message: _unreadOnly
            ? 'You are all caught up.'
            : 'Gate approvals, payments and society updates arrive here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.only(
          left: Tokens.space4,
          right: Tokens.space4,
          bottom: kScreenBottomPadding,
        ),
        children: [
          for (final note in items) ...[
            _NotificationRow(note: note, onTap: () => _open(note)),
            // Aligned with where the row's text starts: page gutter + row
            // padding + icon + gap, so the divider reads as an underline of
            // the text column rather than a line across the circle.
            const Hairline(indent: 52),
          ],
          if (_page?.hasMore == true)
            TextButton(
              onPressed: _loadMore,
              child: Text(_loadingMore ? 'Loading…' : 'Load more'),
            ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space4,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? Tokens.accent : Tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(Tokens.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: Tokens.fontFamily,
            fontSize: Tokens.typeSm,
            fontWeight: FontWeight.w500,
            color: selected ? Tokens.accentOn : Tokens.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.note, required this.onTap});
  final AppNotification note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = note.readAt == null;
    return ListRow(
      title: note.title,
      subtitle: note.body.isEmpty ? null : note.body,
      leading: AppIcon(
        _iconFor(note.type),
        size: IconSize.row,
        color: unread ? Tokens.accent : Tokens.inkFaint,
      ),
      onTap: onTap,
      showChevron: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unread)
            Container(
              width: 6,
              height: 6,
              margin: EdgeInsets.only(right: Tokens.space2),
              decoration: BoxDecoration(
                color: Tokens.accent,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            Fmt.relative(note.createdAt),
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              color: Tokens.inkFaint,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('visitor') || t.contains('gate')) return Icons2.gate;
    if (t.contains('payment') || t.contains('invoice')) return Icons2.payments;
    if (t.contains('complaint') || t.contains('ticket')) {
      return Icons2.complaints;
    }
    if (t.contains('incident') || t.contains('emergency')) {
      return Icons2.emergency;
    }
    if (t.contains('delivery')) return Icons2.deliveries;
    return Icons2.notifications;
  }
}
