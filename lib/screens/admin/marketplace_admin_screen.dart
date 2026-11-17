import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Marketplace, from the admin's seat: listings, categories and the reports
/// residents file against each other.
///
/// Listings in APPROVED or PUBLISHED state are live for the society. Removing
/// one is a moderation action — the audit trail records who removed it and
/// why. Categories power the sell flow, so a typo there shows up for everyone.
class MarketplaceAdminScreen extends StatefulWidget {
  const MarketplaceAdminScreen({super.key});

  @override
  State<MarketplaceAdminScreen> createState() => _MarketplaceAdminScreenState();
}

class _MarketplaceAdminScreenState extends State<MarketplaceAdminScreen>
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
      title: 'Marketplace',
      subtitle: 'Listings, categories and reports',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: _Tabs(controller: _controller),
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: const [_ListingsTab(), _CategoriesTab(), _ReportsTab()],
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

  static const _labels = ['Listings', 'Categories', 'Reports'];

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

// ---------------------------------------------------------------- listings

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
          child: _ListingList(
            key: ValueKey('$_status-$_revision'),
            status: _status,
            fetch: (page) => admin.marketplaceListings(
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
  final Future<PageResult<Listing>> Function(int page) fetch;
  final VoidCallback onChanged;

  @override
  State<_ListingList> createState() => _ListingListState();
}

class _ListingListState extends State<_ListingList> {
  final _scroll = ScrollController();
  final List<Listing> _items = [];
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
        icon: Icons2.marketplace,
        title: 'Nothing here',
        message: 'No listings with this status.',
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
                child: _ListingRow(
                  listing: _items[i],
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

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing, required this.onChanged});

  final Listing listing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Tokens.space3),
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
                    listing.category,
                    Fmt.money(listing.price),
                    if (listing.createdAt != null)
                      Fmt.relative(listing.createdAt),
                  ].whereType<String>().join(' · '),
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
          SizedBox(width: Tokens.space2),
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
                    'It disappears from the marketplace. The seller keeps their '
                    'history; the removal is logged.',
                confirmLabel: 'Remove',
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              try {
                await AppServices.instance.admin.removeListing(listing.id);
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

// ---------------------------------------------------------------- categories

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  int _revision = 0;
  late Future<List<Map<String, dynamic>>> _categories = AppServices
      .instance
      .admin
      .marketplaceCategories();

  void _reload() => setState(() {
    _categories = AppServices.instance.admin.marketplaceCategories();
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
                  'Categories',
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
                  final name = await showDialog<String>(
                    context: context,
                    builder: (_) => const _CategoryDialog(),
                  );
                  if (name == null || name.trim().isEmpty) return;
                  try {
                    await AppServices.instance.admin.createCategory(
                      name: name.trim(),
                    );
                    if (context.mounted) {
                      showMessage(context, 'Category added.');
                    }
                    _reload();
                  } catch (e) {
                    if (context.mounted) {
                      showMessage(context, '$e', error: true);
                    }
                  }
                },
                icon: const AppIcon(Icons2.add, size: IconSize.inline),
                label: const Text('Add category'),
                style: TextButton.styleFrom(foregroundColor: Tokens.accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey(_revision),
            future: _categories,
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
              final items = snapshot.data ?? <Map<String, dynamic>>[];
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons2.marketplace,
                  title: 'No categories',
                  message: 'Add the categories sellers choose from.',
                );
              }
              return ListView(
                padding: EdgeInsets.only(bottom: Tokens.space8),
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
                      child: ListRow(
                        title: asString(items[i]['name'], fallback: 'Category'),
                        icon: Icons2.marketplace,
                        dense: true,
                        showChevron: false,
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: AppIcon(
                            Icons2.delete,
                            size: IconSize.row,
                            color: Tokens.inkFaint,
                          ),
                          onPressed: () async {
                            final id = asString(items[i]['id']);
                            if (id.isEmpty) return;
                            final ok = await confirmDialog(
                              context,
                              title: 'Delete this category?',
                              message:
                                  'Listings keep their category until re-categorised.',
                              confirmLabel: 'Delete',
                              destructive: true,
                            );
                            if (!ok || !context.mounted) return;
                            try {
                              await AppServices.instance.admin.deleteCategory(
                                id,
                              );
                              if (context.mounted) {
                                showMessage(context, 'Category removed.');
                              }
                              _reload();
                            } catch (e) {
                              if (context.mounted) {
                                showMessage(context, '$e', error: true);
                              }
                            }
                          },
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

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: const Text('New category'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Furniture',
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
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- reports

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
          child: FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('$_status-$_revision'),
            future: admin.listingReports(
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
                  message: 'Nothing to review. That is the good state.',
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
      padding: EdgeInsets.all(Tokens.space3),
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
          SizedBox(height: Tokens.space2),
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
                      await AppServices.instance.admin.resolveListingReport(
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
                      await AppServices.instance.admin.resolveListingReport(
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
