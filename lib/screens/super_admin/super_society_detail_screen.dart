import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/ops.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../widgets/file_preview.dart';
import '../widgets/future_body.dart';
import '../widgets/property_info_form.dart';
import '../widgets/validators.dart';
import 'super_societies_tab.dart';

class _Detail {
  const _Detail(this.society, this.info, this.administration);
  final PlatformSociety society;
  final SocietyInfo info;

  /// Null when the administration request failed; the section then shows a retry hint
  /// instead of pretending there is no administrator.
  final SocietyAdministration? administration;
}

/// One society as the platform team sees it: status, applicant / admin,
/// property details and hospitals, with the lifecycle actions.
class SuperSocietyDetailScreen extends StatefulWidget {
  const SuperSocietyDetailScreen({super.key, required this.societyId});

  final String societyId;

  @override
  State<SuperSocietyDetailScreen> createState() => _SuperSocietyDetailScreenState();
}

class _SuperSocietyDetailScreenState extends State<SuperSocietyDetailScreen> {
  int _revision = 0;
  bool _busy = false;

  Future<_Detail> _load() async {
    final api = AppServices.instance.superAdmin;
    final results = await Future.wait<Object?>([
      api.society(widget.societyId),
      api.societyInfo(widget.societyId),
      api.administration(widget.societyId).then<SocietyAdministration?>((v) => v).catchError((Object _) => null),
    ]);
    return _Detail(
      results[0] as PlatformSociety,
      results[1] as SocietyInfo,
      results[2] as SocietyAdministration?,
    );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, done);
      setState(() => _revision++);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(_Detail d) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ApproveScreen(society: d.society, info: d.info),
        fullscreenDialog: true,
      ),
    );
    if (ok == true && mounted) {
      showMessage(context, 'Society approved. The administrator can sign in now.');
      setState(() => _revision++);
    }
  }

  Future<void> _reject(_Detail d) async {
    final reason = await promptText(
      context,
      title: 'Reject ${d.society.name}?',
      hint: 'Reason (shown to the applicant)',
      confirmLabel: 'Reject',
      required: true,
      destructive: true,
    );
    if (reason == null) return;
    await _run(
      () => AppServices.instance.superAdmin.rejectRegistration(d.society.id, reason: reason),
      'Registration rejected.',
    );
  }

  Future<void> _deactivate(_Detail d) async {
    final reason = await promptText(
      context,
      title: 'Deactivate ${d.society.name}?',
      hint: 'Reason (optional)',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (reason == null) return;
    await _run(
      () => AppServices.instance.superAdmin.deactivateSociety(d.society.id, reason: reason),
      'Society deactivated. Its users can no longer sign in.',
    );
  }

  Future<void> _editProperty(_Detail d) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PropertyEditScreen(societyId: d.society.id, societyName: d.society.name, info: d.info),
      ),
    );
    if (saved == true && mounted) {
      showMessage(context, 'Property details saved.');
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Society',
      fillBody: true,
      body: FutureBody<_Detail>(
        key: ValueKey(_revision),
        load: _load,
        builder: (context, d, reload) {
          final s = d.society;
          final raw = s.rawStatus;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: Tokens.space8),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.name,
                      style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeLg, fontWeight: FontWeight.w600, color: Tokens.ink),
                    ),
                  ),
                  StatusBadge(label: s.status, tone: societyTone(raw)),
                ],
              ),
              const SizedBox(height: Tokens.space4),
              if (raw == 'PENDING') _PendingBanner(onApprove: () => _approve(d), onReject: () => _reject(d), busy: _busy),
              if (raw == 'ACTIVE')
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _deactivate(d),
                  icon: const AppIcon(Icons2.cancel, size: IconSize.inline),
                  label: const Text('Deactivate society'),
                ),
              if (raw == 'INACTIVE' || raw == 'REJECTED')
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.accentOn),
                  onPressed: _busy
                      ? null
                      : () => raw == 'REJECTED' ? _approve(d) : _run(() => AppServices.instance.superAdmin.activateSociety(s.id), 'Society activated.'),
                  icon: const AppIcon(Icons2.success, size: IconSize.inline),
                  label: Text(raw == 'REJECTED' ? 'Approve instead' : 'Activate society'),
                ),
              const SizedBox(height: Tokens.space5),
              const SectionLabel('Overview'),
              const SizedBox(height: Tokens.space2),
              Panel(
                child: Column(
                  children: [
                    if (s.code != null) DetailRow(label: 'Society code', value: s.code!),
                    DetailRow(label: 'Property type', value: PropertyKind.label(d.info.propertyType ?? s.propertyType)),
                    if (d.info.propertyDetails.totalUnits != null) DetailRow(label: 'Total units', value: '${d.info.propertyDetails.totalUnits}'),
                    DetailRow(label: 'Location', value: [s.city, s.state].whereType<String>().join(', ').isEmpty ? '—' : [s.city, s.state].whereType<String>().join(', ')),
                    if (s.plan != null) DetailRow(label: 'Plan', value: s.plan!),
                    DetailRow(label: 'Residents', value: '${s.residentCount}'),
                    if (s.createdAt != null) DetailRow(label: 'Registered', value: Fmt.date(s.createdAt)),
                  ],
                ),
              ),
              const SizedBox(height: Tokens.space5),
              _AdministrationView(administration: d.administration, society: s),
              const SizedBox(height: Tokens.space5),
              SectionLabel(
                'Property and floor plans',
                trailing: TextButton.icon(
                  onPressed: () => _editProperty(d),
                  icon: const AppIcon(Icons2.edit, size: IconSize.inline),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(height: Tokens.space2),
              _PropertyView(details: d.info.propertyDetails),
              const SizedBox(height: Tokens.space5),
              const SectionLabel('Hospitals'),
              const SizedBox(height: Tokens.space2),
              _HospitalsView(hospitals: d.info.hospitals),
            ],
          );
        },
      ),
    );
  }
}

