import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../complaint_detail_screen.dart';

/// Complaints and support tickets: what residents have reported and what has
/// happened to it.
///
/// Two things live here because they are the same job — someone complained and
/// somebody has to answer. Complaints come from residents through the app;
/// support tickets come from anyone who hit a wall and asked for help. Both are
/// status-filtered, both open into a thread.
class ComplaintsTab extends StatefulWidget {
  const ComplaintsTab({super.key});

  @override
  State<ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<ComplaintsTab>
    with TickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reports',
      subtitle: 'Complaints and support',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: _Tabs(controller: _controller),
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: const [_ComplaintsList(), _TicketsList()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Tokens.surfaceSunken,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final selected = controller.index == i;
                  return Semantics(
                    button: true,
                    selected: selected,
                    child: InkResponse(
                      onTap: () => controller.animateTo(i),
                      radius: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: Tokens.space2,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? Tokens.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(Tokens.radiusXs),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: Tokens.ink.withValues(alpha: 0.06),
                                    blurRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          i == 0 ? 'Complaints' : 'Support',
                          style: TextStyle(
                            fontFamily: Tokens.fontFamily,
                            fontSize: Tokens.typeXs,
                            fontWeight: FontWeight.w600,
                            color: selected ? Tokens.ink : Tokens.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ComplaintsList extends StatefulWidget {
  const _ComplaintsList();

  @override
  State<_ComplaintsList> createState() => _ComplaintsListState();
}

class _ComplaintsListState extends State<_ComplaintsList> {
  String _status = 'OPEN';

  static const _filters = <(String, String)>[
    ('OPEN', 'Open'),
    ('ASSIGNED', 'Assigned'),
    ('IN_PROGRESS', 'In progress'),
    ('ESCALATED', 'Escalated'),
    ('RESOLVED', 'Resolved'),
    ('CLOSED', 'Closed'),
    ('', 'All'),
  ];

  @override
  Widget build(BuildContext context) {
    final admin = AppServices.instance.admin;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            children: [
              for (final (value, label) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: Tokens.space2),
                  child: _Chip(
                    label: label,
                    selected: value == _status,
                    onTap: () => setState(() => _status = value),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _List<Complaint>(
            key: ValueKey('complaints-$_status'),
            fetch: (page) => admin.complaints(
              page: page,
              limit: 20,
              status: _status.isEmpty ? null : _status,
            ),
            emptyTitle: 'No complaints',
            emptyMessage: 'When a resident raises a complaint it appears here.',
            itemBuilder: (Complaint c) => _ComplaintRow(
              complaint: c,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ComplaintDetailScreen(complaint: c),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketsList extends StatefulWidget {
  const _TicketsList();

  @override
  State<_TicketsList> createState() => _TicketsListState();
}

class _TicketsListState extends State<_TicketsList> {
  String _status = 'OPEN';

  static const _filters = <(String, String)>[
    ('OPEN', 'Open'),
    ('PENDING', 'Waiting'),
    ('RESOLVED', 'Resolved'),
    ('', 'All'),
  ];

  @override
  Widget build(BuildContext context) {
    final admin = AppServices.instance.admin;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            children: [
              for (final (value, label) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: Tokens.space2),
                  child: _Chip(
                    label: label,
                    selected: value == _status,
                    onTap: () => setState(() => _status = value),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _List<SupportTicket>(
            key: ValueKey('tickets-$_status'),
            fetch: (page) => admin.supportTickets(
              page: page,
              limit: 20,
              status: _status.isEmpty ? null : _status,
            ),
            emptyTitle: 'No support tickets',
            emptyMessage:
                'Anyone who hit a wall and asked for help lands here.',
            itemBuilder: (SupportTicket t) => _TicketRow(ticket: t),
          ),
        ),
      ],
    );
  }
}

class _List<T> extends StatefulWidget {
  const _List({
    super.key,
    required this.fetch,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.itemBuilder,
    this.emptyIcon,
  });

  final Future<dynamic> Function(int page) fetch;
  final String emptyTitle;
  final String emptyMessage;
  final IconData? emptyIcon;
  final Widget Function(T item) itemBuilder;

  @override
  State<_List<T>> createState() => _ListState<T>();
}

/// Fetches a paged list of any model. Typed as `dynamic` in [fetch] and cast
/// once, because the two lists in this tab return different model types and the
/// paging logic is otherwise identical.
class _ListState<T> extends State<_List<T>> {
  final _scroll = ScrollController();
  final List<T> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _initial = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 320) {
      return;
    }
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _items.clear();
      _error = null;
      _initial = true;
      setState(() {});
    }
    if (!_hasMore) return;

    setState(() => _loading = true);
    try {
      final result = await widget.fetch(_page);
      if (!mounted) return;
      final items = (result as dynamic).items as List<T>;
      final hasMore = (result as dynamic).hasMore as bool;
      setState(() {
        _items.addAll(items);
        _page++;
        _hasMore = hasMore;
        _error = null;
        _initial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _initial = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initial && _loading) return LoadingList();
    if (_items.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: () => _load(refresh: true));
    }
    if (_items.isEmpty && !_loading) {
      return EmptyState(
        icon: widget.emptyIcon ?? Icons2.complaints,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: Tokens.accent,
      child: ListView(
        controller: _scroll,
        padding: EdgeInsets.only(bottom: Tokens.space6),
        children: [
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: i == _items.length - 1 ? 0 : Tokens.space2,
                ),
                child: widget.itemBuilder(_items[i]),
              ),
            ),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: Tokens.space4),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Tokens.surfaceSunken,
                color: Tokens.accent,
              ),
            ),
        ],
      ),
    );
  }
}

class _ComplaintRow extends StatelessWidget {
  const _ComplaintRow({required this.complaint, required this.onTap});
  final Complaint complaint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: complaint.subject,
      subtitle: [
        complaint.ticketNumber,
        complaint.category,
        complaint.priority == 'Medium' ? null : complaint.priority,
        if (complaint.assignedTo != null) '${complaint.assignedTo}',
        if (complaint.createdAt != null) Fmt.relative(complaint.createdAt),
      ].whereType<String>().join(' · '),
      leading: const AppIcon(Icons2.complaints, size: IconSize.row),
      trailing: StatusBadge.forStatus(
        complaint.status.name,
        domain: StatusDomain.complaint,
        dot: false,
      ),
      onTap: onTap,
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: ticket.subject,
      subtitle: [
        ticket.category,
        if (ticket.raisedBy != null) ticket.raisedBy!,
        if (ticket.createdAt != null) Fmt.relative(ticket.createdAt),
      ].join(' · '),
      leading: const AppIcon(Icons2.support, size: IconSize.row),
      trailing: StatusBadge.forStatus(
        ticket.status,
        domain: StatusDomain.generic,
        dot: false,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: selected ? Tokens.accent : Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
            border: Border.all(
              color: selected ? Tokens.accent : Tokens.lineStrong,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              fontWeight: FontWeight.w600,
              color: selected ? Tokens.accentOn : Tokens.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
