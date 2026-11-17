import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens.dart';

/// Loading, empty and error states for a screen or a list.
///
/// Each screen has exactly one of these. The rule is that a list never shows a
/// spinner in the middle of content: it shows skeleton rows while loading, a
/// real empty state when there is nothing, and an error panel with a retry when
/// the call failed.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.compact = false,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Tokens.gutter,
          vertical: compact ? Tokens.space5 : Tokens.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
              ),
              child: AppIcon(icon ?? Icons2.empty, size: 22),
            ),
            SizedBox(height: Tokens.space4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeMd,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Tokens.ink,
              ),
            ),
            if (message != null) ...[
              SizedBox(height: Tokens.space2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  height: 1.5,
                  color: Tokens.inkMuted,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Tokens.space5),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A failed request. Shows the server message when there is one and a retry
/// action, never a bare "something went wrong".
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
    this.title = 'Could not load',
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Tokens.gutter,
          vertical: compact ? Tokens.space5 : Tokens.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Tokens.dangerTint,
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
              ),
              child: AppIcon(Icons2.error, size: 22, color: Tokens.danger),
            ),
            SizedBox(height: Tokens.space4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeMd,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Tokens.ink,
              ),
            ),
            SizedBox(height: Tokens.space2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                height: 1.5,
                color: Tokens.inkMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Tokens.space5),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder rows used while a list is loading.
///
/// A pulsing bar is a placeholder, not a spinner: it shows the shape of the
/// content that is coming.
class LoadingList extends StatefulWidget {
  const LoadingList({
    super.key,
    this.rows = 5,
    this.itemHeight = Tokens.rowHeight,
  });

  final int rows;
  final double itemHeight;

  @override
  State<LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<LoadingList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = 0.45 + (_controller.value * 0.35);
        return Column(
          children: [
            for (var i = 0; i < widget.rows; i++)
              SizedBox(
                height: widget.itemHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space4,
                    vertical: Tokens.space3,
                  ),
                  child: Row(
                    children: [
                      _bar(36, 36, t, radius: Tokens.radiusSm),
                      const SizedBox(width: Tokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bar(double.infinity, 10, t),
                            const SizedBox(height: Tokens.space2),
                            _bar(120, 8, t),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _bar(
    double width,
    double height,
    double opacity, {
    double radius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Tokens.ink.withValues(alpha: 0.06 * opacity * 2),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A centred spinner for a full-screen wait (app start, auth).
class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          if (label != null) ...[
            SizedBox(height: Tokens.space3),
            Text(
              label!,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                color: Tokens.inkFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