/// Who runs the society, read from the saved records: administrators with their
/// contact details, role, status and last sign-in, plus who created or approved
/// the society and, for self-registered societies, the original applicant.
class _AdministrationView extends StatelessWidget {
  const _AdministrationView({required this.administration, required this.society});
  final SocietyAdministration? administration;
  final PlatformSociety society;

  TextStyle get _muted => TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted, height: 1.4);

  @override
  Widget build(BuildContext context) {
    final a = administration;
    if (a == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Administration details'),
          const SizedBox(height: Tokens.space2),
          Panel(child: Text('Could not load the administration details. Pull down to refresh.', style: _muted)),
        ],
      );
    }
    final pending = society.rawStatus == 'PENDING';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Administration details'),
        const SizedBox(height: Tokens.space2),
        Panel(
          child: Column(
            children: [
              if (a.createdAt != null)
                DetailRow(label: 'Created', value: [Fmt.date(a.createdAt), if (a.createdByName != null) 'by ${a.createdByName}'].join(' ')),
              if (a.approvedAt != null)
                DetailRow(label: 'Approved', value: [Fmt.date(a.approvedAt), if (a.approvedByName != null) 'by ${a.approvedByName}'].join(' ')),
              DetailRow(label: 'Administrators', value: '${a.administrators.length} (${a.administrators.where((x) => x.isActive).length} active)'),
              if ((a.statusReason ?? '').isNotEmpty) DetailRow(label: 'Status note', value: a.statusReason!),
              if (a.hasApplicant) ...[
                if (a.applicantName != null) DetailRow(label: 'Applicant', value: a.applicantName!),
                if (a.applicantMobile != null) DetailRow(label: 'Applicant mobile', value: Fmt.phone(a.applicantMobile)),
                if (a.applicantEmail != null) DetailRow(label: 'Applicant email', value: a.applicantEmail!),
                if ((a.applicantNotes ?? '').isNotEmpty) DetailRow(label: 'Applicant notes', value: a.applicantNotes!),
              ],
            ],
          ),
        ),
        const SizedBox(height: Tokens.space4),
        const SectionLabel('Administrators'),
        const SizedBox(height: Tokens.space2),
        if (a.administrators.isEmpty)
          Panel(
            child: Row(
              children: [
                const AppIcon(Icons2.administrators, size: IconSize.row),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Text(
                    pending
                        ? 'No administrator yet. One is created when you approve this registration.'
                        : 'No administrator has been assigned to this society.',
                    style: _muted,
                  ),
                ),
              ],
            ),
          )
        else
          for (final admin in a.administrators) ...[
            _AdministratorCard(admin: admin),
            const SizedBox(height: Tokens.space3),
          ],
      ],
    );
  }
}

