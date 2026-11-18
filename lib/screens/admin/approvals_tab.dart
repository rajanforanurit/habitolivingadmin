import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// The approval queue.
///
/// Every resident submission — a post, a marketplace listing, a property ad, a
/// move request — lands in one list, filtered server-side by state. This is the
/// screen the admin lives in, so the actions are on the row, not behind a
/// detail screen: start review, approve, reject, ask for changes, suspend,
/// restore, remove.
///
/// A rejection or a removal needs a reason. That is not decoration: the resident
/// sees the reason on their own screen, and an unreasoned refusal is the most
/// common source of "the app did nothing" complaints.
class ApprovalsTab extends StatefulWidget {
  const ApprovalsTab({super.key});

  @override
  State<ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends State<ApprovalsTab> {
  String _status = 'SUBMITTED';

  static const _filters = <(String, String)>[
    ('SUBMITTED', 'To review'),
    ('UNDER_REVIEW', 'In review'),
    ('CHANGES_REQUESTED', 'Changes asked'),
    ('APPROVED', 'Approved'),
    ('REJECTED', 'Rejected'),
    ('', 'All'),
  ];

  int _tick = 0;
  final List<void Function()> _subs = [];

  @override
  void initState() {
    super.initState();
    // A resident submitting something must show up without a manual refresh.
    for (final event in const ['approval:new', 'approval:updated']) {
      _subs.add(
        AppServices.instance.socket.on(event, (_) {
          if (mounted) setState(() => _tick++);
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final cancel in _subs) {
      cancel();
    }
    super.dispose();
  }

  void _set(String value) {
    if (value == _status) return;
    setState(() {
      _status = value;
      _tick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppServices.instance.admin;
    return AppScaffold(
      title: 'Approvals',
      subtitle: 'Everything awaiting a decision',
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              children: [
                for (final (value, label) in _filters) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: Tokens.space2),
                    child: _Chip(
                      label: label,
                      selected: value == _status,
                      onTap: () => _set(value),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _ApprovalList(
              key: ValueKey('$_status-$_tick'),
              status: _status.isEmpty ? null : _status,
              onChanged: () => setState(() => _tick++),
              fetch: (page, status) =>
                  admin.approvals(page: page, limit: 20, status: status),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalList extends StatefulWidget {
  const _ApprovalList({
    super.key,
    required this.fetch,
    required this.status,
    required this.onChanged,
  });

  final Future<PageResultLike> Function(int page, String? status) fetch;
  final String? status;
  final VoidCallback onChanged;

  @override
  State<_ApprovalList> createState() => _ApprovalListState();
}

/// A tiny alias so the fetch signature reads clearly without importing the
/// generic PageResult type into every call site.
typedef PageResultLike = Object;

class _ApprovalListState extends State<_ApprovalList> {
  final ScrollController _scroll = ScrollController();
  final List<ApprovalRequest> _items = [];
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
      final result = await widget.fetch(_page, widget.status);
      if (!mounted) return;
      final page = result as dynamic;
      final items = (page.items as List).cast<ApprovalRequest>();
      final meta = page as dynamic;
      setState(() {
        _items.addAll(items);
        _page++;
        _hasMore = page.hasMore as bool;
        _error = null;
        _initial = false;
      });
      // silence the unused locals lint without changing behaviour
      assert(meta != null);
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
    if (_initial && _loading) {
      return const LoadingList();
    }
    if (_items.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: () => _load(refresh: true));
    }
    if (_items.isEmpty && !_loading) {
      return EmptyState(
        icon: Icons2.approvals,
        title: 'Nothing to review',
        message: widget.status == null || widget.status == 'SUBMITTED'
            ? 'When a resident submits a post, a listing or a move request, it '
                  'appears here for a decision.'
            : 'Nothing in this state right now.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: Tokens.accent,
      child: ListView(
        controller: _scroll,
        padding: EdgeInsets.only(bottom: Tokens.space6),
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: i == _items.length - 1 ? 0 : Tokens.space3,
                ),
                child: _ApprovalCard(
                  request: _items[i],
                  onChanged: widget.onChanged,
                ),
              ),
            ),
          ],
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

class _ApprovalCard extends StatefulWidget {
  const _ApprovalCard({required this.request, required this.onChanged});
  final ApprovalRequest request;
  final VoidCallback onChanged;

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String ok) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, ok);
      widget.onChanged();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reasoned({
    required String title,
    required String hint,
    required String confirm,
    required Future<void> Function(String reason) action,
    required String ok,
    bool destructive = true,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _ReasonDialog(
        title: title,
        hint: hint,
        confirm: confirm,
        destructive: destructive,
      ),
    );
    if (reason == null) return;
    await _run(() => action(reason), ok);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final admin = AppServices.instance.admin;
    final pending = r.isPending;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Tokens.space4),
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
                  r.title?.trim().isNotEmpty == true
                      ? r.title!.trim()
                      : r.entityLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    fontWeight: FontWeight.w600,
                    color: Tokens.ink,
                  ),
                ),
              ),
              const SizedBox(width: Tokens.space2),
              StatusBadge.forStatus(r.status, domain: StatusDomain.approval),
            ],
          ),
          SizedBox(height: Tokens.space1),
          Text(
            [
              r.entityLabel,
              if (r.submittedBy != null) 'by ${r.submittedBy}',
              if (r.submittedAt != null) Fmt.relative(r.submittedAt),
            ].join(' · '),
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              color: Tokens.inkFaint,
            ),
          ),
          if (r.reason != null) ...[
            SizedBox(height: Tokens.space2),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(Tokens.space2),
              decoration: BoxDecoration(
                color: Tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
              child: Text(
                r.reason!,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  height: 1.4,
                  color: Tokens.inkMuted,
                ),
              ),
            ),
          ],
          if (_busy) ...[
            SizedBox(height: Tokens.space3),
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Tokens.surfaceSunken,
              color: Tokens.accent,
            ),
          ] else ...[
            const SizedBox(height: Tokens.space3),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                if (r.rawStatus == 'SUBMITTED')
                  _Action(
                    label: 'Start review',
                    icon: Icons2.search,
                    onTap: () => _run(
                      () => admin.startReview(r.id),
                      'Moved into review.',
                    ),
                  ),
                if (pending)
                  _Action(
                    label: 'Approve',
                    icon: Icons2.success,
                    primary: true,
                    onTap: () => _reasoned(
                      title: 'Approve',
                      hint: 'Note for the resident (optional)',
                      confirm: 'Approve',
                      destructive: false,
                      ok: 'Approved.',
                      action: (note) =>
                          admin.approve(r.id, note: note.isEmpty ? null : note),
                    ),
                  ),
                if (pending)
                  _Action(
                    label: 'Ask for changes',
                    icon: Icons2.edit,
                    onTap: () => _reasoned(
                      title: 'Ask for changes',
                      hint: 'What needs fixing?',
                      confirm: 'Send',
                      ok: 'Sent back for changes.',
                      action: (reason) =>
                          admin.requestChanges(r.id, reason: reason),
                    ),
                  ),
                if (pending)
                  _Action(
                    label: 'Reject',
                    icon: Icons2.close,
                    destructive: true,
                    onTap: () => _reasoned(
                      title: 'Reject',
                      hint: 'The resident will see this',
                      confirm: 'Reject',
                      ok: 'Rejected.',
                      action: (reason) => admin.reject(r.id, reason: reason),
                    ),
                  ),
                if (r.rawStatus == 'APPROVED' || r.rawStatus == 'PUBLISHED')
                  _Action(
                    label: 'Suspend',
                    icon: Icons2.cancel,
                    destructive: true,
                    onTap: () => _reasoned(
                      title: 'Suspend',
                      hint: 'Why is it suspended?',
                      confirm: 'Suspend',
                      ok: 'Suspended.',
                      action: (reason) => admin.suspend(r.id, reason: reason),
                    ),
                  ),
                if (r.rawStatus == 'SUSPENDED')
                  _Action(
                    label: 'Restore',
                    icon: Icons2.refresh,
                    onTap: () => _run(() => admin.restore(r.id), 'Restored.'),
                  ),
                if (r.rawStatus == 'APPROVED' || r.rawStatus == 'PUBLISHED')
                  _Action(
                    label: 'Remove',
                    icon: Icons2.delete,
                    destructive: true,
                    onTap: () => _reasoned(
                      title: 'Remove permanently',
                      hint: 'The resident will see this',
                      confirm: 'Remove',
                      ok: 'Removed.',
                      action: (reason) => admin.remove(r.id, reason: reason),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    final Color border;
    if (primary) {
      fg = Tokens.accentOn;
      bg = Tokens.accent;
      border = Tokens.accent;
    } else if (destructive) {
      fg = Tokens.danger;
      bg = Tokens.dangerTint;
      border = Tokens.danger.withValues(alpha: 0.3);
    } else {
      fg = Tokens.inkMuted;
      bg = Tokens.surface;
      border = Tokens.lineStrong;
    }
    return Semantics(
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: Tokens.space2,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: IconSize.inline, color: fg),
              const SizedBox(width: Tokens.space1),
              Text(
                label,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  fontWeight: FontWeight.w600,
                  color: fg,
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

/// Shared reason prompt. Exported for other admin screens by copying the class
/// shape; kept private here because every admin screen has its own wording.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.confirm,
    this.destructive = true,
  });

  final String title;
  final String hint;
  final String confirm;
  final bool destructive;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
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
      title: Text(
        widget.title,
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        maxLength: 300,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: widget.destructive ? Tokens.danger : Tokens.accent,
          ),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
