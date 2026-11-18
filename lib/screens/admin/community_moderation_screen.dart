import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/ops.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/services/socket_service.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../widgets/file_preview.dart';
import '../widgets/future_body.dart';

Tone approvalTone(String raw) => switch (raw) {
  'SUBMITTED' || 'UNDER_REVIEW' => Tone.warning,
  'APPROVED' || 'PUBLISHED' => Tone.positive,
  'REJECTED' || 'REMOVED' || 'SUSPENDED' => Tone.danger,
  'CHANGES_REQUESTED' => Tone.info,
  _ => Tone.neutral,
};

/// Community post moderation: pending, approved and rejected posts, with the
/// complete post and its author before any decision.
///
/// Posts reach this list the moment a resident submits them (the backend
/// notifies admins and emits `approval:new`). Approve and reject act on the
/// approval request, which is what the backend audits.
class CommunityModerationScreen extends StatefulWidget {
  const CommunityModerationScreen({super.key});

  @override
  State<CommunityModerationScreen> createState() => _CommunityModerationScreenState();
}

class _CommunityModerationScreenState extends State<CommunityModerationScreen> {
  String _tab = 'pending';

  static const _statuses = <String, List<String>>{
    'pending': ['SUBMITTED', 'UNDER_REVIEW'],
    'approved': ['APPROVED', 'PUBLISHED'],
    'rejected': ['REJECTED', 'CHANGES_REQUESTED'],
  };

  Future<List<ApprovalRequest>> _load() async {
    final api = AppServices.instance.admin;
    final pages = await Future.wait(
      _statuses[_tab]!.map((s) => api.approvals(limit: 50, status: s, entityType: 'COMMUNITY_POST')),
    );
    final merged = [for (final p in pages) ...p.items];
    merged.sort((a, b) => (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Community posts',
      subtitle: 'Review before residents see them',
      fillBody: true,
      header: FilterChips(
        options: const [('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')],
        value: _tab,
        onChanged: (v) => setState(() => _tab = v),
      ),
      body: FutureBody<List<ApprovalRequest>>(
        key: ValueKey(_tab),
        load: _load,
        refreshOn: const [Events.approvalNew, Events.approvalUpdated],
        emptyIcon: Icons2.community,
        emptyTitle: switch (_tab) {
          'pending' => 'Nothing to review',
          'approved' => 'No approved posts',
          _ => 'No rejected posts',
        },
        emptyMessage: _tab == 'pending' ? 'Posts residents submit appear here instantly.' : null,
        builder: (context, items, reload) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: Tokens.space8),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: Tokens.space2),
          itemBuilder: (context, i) {
            final r = items[i];
            return Panel(
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostReviewScreen(request: r)));
                await reload();
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title ?? 'Community post',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [if (r.submittedBy != null) r.submittedBy!, Fmt.relative(r.submittedAt)].join(' · '),
                          style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Tokens.space3),
                  StatusBadge(label: r.status, tone: approvalTone(r.rawStatus)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The full post, its author, and the moderation actions.
class PostReviewScreen extends StatefulWidget {
  const PostReviewScreen({super.key, required this.request});

  final ApprovalRequest request;

  @override
  State<PostReviewScreen> createState() => _PostReviewScreenState();
}

class _PostReviewScreenState extends State<PostReviewScreen> {
  bool _busy = false;
  final int _revision = 0;

  Future<void> _decide(
    Future<void> Function() action,
    String done,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, done);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showMessage(context, friendlyError(e), error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final admin = AppServices.instance.admin;
    return AppScaffold(
      title: 'Review post',
      fillBody: true,
      body: FutureBody<ModerationPost>(
        key: ValueKey(_revision),
        load: () => AppServices.instance.ops.post(r.entityId),
        builder: (context, post, reload) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: Tokens.space8),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(post.title, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeLg, fontWeight: FontWeight.w600, color: Tokens.ink)),
                ),
                StatusBadge(label: r.status, tone: approvalTone(r.rawStatus)),
              ],
            ),
            const SizedBox(height: Tokens.space4),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.body, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeMd - 2, color: Tokens.ink, height: 1.5)),
                  for (final id in post.imageIds) ...[
                    const SizedBox(height: Tokens.space3),
                    FilePreview(fileId: id, height: 220),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Tokens.space5),
            const SectionLabel('Author'),
            const SizedBox(height: Tokens.space2),
            Panel(
              child: Column(
                children: [
                  DetailRow(label: 'Name', value: post.authorName ?? 'Resident'),
                  if (post.flatLabel != null) DetailRow(label: 'Flat', value: post.flatLabel!),
                  if (post.authorMobile != null) DetailRow(label: 'Mobile', value: Fmt.phone(post.authorMobile), icon: Icons2.phone),
                  DetailRow(label: 'Submitted', value: Fmt.dateTime(r.submittedAt ?? post.createdAt)),
                  if (r.decidedBy != null) DetailRow(label: 'Decided by', value: '${r.decidedBy}${r.decidedAt == null ? '' : ' · ${Fmt.dateTime(r.decidedAt)}'}'),
                  if ((r.reason ?? post.rejectionReason ?? '').isNotEmpty) DetailRow(label: 'Reason', value: (r.reason ?? post.rejectionReason)!),
                ],
              ),
            ),
            if (r.isPending) ...[
              const SizedBox(height: Tokens.space6),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Approve this post?',
                          message: 'Residents will be able to see it in the community feed.',
                          confirmLabel: 'Approve',
                          destructive: false,
                        );
                        if (!ok) return;
                        await _decide(() => admin.approve(r.id), 'Post approved.');
                      },
                style: FilledButton.styleFrom(backgroundColor: Tokens.positive, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                icon: const AppIcon(Icons2.success, size: IconSize.inline),
                label: const Text('Approve'),
              ),
              const SizedBox(height: Tokens.space3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final reason = await promptText(
                                context,
                                title: 'Ask for changes',
                                hint: 'What should the resident fix?',
                                confirmLabel: 'Send back',
                                required: true,
                              );
                              if (reason == null) return;
                              await _decide(() => admin.requestChanges(r.id, reason: reason), 'Sent back to the resident.');
                            },
                      child: const Text('Ask for changes'),
                    ),
                  ),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Tokens.danger),
                      onPressed: _busy
                          ? null
                          : () async {
                              final reason = await promptText(
                                context,
                                title: 'Reject this post',
                                hint: 'Reason (the resident will see it)',
                                confirmLabel: 'Reject',
                                required: true,
                                destructive: true,
                              );
                              if (reason == null) return;
                              await _decide(() => admin.reject(r.id, reason: reason), 'Post rejected.');
                            },
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
