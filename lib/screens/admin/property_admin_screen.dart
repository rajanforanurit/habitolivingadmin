import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Property listings, from the admin's moderation seat.
///
/// Every property a resident posts passes through review before it goes
/// live. The queue is the approval pipeline; these two tabs are the parts it
/// feeds — the listings themselves, and the reports filed against them.
class PropertyAdminScreen extends StatefulWidget {
  const PropertyAdminScreen({super.key});

  @override
  State<PropertyAdminScreen> createState() => _PropertyAdminScreenState();
}

class _PropertyAdminScreenState extends State<PropertyAdminScreen>
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
      title: 'Property',
      subtitle: 'Listings and reports',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Tabs(controller: _controller),
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: const [_ListingsTab(), _ReportsTab()],
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

  static const _labels = ['Listings', 'Reports'];

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
                        padding: const EdgeInsets.symmetric(vertical: 10),
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

class _ListingsTab extends StatefulWidget {
  const _ListingsTab();

  @override
  State<_ListingsTab> createState() => _ListingsTabState();
}

class _ListingsTabState extends State<_ListingsTab> {
  String _status = 'PUBLISHED';

  static const _filters = <(String, String)>[
    ('PUBLISHED', 'Published'),
    ('APPROVED', 'Approved'),
    ('UNDER_REVIEW', 'In review'),
    ('REJECTED', 'Rejected'),
    ('', 'All'),
  ];

  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final admin = AppServices.instance.admin;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final (value, label) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
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
          child: _ListingList(
            key: ValueKey('$_status-$_revision'),
            status: _status,
            fetch: (page) => admin.propertyListings(
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

class _ListingList extends StatefulWidget {
  const _ListingList({
    super.key,
    required this.status,
    required this.fetch,
    required this.onChanged,
  });

  final String status;
  final Future<PageResult<PropertyListing>> Function(int page) fetch;
  final VoidCallback onChanged;

  @override
  State<_ListingList> createState() => _ListingListState();
}

class _ListingListState extends State<_ListingList> {
  final _scroll = ScrollController();
  final List<PropertyListing> _items = [];
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
      final page = await widget.fetch(_page);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page++;
        _hasMore = page.hasMore;
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
        icon: Icons2.property,
        title: 'Nothing here',
        message: 'No listings with this status.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: Tokens.accent,
      child: ListView(
        controller: _scroll,
        padding: EdgeInsets.only(bottom: 32),
        children: [
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: i == _items.length - 1 ? 0 : 8,
                ),
                child: _ListingRow(
                  listing: _items[i],
                  onChanged: widget.onChanged,
                ),
              ),
            ),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
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

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing, required this.onChanged});

  final PropertyListing listing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
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
                    listing.type,
                    Fmt.money(listing.price),
                    if (listing.areaSqft != null) '${listing.areaSqft} sq ft',
                    if (listing.location != null) listing.location!,
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
          StatusBadge.forStatus(
            listing.status,
            domain: StatusDomain.generic,
            dot: false,
          ),
          SizedBox(width: 8),
          IconButton(
            tooltip: 'Remove listing',
            icon: AppIcon(
              Icons2.delete,
              size: IconSize.row,
              color: Tokens.inkFaint,
            ),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Remove this listing?',
                message:
                    'It disappears from property search. The removal is logged.',
                confirmLabel: 'Remove',
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              try {
                await AppServices.instance.admin.removePropertyListing(
                  listing.id,
                );
                if (context.mounted) showMessage(context, 'Listing removed.');
                onChanged();
              } catch (e) {
                if (context.mounted) showMessage(context, '$e', error: true);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  String _status = 'OPEN';

  static const _filters = <(String, String)>[
    ('OPEN', 'Open'),
    ('REVIEWED', 'Reviewed'),
    ('DISMISSED', 'Dismissed'),
    ('', 'All'),
  ];

  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final admin = AppServices.instance.admin;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final (value, label) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
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
          child: FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('$_status-$_revision'),
            future: admin.propertyReports(
              status: _status.isEmpty ? null : _status,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingList();
              }
              if (snapshot.hasError) {
                return ErrorState(
                  message: '${snapshot.error}',
                  onRetry: () => setState(() => _revision++),
                );
              }
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons2.success,
                  title: 'No reports',
                  message: 'Nothing to review.',
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: i == items.length - 1 ? 0 : 8,
                        ),
                        child: _ReportCard(
                          row: items[i],
                          onChanged: () => setState(() => _revision++),
                        ),
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.row, required this.onChanged});

  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final reason =
        asStringOrNull(row['reason']) ??
        asStringOrNull(row['note']) ??
        'Reported';
    final listing =
        asStringOrNull(row['listingTitle']) ??
        asStringOrNull(row['title']) ??
        'Listing';
    final status = asString(row['status'], fallback: 'OPEN');
    final createdAt = asDateOrNull(row['createdAt']);
    final id = asString(row['id']);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listing,
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
            reason,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              height: 1.4,
              color: Tokens.inkMuted,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    status,
                    if (createdAt != null) Fmt.relative(createdAt),
                  ].join(' · '),
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeXs,
                    color: Tokens.inkFaint,
                  ),
                ),
              ),
              if (status.toUpperCase() == 'OPEN')
                TextButton(
                  onPressed: () async {
                    try {
                      await AppServices.instance.admin.resolvePropertyReport(
                        id,
                        decision: 'DISMISSED',
                      );
                      if (context.mounted) {
                        showMessage(context, 'Report dismissed.');
                      }
                      onChanged();
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '$e', error: true);
                      }
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: Tokens.inkMuted),
                  child: const Text('Dismiss'),
                ),
              if (status.toUpperCase() == 'OPEN')
                TextButton(
                  onPressed: () async {
                    try {
                      await AppServices.instance.admin.resolvePropertyReport(
                        id,
                        decision: 'REMOVED',
                      );
                      if (context.mounted) {
                        showMessage(context, 'Listing removed.');
                      }
                      onChanged();
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '$e', error: true);
                      }
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: Tokens.danger),
                  child: const Text('Remove listing'),
                ),
            ],
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
