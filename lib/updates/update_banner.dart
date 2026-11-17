// In-app updater — the "Update available" banner shown above the app.
//
// Self-contained: the only touch outside lib/updates/ is a single line in
// lib/app.dart mounting this widget. Delete this file and that line to
// remove the banner.

import 'package:flutter/material.dart';

import 'package:habitoliving_shared/ui/tokens.dart';
import 'update_install.dart';
import 'update_service.dart';

/// A slim banner that appears above the app body when a newer version is
/// available. Tapping "Update" opens a dialog *on top of the current screen*
/// (not a new route) so the user does not lose their place. "Later" hides the
/// banner until the next check (6h) or restart.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    UpdateService.instance.addListener(_onService);
  }

  @override
  void dispose() {
    UpdateService.instance.removeListener(_onService);
    super.dispose();
  }

  void _onService() {
    if (mounted) setState(() {});
  }

  void _showUpdateDialog() {
    final info = UpdateService.instance.info;
    if (info == null) return;
    debugPrint('UpdateBanner: opening dialog for ${info.version}');
    // Use the root navigator so the dialog appears above the current screen
    // regardless of which tab/route is active, without replacing it.
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: navigator.context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Tokens.surface,
        title: Text(
          'Update available',
          style: TextStyle(
            fontFamily: Tokens.fontFamily,
            fontSize: Tokens.typeLg,
            fontWeight: FontWeight.w600,
            color: Tokens.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${info.version} is available. You are on '
              '${UpdateService.instance.installedVersion ?? 'an older version'}.',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                height: 1.5,
                color: Tokens.inkMuted,
              ),
            ),
            if (info.releaseNotes.trim().isNotEmpty) ...[
              const SizedBox(height: Tokens.space3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes.trim(),
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      height: 1.45,
                      color: Tokens.inkMuted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Later',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                color: Tokens.inkMuted,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _runDownload();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Tokens.accent,
              foregroundColor: Tokens.accentOn,
            ),
            child: Text(
              'Download & install',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                fontWeight: FontWeight.w600,
                color: Tokens.accentOn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runDownload() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await UpdateService.instance.download();
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            UpdateService.instance.error ?? 'Update failed. Try again later.',
            style: const TextStyle(fontFamily: Tokens.fontFamily),
          ),
        ),
      );
      return;
    }
    final path = UpdateService.instance.apkPath;
    if (path == null) return;
    final installed = await UpdateInstall.install(path);
    if (!installed) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not open the installer. Download the update manually.',
            style: const TextStyle(fontFamily: Tokens.fontFamily),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = UpdateService.instance.status;
    final info = UpdateService.instance.info;
    debugPrint('UpdateBanner.build: status=$status info=${info?.version} dismissed=$_dismissed');
    if (_dismissed || status != UpdateStatus.available || info == null) {
      return widget.child;
    }
    debugPrint('UpdateBanner: RENDERING banner for ${info.version}');
    return Column(
      children: [
        // Simple banner row (no Material wrapper — MaterialApp.builder already
        // provides a Material ancestor, and wrapping in another Material here
        // was causing the banner to not render/expose correctly).
        Container(
          width: double.infinity,
          color: Tokens.accentTint,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space4,
                vertical: Tokens.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Version ${info.version} is available',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        fontWeight: FontWeight.w600,
                        color: Tokens.accent,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _dismissed = true),
                    child: Text(
                      'Later',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        color: Tokens.inkMuted,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _showUpdateDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: Tokens.accent,
                      foregroundColor: Tokens.accentOn,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.space3,
                      ),
                    ),
                    child: Text(
                      'Update',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        fontWeight: FontWeight.w600,
                        color: Tokens.accentOn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // The app itself. Expanded so it takes all remaining space below the
        // banner (without it, Column would give the child unbounded height and
        // the app would render empty).
        Expanded(child: widget.child),
      ],
    );
  }
}