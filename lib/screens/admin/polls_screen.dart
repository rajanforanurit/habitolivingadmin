import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Polls: the society's way of asking everyone at once.
///
/// A poll goes DRAFT (composing) → ACTIVE (residents vote) → CLOSED. Results
/// are aggregate-only when the poll is anonymous. Creating one here wires it
/// to the standard question shape; multi-question elections stay in the board
/// room, not the app.
class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  String _status = 'ACTIVE';

  static const _filters = <(String, String)>[
    ('DRAFT', 'Drafts'),
    ('ACTIVE', 'Active'),
    ('CLOSED', 'Closed'),
    ('', 'All'),
  ];

  int _revision = 0;
  late Future<List<Map<String, dynamic>>> _polls = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final admin = AppServices.instance.admin;
    final rows = await admin.polls(limit: 30);
    if (_status.isEmpty) return rows;
    return rows
        .where((p) => asString(p['status']).toUpperCase() == _status)
        .toList(growable: false);
  }

  void _reload() => setState(() {
    _polls = _load();
    _revision++;
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Polls',
      subtitle: 'Ask everyone at once',
      floatingAction: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const PollCreateScreen()),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final (value, label) in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(
                      label: label,
                      selected: value == _status,
                      onTap: () {
                        if (value == _status) return;
                        setState(() => _status = value);
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey('$_status-$_revision'),
              future: _polls,
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
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons2.poll,
                    title: 'No polls here',
                    message: 'Create one — residents vote, results come back.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: i == items.length - 1 ? 0 : 8,
                          ),
                          child: _PollCard(row: items[i], onChanged: _reload),
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

class _PollCard extends StatelessWidget {
  const _PollCard({required this.row, required this.onChanged});

  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final id = asString(row['id']);
    final title = asStringOrNull(row['title']) ?? 'Poll';
    final status = asString(row['status'], fallback: 'DRAFT');
    final questions = asMapList(row['questions']);
    final createdAt = asDateOrNull(row['createdAt']);

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
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: Tokens.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.forStatus(
                status,
                domain: StatusDomain.generic,
                dot: false,
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            [
              '${questions.length} question${questions.length == 1 ? '' : 's'}',
              if (createdAt != null) Fmt.dateTime(createdAt),
            ].join(' · '),
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              color: Tokens.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (status.toUpperCase() == 'DRAFT')
                _Action(
                  label: 'Open poll',
                  icon: Icons2.success,
                  onTap: () => _call(
                    context,
                    () => AppServices.instance.admin.activatePoll(id),
                    'Poll opened. Residents can vote now.',
                  ),
                )
              else if (status.toUpperCase() == 'ACTIVE')
                _Action(
                  label: 'Close poll',
                  icon: Icons2.cancel,
                  destructive: true,
                  onTap: () => _call(
                    context,
                    () => AppServices.instance.admin.closePoll(id),
                    'Poll closed.',
                  ),
                ),
              const SizedBox(width: 8),
              _Action(
                label: 'Delete',
                icon: Icons2.delete,
                destructive: true,
                onTap: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Delete this poll?',
                    message: 'Votes are discarded. This cannot be undone.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  await _call(
                    context,
                    () => AppServices.instance.admin.deletePoll(id),
                    'Poll deleted.',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _call(
    BuildContext context,
    Future<void> Function() fn,
    String okMessage,
  ) async {
    try {
      await fn();
      if (context.mounted) showMessage(context, okMessage);
      onChanged();
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: destructive ? Tokens.dangerTint : Tokens.accentTint,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: IconSize.inline, color: fg),
              const SizedBox(width: 4),
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

/// Compose a single-question poll. Multi-question surveys and elections are
/// authored by the society board, not from a phone.
class PollCreateScreen extends StatefulWidget {
  const PollCreateScreen({super.key});

  @override
  State<PollCreateScreen> createState() => _PollCreateScreenState();
}

class _PollCreateScreenState extends State<PollCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _question = TextEditingController();
  final _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  bool _anonymous = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _question.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 8) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_options.length <= 2) return;
    setState(() {
      _options[i].dispose();
      _options.removeAt(i);
    });
  }

  Future<void> _create() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final question = _question.text.trim();
    final options = _options
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (options.length < 2) {
      setState(() => _error = 'Two options minimum.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.admin.createPoll({
        'title': _title.text.trim(),
        'kind': 'POLL',
        'anonymous': _anonymous,
        'questions': [
          {
            'text': question,
            'type': 'SINGLE_CHOICE',
            'required': true,
            'options': [
              for (final o in options) {'label': o},
            ],
          },
        ],
      });
      if (!mounted) return;
      showMessage(context, 'Poll drafted. Open it when you are ready.');
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
      title: 'New poll',
      subtitle: 'One question, single choice',
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.only(bottom: 48),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextFormField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Title it' : null,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Should we repaint the gate this year?',
                ),
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextFormField(
                controller: _question,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Ask the question'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  hintText: 'How do you feel about repainting?',
                ),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'OPTIONS',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Tokens.inkFaint,
                ),
              ),
            ),
            SizedBox(height: 8),
            for (var i = 0; i < _options.length; i++)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _options[i],
                        decoration: InputDecoration(
                          labelText: 'Option ${i + 1}',
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: _options.length <= 2
                          ? null
                          : () => _removeOption(i),
                      icon: AppIcon(
                        Icons2.close,
                        size: IconSize.row,
                        color: Tokens.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addOption,
                  icon: const AppIcon(Icons2.add, size: IconSize.inline),
                  label: const Text('Add option'),
                  style: TextButton.styleFrom(foregroundColor: Tokens.accent),
                ),
              ),
            ),
            SizedBox(height: 16),
            Panel(
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Anonymous',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        fontWeight: FontWeight.w600,
                        color: Tokens.ink,
                      ),
                    ),
                  ),
                  AppSwitch(
                    value: _anonymous,
                    onChanged: (v) => setState(() => _anonymous = v),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: EdgeInsets.all(12),
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
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton(
                onPressed: _busy ? null : _create,
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
                    : const Text('Create draft poll'),
              ),
            ),
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
