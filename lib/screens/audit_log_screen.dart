import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';

/// The immutable audit trail: who did what, to what, and when.
///
/// Every privileged action on the platform writes a row here — approvals,
/// block events, impersonations, config changes. It is the one screen with no
/// edit affordances at all, on purpose.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({
    super.key,
    required this.fetch,
    this.title = 'Audit log',
    this.subtitle = 'Everything with a paper trail',
  });

  /// Fetches the newest entries. Kept as a closure so the caller picks the
  /// scope (society admin → own society, super admin → platform).
  final Future<List<AuditLog>> Function() fetch;

  final String title;
  final String subtitle;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late Future<List<AuditLog>> _logs = widget.fetch();

  void _reload() => setState(() {
    _logs = widget.fetch();
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      onRefresh: () async => _reload(),
      body: FutureBuilder<List<AuditLog>>(
        future: _logs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }
          final items = snapshot.data ?? const <AuditLog>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons2.audit,
              title: 'Nothing logged yet',
              message: 'Actions appear here the moment they happen.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                const Hairline(indent: 16 + IconSize.row + 12),
            itemBuilder: (context, i) {
              final log = items[i];
              return ListRow(
                title: log.action,
                subtitle: [
                  if (log.actorName != null) 'by ${log.actorName!}',
                  if (log.target != null) log.target!,
                  if (log.createdAt != null) Fmt.dateTime(log.createdAt),
                ].join(' · '),
                icon: Icons2.audit,
                dense: true,
                showChevron: false,
                trailing: null,
              );
            },
          );
        },
      ),
    );
  }
}
