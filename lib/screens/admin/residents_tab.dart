import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/json.dart';

import 'package:habitoliving_shared/models/society.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import 'resident_detail_screen.dart';

/// Residents: who lives here, who is waiting to be let in, who has been moved.
///
/// Three states of the same thing — `PENDING` (they registered and nobody has
/// approved them yet), `ACTIVE` (they live here), `INACTIVE` (they left, or were
/// suspended). The status filter is server-side so a society of 400 flats does
/// not send 400 records to show the 12 pending ones.
class ResidentsTab extends StatefulWidget {
  const ResidentsTab({super.key});

  @override
  State<ResidentsTab> createState() => _ResidentsTabState();
}

class _ResidentsTabState extends State<ResidentsTab> {
  String _status = 'PENDING';

  static const _filters = <(String, String)>[
    ('PENDING', 'To approve'),
    ('APPROVED', 'Approved'),
    ('INACTIVE', 'Inactive'),
    ('', 'Everyone'),
  ];

  int _revision = 0;

  void _set(String value) {
    if (value == _status) return;
    setState(() => _status = value);
  }

  Future<void> _open(Resident r) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ResidentDetailScreen(resident: r)),
    );
    if (!mounted) return;
    if (changed == true) {
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppServices.instance.admin;
    return AppScaffold(
      title: 'Residents',
      subtitle: 'Who lives here',
      body: Column(
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
                      onTap: () => _set(value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _ResidentList(
              key: ValueKey('$_status-$_revision'),
              fetch: (page) => admin.residents(
                page: page,
                limit: 20,
                status: _status.isEmpty ? null : _status,
              ),
              emptyTitle: _status == 'PENDING'
                  ? 'Nobody is waiting'
                  : 'No residents here',
              emptyMessage: _status == 'PENDING'
                  ? 'When someone registers against the society, they appear here '
                        'for approval before they can use the app.'
                  : 'Nobody matches this filter yet.',
              onOpen: _open,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResidentList extends StatefulWidget {
  const _ResidentList({
    super.key,
    required this.fetch,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onOpen,
  });

  final Future<PageResult<Resident>> Function(int page) fetch;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function(Resident) onOpen;

  @override
  State<_ResidentList> createState() => _ResidentListState();
}

class _ResidentListState extends State<_ResidentList> {
  final _scroll = ScrollController();
  final List<Resident> _items = [];
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
      final page = await widget.fetch(_page);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page++;
        _hasMore = page.hasMore;
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
        icon: Icons2.residents,
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
                child: _Card(
                  resident: _items[i],
                  onTap: () => widget.onOpen(_items[i]),
                ),
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

class _Card extends StatelessWidget {
  const _Card({required this.resident, required this.onTap});
  final Resident resident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 14,
      child: Container(
        padding: EdgeInsets.all(Tokens.space3),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: Tokens.line),
        ),
        child: Row(
          children: [
            InitialsAvatar(name: resident.name),
            SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resident.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      fontWeight: FontWeight.w600,
                      color: Tokens.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    [
                      resident.flat?.label ?? 'No flat',
                      resident.residentType,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      color: Tokens.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: Tokens.space2),
            StatusBadge.forStatus(
              resident.status,
              domain: StatusDomain.generic,
            ),
            SizedBox(width: Tokens.space2),
            AppIcon(Icons2.forward, size: IconSize.row, color: Tokens.inkFaint),
          ],
        ),
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
