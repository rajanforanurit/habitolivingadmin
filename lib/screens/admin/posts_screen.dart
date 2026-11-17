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

/// Community posts, every status, moderation view.
///
/// Residents see only the published feed. An admin sees what was removed or
/// held back — which is the whole point of this screen. Removing requires a
/// reason because the author is told why, and because the audit trail should
/// never contain a bare "removed".
class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  String _status = 'PUBLISHED';

  static const _filters = <(String, String)>[
    ('PUBLISHED', 'Published'),
    ('REMOVED', 'Removed'),
    ('REPORTED', 'Reported'),
    ('', 'All'),
  ];

  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final admin = AppServices.instance.admin;
    return AppScaffold(
      title: 'Community posts',
      subtitle: 'Moderation view — all statuses',
      body: Column(
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
            child: _PostList(
              key: ValueKey('$_status-$_revision'),
              fetch: (page) => admin.communityPosts(
                page: page,
                limit: 20,
                status: _status.isEmpty ? null : _status,
              ),
              onChanged: () => setState(() => _revision++),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostList extends StatefulWidget {
  const _PostList({super.key, required this.fetch, required this.onChanged});

  final Future<PageResult<Post>> Function(int page) fetch;
  final VoidCallback onChanged;

  @override
  State<_PostList> createState() => _PostListState();
}

class _PostListState extends State<_PostList> {
  final _scroll = ScrollController();
  final List<Post> _items = [];
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
        icon: Icons2.community,
        title: 'Nothing here',
        message: 'No posts with this status.',
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
                child: _PostCard(post: _items[i], onChanged: widget.onChanged),
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

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onChanged});

  final Post post;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final removed = post.status.toUpperCase() == 'REMOVED';
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
          Row(
            children: [
              InitialsAvatar(name: post.authorName, size: 36),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        fontWeight: FontWeight.w600,
                        color: Tokens.ink,
                      ),
                    ),
                    Text(
                      [
                        if (post.createdAt != null)
                          Fmt.relative(post.createdAt),
                        '${post.likeCount} likes',
                        '${post.commentCount} comments',
                      ].join(' · '),
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeXs,
                        color: Tokens.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.forStatus(
                post.status,
                domain: StatusDomain.generic,
                dot: false,
              ),
            ],
          ),
          if (post.title.trim().isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                fontWeight: FontWeight.w600,
                color: Tokens.ink,
              ),
            ),
          ],
          if (post.body.trim().isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              post.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                height: 1.4,
                color: Tokens.inkMuted,
              ),
            ),
          ],
          SizedBox(height: 8),
          Row(
            children: [
              if (!removed)
                _Action(
                  label: 'Remove post',
                  icon: Icons2.delete,
                  destructive: true,
                  onTap: () => _remove(context),
                )
              else
                Text(
                  'Removed by moderation',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeXs,
                    fontStyle: FontStyle.italic,
                    color: Tokens.inkFaint,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ReasonDialog(),
    );
    if (reason == null || !context.mounted) return;
    try {
      await AppServices.instance.admin.removePost(post.id, reason: reason);
      if (context.mounted) showMessage(context, 'Post removed.');
      onChanged();
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
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
      title: const Text('Why is this post going?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 2,
        decoration: const InputDecoration(
          hintText: 'The author is shown this reason',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
          child: const Text('Remove'),
        ),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: destructive ? Tokens.dangerTint : Tokens.accentTint,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: IconSize.inline, color: fg),
              const SizedBox(width: 4),
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
