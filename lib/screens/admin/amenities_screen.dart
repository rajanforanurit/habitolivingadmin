import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Amenities the society offers, and how their bookings go.
///
/// Two tabs: the amenities themselves (create/edit/remove) and the booking
/// log, where pending requests wait for a decision. Approving a booking here
/// is the whole job — the resident already sees the slot availability.
class AmenitiesScreen extends StatefulWidget {
  const AmenitiesScreen({super.key});

  @override
  State<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends State<AmenitiesScreen>
    with TickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Amenities',
      subtitle: 'What the society offers and who booked it',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: _Tabs(controller: _controller),
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: const [_AmenitiesTab(), _BookingsTab()],
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

  static const _labels = ['Amenities', 'Bookings'];

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

class _AmenitiesTab extends StatefulWidget {
  const _AmenitiesTab();

  @override
  State<_AmenitiesTab> createState() => _AmenitiesTabState();
}

class _AmenitiesTabState extends State<_AmenitiesTab> {
  int _revision = 0;
  late Future<List<Amenity>> _amenities = _load();

  Future<List<Amenity>> _load() => AppServices.instance.admin.amenities();

  void _reload() => setState(() {
    _amenities = _load();
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
                  'Amenities',
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
                  final ok = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const AmenityEditScreen(),
                    ),
                  );
                  if (ok == true) _reload();
                },
                icon: const AppIcon(Icons2.add, size: IconSize.inline),
                label: const Text('Add amenity'),
                style: TextButton.styleFrom(foregroundColor: Tokens.accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Amenity>>(
            key: ValueKey(_revision),
            future: _amenities,
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
              final items = snapshot.data ?? const <Amenity>[];
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons2.amenities,
                  title: 'No amenities yet',
                  message:
                      'Add the gym, the clubhouse, the swimming pool — anything '
                      'the residents book slots for.',
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: Tokens.space8),
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.space4,
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: i == items.length - 1 ? 0 : Tokens.space2,
                        ),
                        child: _Card(amenity: items[i], onChanged: _reload),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.amenity, required this.onChanged});

  final Amenity amenity;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () async {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => AmenityEditScreen(amenity: amenity),
          ),
        );
        if (ok == true) onChanged();
      },
      radius: 14,
      child: Container(
        padding: EdgeInsets.all(Tokens.space3),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: Tokens.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Tokens.accentTint,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
              child: Center(
                child: AppIcon(
                  Icons2.amenities,
                  size: IconSize.row,
                  color: Tokens.accent,
                ),
              ),
            ),
            SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amenity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      fontWeight: FontWeight.w600,
                      color: Tokens.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    [
                      amenity.type,
                      if (amenity.fee > 0)
                        '₹${amenity.fee.toStringAsFixed(0)}/slot',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      color: Tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            AppIcon(Icons2.forward, size: IconSize.row, color: Tokens.inkFaint),
          ],
        ),
      ),
    );
  }
}

class AmenityEditScreen extends StatefulWidget {
  const AmenityEditScreen({super.key, this.amenity});

  final Amenity? amenity;

  @override
  State<AmenityEditScreen> createState() => _AmenityEditScreenState();
}

