import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'future_body.dart';

/// Shows an uploaded file by id. Images are rendered; anything else (a PDF
/// floor plan, say) shows a document tile, since a PDF renderer is not part of
/// the app.
class FilePreview extends StatefulWidget {
  const FilePreview({super.key, required this.fileId, this.height = 180});

  final String fileId;
  final double height;

  @override
  State<FilePreview> createState() => _FilePreviewState();
}

class _FilePreviewState extends State<FilePreview> {
  late Future<Uint8List> _bytes = _load();

  Future<Uint8List> _load() async =>
      Uint8List.fromList(await AppServices.instance.files.fetch(widget.fileId));

  static bool _isImage(Uint8List b) {
    if (b.length < 12) return false;
    final png = b[0] == 0x89 && b[1] == 0x50;
    final jpg = b[0] == 0xFF && b[1] == 0xD8;
    final webp = b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57 && b[9] == 0x45;
    return png || jpg || webp;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        Widget child;
        if (snap.connectionState != ConnectionState.done) {
          child = const Center(child: CircularProgressIndicator(strokeWidth: 2));
        } else if (snap.hasError) {
          child = _Tile(
            icon: Icons2.error,
            label: friendlyError(snap.error!),
            onTap: () => setState(() => _bytes = _load()),
          );
        } else if (_isImage(snap.data!)) {
          child = InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: EdgeInsets.zero,
                child: InteractiveViewer(child: Image.memory(snap.data!)),
              ),
            ),
            child: Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity),
          );
        } else {
          child = const _Tile(icon: Icons2.documents, label: 'Document attached (PDF)');
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          child: Container(
            height: widget.height,
            width: double.infinity,
            color: Tokens.surfaceSunken,
            child: child,
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: IconSize.hero, color: Tokens.inkMuted),
          const SizedBox(height: Tokens.space2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeSm,
              color: Tokens.inkMuted,
            ),
          ),
        ],
      ),
    ),
  );
}
