import 'package:flutter/material.dart';

import '../app.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// One complaint: what was reported, who has it, and the thread.
///
/// The composer sits under the thread rather than behind a button. A complaint
/// that needs another detail should take one tap to answer, and a resident who
/// has just read "we've assigned this to Ramesh" wants to reply right there.
class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key, required this.complaint});

  final Complaint complaint;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final _input = TextEditingController();
  late Future<List<ComplaintComment>> _thread;
  bool _sending = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _thread = AppServices.instance.resident.complaintComments(
      widget.complaint.id,
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final f = AppServices.instance.resident.complaintComments(
      widget.complaint.id,
    );
    setState(() => _thread = f);
    try {
      await f;
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await AppServices.instance.resident.commentOnComplaint(
        widget.complaint.id,
        body,
      );
      _input.clear();
      await _reload();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _rate() async {
    var rating = 5;
    final feedback = TextEditingController();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.all(Tokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rate the resolution',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeLg,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
              const SizedBox(height: Tokens.space3),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setSheet(() => rating = i),
                      icon: AppIcon(
                        Icons2.star,
                        size: IconSize.hero,
                        color: i <= rating ? Tokens.accent : Tokens.lineStrong,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Tokens.space2),
              TextField(
                controller: feedback,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Anything to add (optional)',
                ),
              ),
              const SizedBox(height: Tokens.space4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(rating),
                  child: const Text('Send rating'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    try {
      await AppServices.instance.resident.rateComplaint(
        widget.complaint.id,
        rating: picked,
        feedback: feedback.text.trim().isEmpty ? null : feedback.text.trim(),
      );
      if (!mounted) return;
      showMessage(context, 'Thanks — rating recorded');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _reopen() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Tokens.surface,
        title: const Text('Reopen this complaint'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'What is still wrong?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await AppServices.instance.resident.reopenComplaint(
        widget.complaint.id,
        reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
      );
      if (!mounted) return;
      showMessage(context, 'Complaint reopened');
      Navigator.of(context).maybePop(true);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    return AppScaffold(
      title: c.subject,
      subtitle: c.ticketNumber,
      showBack: true,
      actions: [
        if (c.canReopen)
          HeaderAction(
            icon: Icons2.refresh,
            tooltip: 'Reopen',
            onPressed: _busy ? null : _reopen,
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusBadge.forStatus(c.status.name),
              const SizedBox(width: Tokens.space2),
              MetaTag(c.priority),
              MetaTag(c.category),
            ],
          ),
          SizedBox(height: Tokens.space3),
          if (c.description != null) ...[
            Text(
              c.description!,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeBase,
                height: 1.55,
                color: Tokens.inkMuted,
              ),
            ),
            const SizedBox(height: Tokens.space4),
          ],
          DetailRow(
            label: 'Raised',
            value: c.createdAt == null ? '—' : Fmt.dateTime(c.createdAt),
          ),
          if (c.assignedTo != null)
            DetailRow(label: 'Assigned to', value: c.assignedTo!),
          if (c.resolutionNote != null) ...[
            SizedBox(height: Tokens.space3),
            Container(
              padding: EdgeInsets.all(Tokens.space3),
              decoration: BoxDecoration(
                color: Tokens.accentTint,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel('Resolution'),
                  SizedBox(height: Tokens.space1),
                  Text(
                    c.resolutionNote!,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      height: 1.5,
                      color: Tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: Tokens.space5),
          SectionLabel('Conversation'),
          SizedBox(height: Tokens.space2),
          FutureBuilder<List<ComplaintComment>>(
            future: _thread,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
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
                );
              }
              if (snapshot.hasError) {
                return ErrorState(
                  compact: true,
                  message: '${snapshot.error}',
                  onRetry: _reload,
                );
              }
              final thread = snapshot.data ?? [];
              if (thread.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: Tokens.space3),
                  child: Text(
                    'No replies yet. The office sees this as soon as you write.',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      color: Tokens.inkFaint,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in thread) ...[
                    Padding(
                      padding: EdgeInsets.only(bottom: Tokens.space3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InitialsAvatar(name: m.authorName),
                          SizedBox(width: Tokens.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        m.authorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: Tokens.fontFamily,
                                          fontSize: Tokens.typeSm,
                                          fontWeight: FontWeight.w600,
                                          color: Tokens.ink,
                                        ),
                                      ),
                                    ),
                                    if (m.isStaff) ...[
                                      const SizedBox(width: Tokens.space2),
                                      const MetaTag('Office'),
                                    ],
                                    Spacer(),
                                    Text(
                                      m.createdAt == null
                                          ? ''
                                          : Fmt.relative(m.createdAt),
                                      style: TextStyle(
                                        fontFamily: Tokens.fontFamily,
                                        fontSize: Tokens.typeXs,
                                        color: Tokens.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Text(
                                  m.body,
                                  style: TextStyle(
                                    fontFamily: Tokens.fontFamily,
                                    fontSize: Tokens.typeBase,
                                    height: 1.45,
                                    color: Tokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          SizedBox(height: Tokens.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Add a detail'),
                ),
              ),
              SizedBox(width: Tokens.space2),
              SizedBox(
                width: 44,
                height: 44,
                child: FilledButton(
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.accent,
                    foregroundColor: Tokens.accentOn,
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: AppIcon(
                    Icons2.forward,
                    size: IconSize.row,
                    color: Tokens.accentOn,
                  ),
                ),
              ),
            ],
          ),
          if (c.isClosed) ...[
            const SizedBox(height: Tokens.space3),
            OutlinedButton.icon(
              onPressed: _busy ? null : _reopen,
              icon: const AppIcon(Icons2.refresh, size: IconSize.row),
              label: const Text('Reopen'),
            ),
          ] else if (c.status == ComplaintStatusValue.resolved &&
              c.rating == null) ...[
            const SizedBox(height: Tokens.space3),
            TextButton.icon(
              onPressed: _rate,
              icon: const AppIcon(Icons2.star, size: IconSize.row),
              label: const Text('Rate the resolution'),
            ),
          ],
          const SizedBox(height: Tokens.space6),
        ],
      ),
    );
  }
}
