import 'package:flutter/material.dart';

import '../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/media_service.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';

/// Edit your own profile: name, email and the photo that appears next to it.
///
/// The photo is uploaded first (`POST /files`, purpose PROFILE), then the
/// profile is patched with the returned file id — the same order the backend
/// expects. Nothing here is mandatory except the name; an account with no
/// email yet is still valid.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();

  PickedFile? _photo;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await AppServices.instance.resident.profile();
      if (!mounted) return;
      setState(() {
        _name.text = asString(profile['name']);
        _email.text = asStringOrNull(profile['email']) ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await AppServices.instance.media.fromGallery();
      if (picked == null || !mounted) return;
      setState(() => _photo = picked);
    } on MediaException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      };
      if (_photo != null) {
        final id = await AppServices.instance.media.upload(
          _photo!,
          purpose: UploadPurpose.profile,
        );
        body['avatarFileId'] = id;
      }
      await AppServices.instance.resident.updateProfile(body);
      // The session carries the name for the whole app; refresh it so every
      // initial-based avatar and greeting updates immediately.
      await AppServices.instance.auth.refreshIdentity();
      AppServices.instance.attachSession();
      if (!mounted) return;
      showMessage(context, 'Profile saved.');
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
    if (_loading) {
      return const AppScaffold(title: 'Your profile', body: LoadingList());
    }
    if (_error != null && _name.text.isEmpty) {
      return AppScaffold(
        title: 'Your profile',
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }
    return AppScaffold(
      title: 'Your profile',
      subtitle: 'How you appear across the society',
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.only(bottom: 48),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Tokens.surfaceSunken,
                        shape: BoxShape.circle,
                        image: _photo == null
                            ? null
                            : DecorationImage(
                                image: MemoryImage(_photo!.bytes),
                                fit: BoxFit.cover,
                              ),
                      ),
                      child: _photo == null
                          ? Center(
                              child: Text(
                                AppServices.instance.session.displayName
                                        .trim()
                                        .isEmpty
                                    ? 'H'
                                    : AppServices.instance.session.displayName
                                          .trim()
                                          .substring(0, 1)
                                          .toUpperCase(),
                                style: TextStyle(
                                  fontFamily: Tokens.fontFamilyFigure,
                                  fontSize: Tokens.type2Xl,
                                  fontWeight: FontWeight.w600,
                                  color: Tokens.inkMuted,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Tokens.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Tokens.surface, width: 2),
                        ),
                        child: AppIcon(
                          Icons2.camera,
                          size: 14,
                          color: Tokens.accentOn,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: Tokens.space2),
            Center(
              child: Text(
                'Tap to change photo',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  color: Tokens.inkFaint,
                ),
              ),
            ),
            SizedBox(height: Tokens.space6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter your name'
                    : null,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
            ),
            SizedBox(height: Tokens.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null; // optional
                  if (!t.contains('@')) return 'Enter a valid email';
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  helperText: 'Used for receipts and notices',
                ),
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
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
