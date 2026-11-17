import 'package:flutter/material.dart';

import '../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/services/media_service.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import 'widgets/paged_list.dart';

/// Documents: personal files plus the society's published set.
///
/// Personal documents are the resident's own records (lease, ID, society NOC);
/// society documents are what the committee publishes (by-laws, minutes,
/// invoices). They are separated because they have different owners and
/// different rules, and mixing them makes both harder to find.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _scope = 'ALL';
  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Documents',
      subtitle: 'Your files, and what the society publishes',
      floatingAction: _scope == 'SOCIETY'
          ? null
          : FloatingActionButton(
              onPressed: _upload,
              backgroundColor: Tokens.accent,
              foregroundColor: Tokens.accentOn,
              tooltip: 'Upload a document',
              child: const AppIcon(Icons2.upload, size: IconSize.hero),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space3),
            child: Row(
              children: [
                for (final s in const [
                  ('ALL', 'All'),
                  ('PERSONAL', 'Mine'),
                  ('SOCIETY', 'Society'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: Tokens.space2),
                    child: _Chip(
                      label: s.$2,
                      selected: _scope == s.$1,
                      onTap: () => setState(() => _scope = s.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PagedList<DocumentRecord>(
              key: ValueKey('$_scope-$_revision'),
              fetch: (page) async {
                final all = await AppServices.instance.resident.documents(
                  page: page,
                  limit: 30,
                );
                if (_scope == 'ALL') return all;
                return PageResult(
                  items: all.items
                      .where((d) => d.scope.toUpperCase() == _scope)
                      .toList(growable: false),
                  page: all.page,
                  limit: all.limit,
                  total: all.total,
                  totalPages: all.totalPages,
                );
              },
              emptyTitle: 'No documents',
              emptyMessage: _scope == 'SOCIETY'
                  ? 'The committee has not published anything yet.'
                  : 'Upload a lease, an ID or a society NOC and it appears here.',
              emptyIcon: Icons2.documents,
              itemBuilder: (context, d, _) => ListRow(
                title: d.title,
                subtitle: [
                  d.category,
                  if (d.fileName != null) d.fileName!,
                  if (d.sizeBytes != null) Fmt.fileSize(d.sizeBytes!),
                  if (d.uploadedAt != null) Fmt.relative(d.uploadedAt),
                ].join(' · '),
                icon: d.isSocietyDoc ? Icons2.community : Icons2.file,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MetaTag(d.scope),
                    if (d.scope.toUpperCase() != 'SOCIETY')
                      IconButton(
                        tooltip: 'Delete document',
                        icon: AppIcon(
                          Icons2.delete,
                          size: IconSize.row,
                          color: Tokens.inkFaint,
                        ),
                        onPressed: () => _delete(d),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _upload() async {
    final doc = await AppServices.instance.media.document();
    if (doc == null || !mounted) return;
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _TitleDialog(fileName: doc.name),
    );
    if (title == null || title.trim().isEmpty) return;
    try {
      if (!mounted) return;
      showMessage(context, 'Uploading…');
      final fileId = await AppServices.instance.media.upload(
        doc,
        purpose: UploadPurpose.document,
      );
      await AppServices.instance.resident.addDocument(
        title: title.trim(),
        category: 'PERSONAL',
        fileId: fileId,
      );
      if (!mounted) return;
      showMessage(context, 'Document uploaded.');
      setState(() => _revision++);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _delete(DocumentRecord d) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this document?',
      message:
          '“${d.title}” will be removed from your files. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await AppServices.instance.resident.deleteDocument(d.id);
      if (!mounted) return;
      showMessage(context, 'Document deleted.');
      setState(() => _revision++);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }
}

class _TitleDialog extends StatefulWidget {
  const _TitleDialog({required this.fileName});

  final String fileName;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final _controller = TextEditingController(
    text: widget.fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: const Text('What is this file?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Title',
          helperText: 'e.g. Lease agreement 2025',
        ),
        onSubmitted: (_) => Navigator.of(context).pop(_controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: const Text('Upload'),
        ),
      ],
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
    return Material(
      color: selected ? Tokens.accentTint : Tokens.surface,
      borderRadius: BorderRadius.circular(Tokens.radiusFull),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: Tokens.space2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
            border: Border.all(color: selected ? Tokens.accent : Tokens.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeSm,
              fontWeight: FontWeight.w500,
              color: selected ? Tokens.accent : Tokens.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
