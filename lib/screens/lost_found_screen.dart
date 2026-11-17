import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import 'widgets/paged_list.dart';

/// Lost and found.
///
/// Read-only for residents: the guard desk and the office log what comes in, and
/// a resident claiming an item does it in person. The screen answers "has my
/// thing been handed in?" — that is the whole job, so it stays a list with a
/// filter and no compose button.
class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  String? _kind;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.space3),
          child: Row(
            children: [
              _Filter(
                label: 'All',
                selected: _kind == null,
                onTap: () => setState(() => _kind = null),
              ),
              const SizedBox(width: Tokens.space2),
              _Filter(
                label: 'Lost',
                selected: _kind == 'LOST',
                onTap: () => setState(() => _kind = 'LOST'),
              ),
              const SizedBox(width: Tokens.space2),
              _Filter(
                label: 'Found',
                selected: _kind == 'FOUND',
                onTap: () => setState(() => _kind = 'FOUND'),
              ),
            ],
          ),
        ),
        Expanded(
          child: PagedList<LostFoundItem>(
            key: ValueKey(_kind),
            fetch: (page) async {
              final all = await AppServices.instance.resident.lostAndFound(
                page: page,
                limit: 50,
              );
              // Filtered in-app: the backend list is short enough that a
              // client-side filter is exact, and it saves a round trip per tap.
              return PageResult(
                items: _kind == null
                    ? all.items
                    : all.items
                          .where((i) => i.kind.toUpperCase() == _kind)
                          .toList(growable: false),
                page: all.page,
                limit: all.limit,
                total: all.total,
                totalPages: all.totalPages,
              );
            },
            emptyTitle: 'Nothing logged',
            emptyMessage:
                'Items handed in at the gate and things reported '
                'missing appear here.',
            emptyIcon: Icons2.lostFound,
            itemBuilder: (context, item, _) {
              return ListRow(
                title: item.title,
                subtitle: [
                  item.kind,
                  if (item.location != null) item.location!,
                  if (item.createdAt != null) Fmt.relative(item.createdAt),
                ].join(' · '),
                icon: Icons2.lostFound,
                trailing: StatusBadge.forStatus(item.status),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
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
