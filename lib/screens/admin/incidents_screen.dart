import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Security incidents: what was reported, and what has been done about it.
///
/// An incident moves OPEN → INVESTIGATING → CLOSED. Closing it requires a
/// note — "false alarm", "fixed the light" — because the next shift will ask.
class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  String _status = 'OPEN';

  static const _filters = <(String, String)>[
    ('OPEN', 'Open'),
    ('INVESTIGATING', 'Investigating'),
    ('CLOSED', 'Closed'),
    ('', 'All'),
  ];

  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final admin = AppServices.instance.admin;
    return AppScaffold(
      title: 'Incidents',
      subtitle: 'Reported security issues',
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final (value, label) in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(
                      label: label,
                      selected: value == _status,
                      onTap: () => setState(() {
                        _status = value;
                        _revision++;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _IncidentList(
              key: ValueKey('$_status-$_revision'),
              fetch: (page) => admin.incidents(
                page: page,
                limit: 20,
                status: _status.isEmpty ? null : _status,
              ),
              onChanged: () => setState(() => _revision++),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentList extends StatefulWidget {
  const _IncidentList({
    super.key,
    required this.fetch,
    required this.onChanged,
  });

  final Future<PageResult<Incident>> Function(int page) fetch;
  final VoidCallback onChanged;

  @override
  State<_IncidentList> createState() => _IncidentListState();
}

class _IncidentListState extends State<_IncidentList> {
  final _scroll = ScrollController();
  final List<Incident> _items = [];
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
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _items.clear();
      _initial = true;
      _error = null;
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
      return const EmptyState(
        icon: Icons2.success,
        title: 'Nothing to investigate',
        message: 'No incidents with this status.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: Tokens.accent,
      child: ListView(
        controller: _scroll,
        padding: EdgeInsets.only(bottom: 32),
        children: [
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: i == _items.length - 1 ? 0 : 8,
                ),
                child: _IncidentCard(
                  incident: _items[i],
                  onChanged: widget.onChanged,
                ),
              ),
            ),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
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

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.onChanged});

  final Incident incident;
  final VoidCallback onChanged;

  static final _next = {'OPEN': 'INVESTIGATING', 'INVESTIGATING': 'CLOSED'};

  @override
  Widget build(BuildContext context) {
    final status = incident.status.toUpperCase();
    final next = _next[status];
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  incident.type,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    fontWeight: FontWeight.w600,
                    color: Tokens.ink,
                  ),
                ),
              ),
              StatusBadge.forStatus(
                incident.status,
                domain: StatusDomain.generic,
                dot: false,
              ),
            ],
          ),
          if (incident.description != null) ...[
            SizedBox(height: 6),
            Text(
              incident.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                height: 1.4,
                color: Tokens.inkMuted,
              ),
            ),
          ],
          SizedBox(height: 6),
          Text(
            [
              if (incident.location != null && incident.location!.isNotEmpty)
                incident.location!,
              if (incident.reportedBy != null) 'by ${incident.reportedBy}',
              if (incident.createdAt != null) Fmt.dateTime(incident.createdAt),
            ].join(' · '),
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              color: Tokens.inkFaint,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 8),
            _Action(
              label: next == 'INVESTIGATING'
                  ? 'Start investigation'
                  : 'Close incident',
              icon: next == 'INVESTIGATING' ? Icons2.search : Icons2.success,
              onTap: () => _advance(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _advance(BuildContext context) async {
    final status = incident.status.toUpperCase();
    final next = _next[status];
    if (next == null) return;
    String? note;
    if (next == 'CLOSED') {
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => const _CloseDialog(),
      );
      if (note == null) return;
    }
    try {
      await AppServices.instance.admin.updateIncident(
        incident.id,
        status: next,
        note: note,
      );
      if (context.mounted) {
        showMessage(
          context,
          next == 'CLOSED' ? 'Incident closed.' : 'Under investigation.',
        );
      }
      onChanged();
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
  }
}

class _CloseDialog extends StatefulWidget {
  const _CloseDialog();

  @override
  State<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<_CloseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: const Text('Close this incident?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 2,
        decoration: const InputDecoration(
          hintText: 'What was done? e.g. "Electrician fixed the gate light"',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Tokens.accentTint,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: IconSize.inline, color: Tokens.accent),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  fontWeight: FontWeight.w600,
                  color: Tokens.accent,
                ),
              ),
            ],
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
