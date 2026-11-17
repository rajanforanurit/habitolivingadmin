import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/society.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Notices: announcements to the whole society.
///
/// A notice goes through three states — DRAFT (written, nobody has seen it),
/// PUBLISHED (everyone sees it), and back to DRAFT if retracted. Deleting is
/// the last resort; pausing is the usual move.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  String _status = '';
  int _revision = 0;
  late Future<PageResult<AdminNotice>> _notices = _load();

  static const _filters = <(String, String)>[
    ('', 'All'),
    ('DRAFT', 'Drafts'),
    ('PUBLISHED', 'Published'),
  ];

  Future<PageResult<AdminNotice>> _load() => AppServices.instance.admin.notices(
    limit: 30,
    status: _status.isEmpty ? null : _status,
  );

  void _reload() => setState(() {
    _notices = _load();
    _revision++;
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Notices',
      subtitle: 'Draft, publish, retract',
      floatingAction: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const NoticeEditScreen()),
          );
          if (ok == true) _reload();
        },
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        child: const AppIcon(Icons2.add, size: IconSize.hero),
      ),
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
                      onTap: () {
                        if (value == _status) return;
                        setState(() {
                          _status = value;
                        });
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<PageResult<AdminNotice>>(
              key: ValueKey(_revision),
              future: _notices,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingList();
                }
                if (snapshot.hasError) {
                  return ErrorState(
                    message: '${snapshot.error}',
                    onRetry: _reload,
                  );
                }
                final items = snapshot.data?.items ?? const <AdminNotice>[];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons2.notices,
                    title: 'No notices yet',
                    message:
                        'Announcements land here. Write a draft first — publish '
                        'only when the office is happy with it.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: Tokens.space8),
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Tokens.space4,
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: i == items.length - 1 ? 0 : Tokens.space2,
                          ),
                          child: _Card(notice: items[i], onChanged: _reload),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.notice, required this.onChanged});

  final AdminNotice notice;
  final VoidCallback onChanged;

  bool get _isDraft => notice.status.toUpperCase() == 'DRAFT';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  notice.title,
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
              StatusBadge.forStatus(
                notice.status,
                domain: StatusDomain.generic,
                dot: false,
              ),
            ],
          ),
          SizedBox(height: Tokens.space2),
          Text(
            [
              notice.type,
              if (notice.audience != null) notice.audience!,
              if (notice.publishedAt != null) Fmt.dateTime(notice.publishedAt),
              if (notice.authorName != null) 'by ${notice.authorName}',
            ].join(' · '),
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              color: Tokens.inkMuted,
            ),
          ),
          const SizedBox(height: Tokens.space3),
          Row(
            children: [
              if (_isDraft)
                _Action(
                  label: 'Publish',
                  icon: Icons2.success,
                  onTap: () async {
                    try {
                      await AppServices.instance.admin.publishNotice(notice.id);
                      if (context.mounted) {
                        showMessage(context, 'Published to every resident.');
                      }
                      onChanged();
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '$e', error: true);
                      }
                    }
                  },
                )
              else
                _Action(
                  label: 'Archive',
                  icon: Icons2.cancel,
                  destructive: true,
                  onTap: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Archive this notice?',
                      message:
                          'Residents stop seeing it immediately. The notice stays '
                          'in the archive.',
                      confirmLabel: 'Archive',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    try {
                      await AppServices.instance.admin.archiveNotice(notice.id);
                      if (context.mounted) showMessage(context, 'Archived.');
                      onChanged();
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '$e', error: true);
                      }
                    }
                  },
                ),
              const SizedBox(width: Tokens.space2),
              _Action(
                label: 'Delete',
                icon: Icons2.delete,
                destructive: true,
                onTap: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Delete this notice?',
                    message:
                        'The notice is removed from the archive permanently.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  try {
                    await AppServices.instance.admin.deleteNotice(notice.id);
                    if (context.mounted) showMessage(context, 'Deleted.');
                    onChanged();
                  } catch (e) {
                    if (context.mounted) {
                      showMessage(context, '$e', error: true);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NoticeEditScreen extends StatefulWidget {
  const NoticeEditScreen({super.key});

  @override
  State<NoticeEditScreen> createState() => _NoticeEditScreenState();
}

class _NoticeEditScreenState extends State<NoticeEditScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();

  String _type = 'ANNOUNCEMENT';
  final Set<String> _towerIds = {};
  List<Tower>? _towers;
  bool _publish = false;
  bool _busy = false;
  String? _error;

  static final _types = <(String, String)>[
    ('ANNOUNCEMENT', 'Announcement'),
    ('CIRCULAR', 'Circular'),
    ('EVENT', 'Event'),
    ('MAINTENANCE', 'Maintenance'),
    ('EMERGENCY', 'Emergency'),
  ];

  @override
  void initState() {
    super.initState();
    AppServices.instance.admin
        .towers()
        .then((towers) {
          if (!mounted) return;
          setState(() => _towers = towers);
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _towers = const <Tower>[]);
        });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.admin.createNotice(
        title: _title.text.trim(),
        body: _body.text.trim(),
        type: _type,
        towerIds: _towerIds.isEmpty ? null : _towerIds.toList(),
        publish: _publish,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'New notice',
      subtitle: 'Write it once, everyone sees it',
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.only(bottom: Tokens.space8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().length < 4)
                    ? 'Give the notice a title'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  helperText:
                      'Shown in the notice list and the push notification',
                ),
              ),
            ),
            SizedBox(height: Tokens.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _body,
                minLines: 5,
                maxLines: 10,
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Say a little more — at least 10 characters'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Type',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
            ),
            SizedBox(height: Tokens.space3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final (value, label) in _types)
                    _Choice(
                      label: label,
                      selected: value == _type,
                      onTap: () => setState(() => _type = value),
                    ),
                ],
              ),
            ),
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Who sees it',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        fontWeight: FontWeight.w600,
                        color: Tokens.ink,
                      ),
                    ),
                  ),
                  Text(
                    _towerIds.isEmpty
                        ? 'Everyone'
                        : '${_towerIds.length} tower${_towerIds.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      color: Tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Tokens.space3),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: _towers == null
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: Tokens.space1),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Tokens.surfaceSunken,
                        color: Tokens.accent,
                      ),
                    )
                  : _towers!.isEmpty
                  ? Text(
                      'No towers defined — the notice goes to everyone.',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeXs,
                        color: Tokens.inkMuted,
                      ),
                    )
                  : Wrap(
                      spacing: Tokens.space2,
                      runSpacing: Tokens.space2,
                      children: [
                        for (final tower in _towers!)
                          FilterChip(
                            label: Text(tower.name),
                            selected: _towerIds.contains(tower.id),
                            selectedColor: Tokens.accentTint,
                            checkmarkColor: Tokens.accent,
                            onSelected: (v) => setState(() {
                              if (v) {
                                _towerIds.add(tower.id);
                              } else {
                                _towerIds.remove(tower.id);
                              }
                            }),
                          ),
                      ],
                    ),
            ),

            SizedBox(height: Tokens.space4),
            Panel(
              margin: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publish immediately',
                          style: TextStyle(
                            fontFamily: Tokens.fontFamily,
                            fontSize: Tokens.typeSm,
                            fontWeight: FontWeight.w600,
                            color: Tokens.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _publish
                              ? 'Everyone in the audience gets a push notification'
                              : 'Saved as a draft — nobody is notified yet',
                          style: TextStyle(
                            fontFamily: Tokens.fontFamily,
                            fontSize: Tokens.typeXs,
                            color: Tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSwitch(
                    value: _publish,
                    onChanged: (v) => setState(() => _publish = v),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              SizedBox(height: Tokens.space4),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: Container(
                  padding: EdgeInsets.all(Tokens.space3),
                  decoration: BoxDecoration(
                    color: Tokens.dangerTint,
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      color: Tokens.danger,
                    ),
                  ),
                ),
              ),
            ],

            SizedBox(height: Tokens.space6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.accent,
                  minimumSize: const Size.fromHeight(Tokens.controlHeight),
                ),
                child: _busy
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Tokens.accentOn,
                        ),
                      )
                    : Text(_publish ? 'Publish notice' : 'Save draft'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? Tokens.danger : Tokens.accent;
    return Semantics(
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: Tokens.space2,
          ),
          decoration: BoxDecoration(
            color: destructive ? Tokens.dangerTint : Tokens.accentTint,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
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

class _Choice extends StatelessWidget {
  const _Choice({
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
