import 'dart:async';

import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../widgets/future_body.dart';
import 'super_society_create_screen.dart';
import 'super_society_detail_screen.dart';

/// A society is either Active or Inactive. Anything that is not ACTIVE (including
/// records left over from the old registration workflow) is shown as Inactive.
String societyStatusLabel(String raw) => raw == 'ACTIVE' ? 'Active' : 'Inactive';

Tone societyTone(String raw) => raw == 'ACTIVE' ? Tone.positive : Tone.neutral;

/// Every society on the platform, filterable by All / Active / Inactive.
class SuperSocietiesTab extends StatefulWidget {
  const SuperSocietiesTab({super.key});

  @override
  State<SuperSocietiesTab> createState() => _SuperSocietiesTabState();
}

class _SuperSocietiesTabState extends State<SuperSocietiesTab> {
  static const _filters = <(String, String)>[
    ('', 'All'),
    ('ACTIVE', 'Active'),
    ('INACTIVE', 'Inactive'),
  ];

  String _status = '';
  String _search = '';
  int _revision = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Societies',
      subtitle: 'Onboard and manage',
      showBack: false,
      fillBody: true,
      floatingAction: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const SuperSocietyCreateScreen()),
          );
          if (created == true) setState(() => _revision++);
        },
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        icon: const AppIcon(Icons2.add, size: IconSize.row),
        label: const Text('New society'),
      ),
      header: Column(
        children: [
          SearchField(
            hint: 'Search by name, code or city',
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                if (mounted) {
                  setState(() {
                    _search = v.trim();
                    _revision++;
                  });
                }
              });
            },
          ),
          const SizedBox(height: Tokens.space2),
          FilterChips(
            options: _filters,
            value: _status,
            onChanged: (v) => setState(() {
              _status = v;
              _revision++;
            }),
          ),
        ],
      ),
      body: PagedBody<PlatformSociety>(
        key: ValueKey('$_status|$_search|$_revision'),
        refreshOn: const ['society:updated'],
        emptyIcon: Icons2.societies,
        emptyTitle: 'No societies found',
        emptyMessage: 'Try another filter, or onboard a new society.',
        padding: const EdgeInsets.only(bottom: 96),
        fetch: (page) => AppServices.instance.superAdmin.societies(
          page: page,
          limit: 20,
          status: _status.isEmpty ? null : _status,
          search: _search,
        ),
        itemBuilder: (context, s, reload) => Panel(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SuperSocietyDetailScreen(societyId: s.id)),
            );
            reload();
          },
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeMd, fontWeight: FontWeight.w600, color: Tokens.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (s.code != null) s.code!,
                        if (s.city != null) s.city!,
                        if (s.adminName != null) s.adminName!,
                      ].join(' · '),
                      style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Tokens.space3),
              StatusBadge(label: societyStatusLabel(s.rawStatus), tone: societyTone(s.rawStatus)),
            ],
          ),
        ),
      ),
    );
  }
}
