import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Vehicles registered in the society, and where they are allowed to park.
///
/// Three tabs, because they are three different questions: what drives in
/// here, which slots exist, and who asked for one. Approving a parking
/// request means assigning a slot to a flat, not just ticking a box.
class VehiclesParkingScreen extends StatefulWidget {
  const VehiclesParkingScreen({super.key});

  @override
  State<VehiclesParkingScreen> createState() => _VehiclesParkingScreenState();
}

class _VehiclesParkingScreenState extends State<VehiclesParkingScreen>
    with TickerProviderStateMixin {
  late final TabController _controller = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Vehicles & parking',
      subtitle: 'Who drives here and where they park',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: _Tabs(controller: _controller),
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: const [_VehiclesTab(), _SlotsTab(), _RequestsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller});
  final TabController controller;

  static const _labels = ['Vehicles', 'Slots', 'Requests'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Tokens.surfaceSunken,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final selected = controller.index == i;
                  return Semantics(
                    button: true,
                    selected: selected,
                    child: InkResponse(
                      onTap: () => controller.animateTo(i),
                      radius: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: Tokens.space2,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? Tokens.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(Tokens.radiusXs),
                        ),
                        child: Text(
                          _labels[i],
                          style: TextStyle(
                            fontFamily: Tokens.fontFamily,
                            fontSize: Tokens.typeXs,
                            fontWeight: FontWeight.w600,
                            color: selected ? Tokens.ink : Tokens.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- vehicles

class _VehiclesTab extends StatefulWidget {
  const _VehiclesTab();

  @override
  State<_VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<_VehiclesTab> {
  final _scroll = ScrollController();
  final List<SocietyVehicle> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _initial = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 320) {
      return;
    }
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _items.clear();
      _initial = true;
      _error = null;
      setState(() {});
    }
    if (!_hasMore) return;

    setState(() => _loading = true);
    try {
      final page = await AppServices.instance.admin.vehicles(
        page: _page,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page++;
        _hasMore = page.hasMore;
        _initial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _initial = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initial && _loading) return LoadingList();
    if (_items.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: () => _load(refresh: true));
    }
    if (_items.isEmpty && !_loading) {
      return const EmptyState(
        icon: Icons2.vehicles,
        title: 'No vehicles registered',
        message:
            'Residents register vehicles from their own app; they show up here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: Tokens.accent,
      child: ListView(
        controller: _scroll,
        padding: EdgeInsets.only(bottom: Tokens.space6),
        children: [
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: ListRow(
                title: _items[i].plate,
                subtitle: [
                  _items[i].type,
                  if (_items[i].ownerName != null) _items[i].ownerName!,
                  if (_items[i].flatLabel != null) _items[i].flatLabel!,
                  if (_items[i].slotLabel != null)
                    'slot ${_items[i].slotLabel}',
                ].join(' · '),
                icon: Icons2.vehicles,
                dense: true,
                showChevron: false,
                trailing: _items[i].status == null
                    ? null
                    : MetaTag(_items[i].status!),
              ),
            ),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: Tokens.space4),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Tokens.surfaceSunken,
                color: Tokens.accent,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- slots

class _SlotsTab extends StatefulWidget {
  const _SlotsTab();

  @override
  State<_SlotsTab> createState() => _SlotsTabState();
}

class _SlotsTabState extends State<_SlotsTab> {
  int _revision = 0;
  late Future<List<ParkingSlot>> _slots = AppServices.instance.admin
      .parkingSlots();

  void _reload() => setState(() {
    _slots = AppServices.instance.admin.parkingSlots();
    _revision++;
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            Tokens.space4,
            Tokens.space2,
            Tokens.space4,
            Tokens.space2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Parking slots',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    fontWeight: FontWeight.w600,
                    color: Tokens.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => const _SlotDialog(),
                  );
                  if (ok == true) _reload();
                },
                icon: const AppIcon(Icons2.add, size: IconSize.inline),
                label: const Text('Add slot'),
                style: TextButton.styleFrom(foregroundColor: Tokens.accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ParkingSlot>>(
            key: ValueKey(_revision),
            future: _slots,
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
              final items = snapshot.data ?? const <ParkingSlot>[];
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons2.gate,
                  title: 'No parking slots',
                  message:
                      'Add the slots the society has — including visitor and '
                      'two-wheeler spaces — so requests can be satisfied.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                color: Tokens.accent,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: Tokens.space8),
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Tokens.space4,
                        ),
                        child: ListRow(
                          title: items[i].label,
                          subtitle: [
                            if (items[i].type != null) items[i].type!,
                            if (items[i].flatLabel != null)
                              'assigned to ${items[i].flatLabel}',
                          ].join(' · '),
                          icon: Icons2.gate,
                          dense: true,
                          showChevron: false,
                          trailing: StatusBadge.forStatus(
                            items[i].status,
                            domain: StatusDomain.generic,
                            dot: false,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SlotDialog extends StatefulWidget {
  const _SlotDialog();

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  final _label = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: const Text('New parking slot'),
      content: TextField(
        controller: _label,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'Label', hintText: 'P-12'),
        onSubmitted: (_) => _create(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      showMessage(context, 'Give the slot a label.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppServices.instance.admin.createParkingSlot(label: label);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, '$e', error: true);
    }
  }
}

// ---------------------------------------------------------------- requests

class _RequestsTab extends StatefulWidget {
  const _RequestsTab();

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  int _revision = 0;
  late Future<List<Map<String, dynamic>>> _requests = AppServices.instance.admin
      .parkingRequests();

  void _reload() => setState(() {
    _requests = AppServices.instance.admin.parkingRequests();
    _revision++;
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(_revision),
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingList();
        }
        if (snapshot.hasError) {
          return ErrorState(message: '${snapshot.error}', onRetry: _reload);
        }
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons2.success,
            title: 'No parking requests',
            message: 'When a resident asks for a slot it appears here.',
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: Tokens.space8),
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: i == items.length - 1 ? 0 : Tokens.space2,
                  ),
                  child: _RequestCard(row: items[i], onChanged: _reload),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.row, required this.onChanged});

  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final id = asString(row['id']);
    final flat =
        asStringOrNull(row['flatLabel']) ??
        asStringOrNull(asMapOrNull(row['flat'])?['label']) ??
        'Flat';
    final status = asString(row['status'], fallback: 'PENDING');
    final note = asStringOrNull(row['note']);
    final vehicle =
        asStringOrNull(row['vehicleNumber']) ??
        asStringOrNull(row['plate']) ??
        asStringOrNull(row['vehicleType']);

    return Container(
      padding: EdgeInsets.all(Tokens.space3),
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
                  flat,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    fontWeight: FontWeight.w600,
                    color: Tokens.ink,
                  ),
                ),
              ),
              StatusBadge.forStatus(
                status,
                domain: StatusDomain.generic,
                dot: false,
              ),
            ],
          ),
          if (vehicle != null || note != null) ...[
            SizedBox(height: Tokens.space2),
            Text(
              [
                if (vehicle != null) vehicle,
                if (note != null) note,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                height: 1.4,
                color: Tokens.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: Tokens.space3),
          Row(
            children: [
              _Action(
                label: 'Approve',
                icon: Icons2.success,
                onTap: () async {
                  try {
                    await AppServices.instance.admin.respondParkingRequest(
                      id,
                      approve: true,
                    );
                    if (context.mounted) {
                      showMessage(context, 'Request approved.');
                    }
                    onChanged();
                  } catch (e) {
                    if (context.mounted) {
                      showMessage(context, '$e', error: true);
                    }
                  }
                },
              ),
              const SizedBox(width: Tokens.space2),
              _Action(
                label: 'Reject',
                icon: Icons2.close,
                destructive: true,
                onTap: () async {
                  try {
                    await AppServices.instance.admin.respondParkingRequest(
                      id,
                      approve: false,
                    );
                    if (context.mounted) {
                      showMessage(context, 'Request rejected.');
                    }
                    onChanged();
                  } catch (e) {
                    if (context.mounted) {
                      showMessage(context, '$e', error: true);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
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
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: Tokens.space2,
          ),
          decoration: BoxDecoration(
            color: destructive ? Tokens.dangerTint : Tokens.accentTint,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: IconSize.inline, color: fg),
              const SizedBox(width: Tokens.space1),
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
