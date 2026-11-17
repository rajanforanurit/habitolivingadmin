import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens.dart';

/// A navigation destination for [RoleShell].
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The bottom navigation bar used by every role shell.
///
/// Design notes:
/// - Five destinations maximum. A sixth item would make the targets narrower
///   than the 44pt minimum, so the app adds a "More" tab instead.
/// - The active item is a filled icon in the accent colour with a small dot
///   underneath; inactive items are outline icons in muted ink. Colour is not
///   the only signal, which keeps the bar readable for colour-blind users.
/// - The bar sits on the surface colour with a hairline above it, not a drop
///   shadow, so it does not look like a floating Material card.
class RoleShell extends StatelessWidget {
  const RoleShell({
    super.key,
    required this.destinations,
    required this.index,
    required this.onSelected,
    required this.child,
  });

  final List<NavDestination> destinations;
  final int index;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.background,
      body: child,
      bottomNavigationBar: _Bar(
        destinations: destinations,
        index: index,
        onSelected: onSelected,
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.destinations,
    required this.index,
    required this.onSelected,
  });

  final List<NavDestination> destinations;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tokens.surface,
        border: Border(top: BorderSide(color: Tokens.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _Item(
                    destination: destinations[i],
                    selected: i == index,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Tokens.accent : Tokens.inkFaint;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              selected ? destination.activeIcon : destination.icon,
              size: IconSize.nav,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: 10.5,
                height: 1.1,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: selected ? Tokens.accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