class _AdministratorCard extends StatelessWidget {
  const _AdministratorCard({required this.admin});
  final AdministratorRecord admin;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(name: admin.name),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(admin.name, style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
                    Text(
                      [if (admin.designation != null) admin.designation!, if (admin.roleName != null) admin.roleName!].join(' · '),
                      style: muted,
                    ),
                  ],
                ),
              ),
              StatusBadge.forStatus(admin.status),
            ],
          ),
          const SizedBox(height: Tokens.space3),
          const Hairline(),
          if (admin.mobile != null) DetailRow(label: 'Mobile', value: Fmt.phone(admin.mobile)),
          if (admin.email != null) DetailRow(label: 'Email', value: admin.email!),
          DetailRow(label: 'Last sign-in', value: admin.lastLoginAt == null ? 'Never signed in' : Fmt.relative(admin.lastLoginAt)),
          if (admin.addedAt != null) DetailRow(label: 'Added', value: Fmt.date(admin.addedAt)),
          if (admin.mustChangePassword)
            Padding(
              padding: const EdgeInsets.only(top: Tokens.space2),
              child: Align(alignment: Alignment.centerLeft, child: const StatusBadge(label: 'Must change password', tone: Tone.warning)),
            ),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.onApprove, required this.onReject, required this.busy});
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Panel(
      color: Tokens.warningTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Awaiting your verification',
            style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink),
          ),
          const SizedBox(height: Tokens.space1),
          Text(
            'Approving creates the society administrator account and unlocks sign-in. Add the floor plan and hospitals now, or later from this page.',
            style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted, height: 1.4),
          ),
          const SizedBox(height: Tokens.space4),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.accentOn),
                  onPressed: busy ? null : onApprove,
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Tokens.danger),
                  onPressed: busy ? null : onReject,
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PropertyView extends StatelessWidget {
  const _PropertyView({required this.details});
  final PropertyDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) {
      return Panel(
        child: Text(
          'No property details yet. Residents and the society admin see these once you add them.',
          style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          child: Column(
            children: [
              if ((details.propertyName ?? '').isNotEmpty) DetailRow(label: 'Property', value: details.propertyName!),
              if (details.totalTowers != null && details.totalTowers! > 0) DetailRow(label: 'Towers', value: '${details.totalTowers}'),
              if (details.totalFloors != null && details.totalFloors! > 0) DetailRow(label: 'Max floors', value: '${details.totalFloors}'),
              if (details.totalUnits != null) DetailRow(label: 'Units', value: '${details.totalUnits}'),
              if ((details.parkingInfo ?? '').isNotEmpty) DetailRow(label: 'Parking', value: details.parkingInfo!),
              if ((details.description ?? '').isNotEmpty) DetailRow(label: 'About', value: details.description!),
              if ((details.notes ?? '').isNotEmpty) DetailRow(label: 'Notes', value: details.notes!),
            ],
          ),
        ),
        if (details.towers.isNotEmpty) ...[
          const SizedBox(height: Tokens.space3),
          Panel(
            child: Column(
              children: [
                for (var i = 0; i < details.towers.length; i++) ...[
                  if (i > 0) const Hairline(),
                  ListRow(
                    title: '${details.towers[i].name} (${details.towers[i].code})',
                    subtitle: '${details.towers[i].floors.length} floors · ${details.towers[i].totalUnits} units',
                    icon: Icons2.tower,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (details.singleFamily != null) ...[
          const SizedBox(height: Tokens.space3),
          Panel(
            child: DetailRow(
              label: 'Houses',
              value: '${details.singleFamily!.totalHouses} · ${details.singleFamily!.labelAt(0)} … ${details.singleFamily!.labelAt(details.singleFamily!.totalHouses - 1)}',
            ),
          ),
        ],
        for (final plan in details.floorPlans) ...[
          const SizedBox(height: Tokens.space3),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.title, style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
                if ((plan.description ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(plan.description!, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted)),
                  ),
                if (plan.fileId != null) ...[
                  const SizedBox(height: Tokens.space3),
                  FilePreview(fileId: plan.fileId!),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HospitalsView extends StatelessWidget {
  const _HospitalsView({required this.hospitals});
  final List<Hospital> hospitals;

  @override
  Widget build(BuildContext context) {
    if (hospitals.isEmpty) {
      return Panel(
        child: Text('No hospitals added.', style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted)),
      );
    }
    return Panel(
      child: Column(
        children: [
          for (var i = 0; i < hospitals.length; i++) ...[
            if (i > 0) const Hairline(),
            ListRow(
              title: hospitals[i].name,
              subtitle: [
                Fmt.phone(hospitals[i].phone),
                if (hospitals[i].distanceKm != null) '${hospitals[i].distanceKm} km',
                if (hospitals[i].open24x7) '24×7',
              ].join(' · '),
              icon: Icons2.emergency,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Approve a pending society: confirm the administrator's credentials and
/// attach the property details and hospitals in one step.
class _ApproveScreen extends StatefulWidget {
  const _ApproveScreen({required this.society, required this.info});
  final PlatformSociety society;
  final SocietyInfo info;

  @override
  State<_ApproveScreen> createState() => _ApproveScreenState();
}

class _ApproveScreenState extends State<_ApproveScreen> {
  final _form = GlobalKey<FormState>();
  final _property = GlobalKey<PropertyInfoEditorState>();
  late final _name = TextEditingController(text: widget.society.adminName ?? '');
  late final _mobile = TextEditingController(text: widget.society.adminMobile ?? '');
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final editor = _property.currentState;
    final problem = editor?.validate();
    if (editor == null || problem != null) {
      setState(() => _error = problem ?? 'Configure the property first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.superAdmin.approveRegistration(
        widget.society.id,
        password: _password.text,
        name: _name.text,
        mobile: _mobile.text,
        email: _email.text,
        propertyType: editor.propertyType!,
        propertyDetails: editor.details,
        hospitals: editor.hospitals,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Approve society',
      subtitle: widget.society.name,
      bottom: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space5),
          child: FilledButton(
            onPressed: (_busy || !(_property.currentState?.isLayoutComplete ?? false)) ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.accentOn, minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Approve and create administrator'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Administrator account'),
            const SizedBox(height: Tokens.space2),
            TextFormField(controller: _name, validator: Validators.required, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: Tokens.space3),
            TextFormField(controller: _mobile, validator: Validators.mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number (login)')),
            const SizedBox(height: Tokens.space3),
            TextFormField(controller: _email, validator: Validators.optionalEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)')),
            const SizedBox(height: Tokens.space3),
            TextFormField(
              controller: _password,
              obscureText: !_show,
              validator: Validators.password,
              decoration: InputDecoration(
                labelText: 'Initial password',
                suffixIcon: IconButton(icon: Icon(_show ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _show = !_show)),
              ),
            ),
            const SizedBox(height: Tokens.space6),
            PropertyInfoEditor(
              key: _property,
              initialDetails: widget.info.propertyDetails,
              initialHospitals: widget.info.hospitals,
              initialPropertyName: widget.society.name,
              initialPropertyType: widget.info.propertyType,
              onChanged: () => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: Tokens.space4),
              Text(_error!, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.danger)),
            ],
            const SizedBox(height: Tokens.space6),
          ],
        ),
      ),
    );
  }
}

class _PropertyEditScreen extends StatefulWidget {
  const _PropertyEditScreen({required this.societyId, required this.societyName, required this.info});
  final String societyId;
  final String societyName;
  final SocietyInfo info;

  @override
  State<_PropertyEditScreen> createState() => _PropertyEditScreenState();
}

class _PropertyEditScreenState extends State<_PropertyEditScreen> {
  final _property = GlobalKey<PropertyInfoEditorState>();
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final editor = _property.currentState!;
    final problem = editor.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.superAdmin.setPropertyInfo(
        widget.societyId,
        propertyType: editor.propertyType,
        propertyDetails: editor.details,
        hospitals: editor.hospitals,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Property details',
      subtitle: widget.societyName,
      bottom: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space5),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.accentOn, minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Only the platform team can change this. The society admin, residents and guards see it read-only. Towers, floors and units can be added, not removed.',
            style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted, height: 1.4),
          ),
          const SizedBox(height: Tokens.space5),
          PropertyInfoEditor(
            key: _property,
            initialDetails: widget.info.propertyDetails,
            initialHospitals: widget.info.hospitals,
            initialPropertyName: widget.societyName,
            initialPropertyType: widget.info.propertyType,
            // Older societies may have no layout yet; floor plans and hospitals can still be saved.
            layoutRequired: widget.info.propertyType != null || widget.info.propertyDetails.hasLayout,
            lockType: widget.info.propertyType != null,
          ),
          if (_error != null) ...[
            const SizedBox(height: Tokens.space4),
            Text(_error!, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.danger)),
          ],
          const SizedBox(height: Tokens.space6),
        ],
      ),
    );
  }
}