class _AmenityEditScreenState extends State<AmenityEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.amenity?.name ?? '');
  late final _fee = TextEditingController(
    text: widget.amenity == null ? '0' : widget.amenity!.fee.toStringAsFixed(0),
  );
  late final _capacity = TextEditingController(
    text: widget.amenity == null ? '1' : '1',
  );

  String _type = 'GYM';
  String _slotDuration = '60';
  bool _active = true;
  bool _requiresApproval = false;
  bool _busy = false;
  String? _error;

  static final _types = <(String, String)>[
    ('GYM', 'Gym'),
    ('CLUBHOUSE', 'Clubhouse'),
    ('SWIMMING_POOL', 'Swimming pool'),
    ('SPORTS_COURT', 'Sports court'),
    ('PARTY_HALL', 'Party hall'),
    ('GARDEN', 'Garden'),
    ('OTHER', 'Other'),
  ];

  static final _durations = <(String, String)>[
    ('30', '30 min'),
    ('60', '1 hour'),
    ('90', '90 min'),
    ('120', '2 hours'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _fee.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Map<String, dynamic> _body() => {
    'name': _name.text.trim(),
    'type': _type,
    'capacity': int.tryParse(_capacity.text.trim()) ?? 1,
    'status': _active ? 'ACTIVE' : 'INACTIVE',
    'requiresApproval': _requiresApproval,
    'pricing': {
      'perSlot': double.tryParse(_fee.text.trim()) ?? 0,
      'deposit': 0,
    },
    'operatingHours': [
      for (final day in const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'])
        {'day': day, 'open': '06:00', 'close': '22:00'},
    ],
    'slotDurationMinutes': int.tryParse(_slotDuration) ?? 60,
  };

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final admin = AppServices.instance.admin;
      if (widget.amenity == null) {
        await admin.createAmenity(_body());
      } else {
        await admin.updateAmenity(widget.amenity!.id, _body());
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${widget.amenity!.name}?',
      message:
          'Past bookings are kept for the audit trail, but residents cannot '
          'book it again. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppServices.instance.admin.deleteAmenity(widget.amenity!.id);
      if (!mounted) return;
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
    final editing = widget.amenity != null;
    return AppScaffold(
      title: editing ? 'Edit amenity' : 'New amenity',
      subtitle: editing ? widget.amenity!.name : 'Something the residents book',
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.only(bottom: Tokens.space8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _name,
                autofocus: !editing,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Name the amenity'
                    : null,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ),
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Type',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
            ),
            SizedBox(height: Tokens.space3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final (value, label) in _types)
                    _Choice(
                      label: label,
                      selected: value == _type,
                      onTap: () => setState(() => _type = value),
                    ),
                ],
              ),
            ),
            SizedBox(height: Tokens.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Capacity'),
                    ),
                  ),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: TextFormField(
                      controller: _fee,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Fee per slot',
                        prefixText: '₹ ',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Slot duration',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
            ),
            SizedBox(height: Tokens.space3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final (value, label) in _durations)
                    _Choice(
                      label: label,
                      selected: value == _slotDuration,
                      onTap: () => setState(() => _slotDuration = value),
                    ),
                ],
              ),
            ),
            SizedBox(height: Tokens.space4),
            Panel(
              margin: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Booking needs approval',
                          style: TextStyle(
                            fontFamily: Tokens.fontFamily,
                            fontSize: Tokens.typeSm,
                            fontWeight: FontWeight.w600,
                            color: Tokens.ink,
                          ),
                        ),
                      ),
                      AppSwitch(
                        value: _requiresApproval,
                        onChanged: (v) => setState(() => _requiresApproval = v),
                      ),
                    ],
                  ),
                  Hairline(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Active',
                          style: TextStyle(
                            fontFamily: Tokens.fontFamily,
                            fontSize: Tokens.typeSm,
                            fontWeight: FontWeight.w600,
                            color: Tokens.ink,
                          ),
                        ),
                      ),
                      AppSwitch(
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                    ],
                  ),
                ],
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
                    : Text(editing ? 'Save amenity' : 'Create amenity'),
              ),
            ),
            if (editing) ...[
              SizedBox(height: Tokens.space2),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: OutlinedButton(
                  onPressed: _busy ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Tokens.danger,
                    side: BorderSide(color: Tokens.danger),
                    minimumSize: const Size.fromHeight(Tokens.controlHeight),
                  ),
                  child: const Text('Delete this amenity'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: selected ? Tokens.accent : Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
            border: Border.all(
              color: selected ? Tokens.accent : Tokens.lineStrong,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              fontWeight: FontWeight.w600,
              color: selected ? Tokens.accentOn : Tokens.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingsTab extends StatefulWidget {
  const _BookingsTab();

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  String _status = 'PENDING';
  int _revision = 0;

  static const _filters = <(String, String)>[
    ('PENDING', 'Pending'),
    ('CONFIRMED', 'Confirmed'),
    ('COMPLETED', 'Completed'),
    ('CANCELLED', 'Cancelled'),
    ('', 'All'),
  ];

  @override
  Widget build(BuildContext context) {
    final admin = AppServices.instance.admin;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            children: [
              for (final (value, label) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: Tokens.space2),
                  child: _Chip(
                    label: label,
                    selected: value == _status,
                    onTap: () => setState(() {
                      _status = value;
                      _revision++;
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _BookingList(
            key: ValueKey('$_status-$_revision'),
            status: _status,
            fetch: (page) => admin.amenityBookings(
              page: page,
              limit: 20,
              status: _status.isEmpty ? null : _status,
            ),
            onChanged: () => setState(() => _revision++),
          ),
        ),
      ],
    );
  }
}

class _BookingList extends StatefulWidget {
  const _BookingList({
    super.key,
    required this.status,
    required this.fetch,
    required this.onChanged,
  });

  final String status;
  final Future<dynamic> Function(int page) fetch;
  final VoidCallback onChanged;

  @override
  State<_BookingList> createState() => _BookingListState();
}

class _BookingListState extends State<_BookingList> {
  final _scroll = ScrollController();
  final List<dynamic> _items = [];
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
      _load();
    }
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
      final result = await widget.fetch(_page);
      if (!mounted) return;
      setState(() {
        _items.addAll((result as dynamic).items as List<dynamic>);
        _page++;
        _hasMore = (result as dynamic).hasMore as bool;
        _error = null;
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
        icon: Icons2.amenities,
        title: 'Nothing matches',
        message: 'No bookings with this status yet.',
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
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: i == _items.length - 1 ? 0 : Tokens.space2,
                ),
                child: _BookingRow(
                  booking: _items[i] as Booking,
                  onChanged: widget.onChanged,
                ),
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

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking, required this.onChanged});

  final Booking booking;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final pending = booking.status.toUpperCase() == 'PENDING';
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
                  booking.amenityName,
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
              StatusBadge.forStatus(
                booking.status,
                domain: StatusDomain.generic,
                dot: false,
              ),
            ],
          ),
          SizedBox(height: Tokens.space2),
          Text(
            [
              if (booking.startAt != null) Fmt.dateTime(booking.startAt),
              if (booking.flatLabel != null) booking.flatLabel!,
              if (booking.amount > 0) Fmt.money(booking.amount),
            ].join(' · '),
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              color: Tokens.inkMuted,
            ),
          ),
          if (pending) ...[
            const SizedBox(height: Tokens.space3),
            Row(
              children: [
                _Action(
                  label: 'Approve',
                  icon: Icons2.success,
                  onTap: () async {
                    try {
                      await AppServices.instance.admin.markBooking(
                        booking.id,
                        status: 'approved',
                      );
                      if (context.mounted) {
                        showMessage(context, 'Booking approved.');
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
                      await AppServices.instance.admin.markBooking(
                        booking.id,
                        status: 'rejected',
                      );
                      if (context.mounted) {
                        showMessage(context, 'Booking rejected.');
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
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: selected ? Tokens.accent : Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
            border: Border.all(
              color: selected ? Tokens.accent : Tokens.lineStrong,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              fontWeight: FontWeight.w600,
              color: selected ? Tokens.accentOn : Tokens.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
