import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'design_tokens.dart';

/// A frosted-glass navigation rail with an animated "liquid" capsule
/// indicator around the active item — the Flutter equivalent of the
/// `liquid-glass-navbar` component.
class LiquidSidebar extends StatefulWidget {
  const LiquidSidebar({
    super.key,
    this.width = 220,
    this.borderRadius = 18,
    this.sections = const [],
    this.footer = const [],
    this.title,
    this.logo,
  });

  final double width;
  final double borderRadius;
  final List<LiquidSidebarSection> sections;
  final List<LiquidSidebarItem> footer;
  final Widget? title;
  final Widget? logo;

  @override
  State<LiquidSidebar> createState() => _LiquidSidebarState();
}

class LiquidSidebarSection {
  LiquidSidebarSection({required this.label, required this.items});

  final String label;
  final List<LiquidSidebarItem> items;
}

class LiquidSidebarItem {
  LiquidSidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final int? badge;
}

class _LiquidSidebarState extends State<LiquidSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _fromY = 0;
  double _toY = 0;
  int? _activeIndex;
  String? _currentRoute;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Inherited route info (GoRouterState) is NOT available during initState,
    // so we never call GoRouterState.of(context) here. The initial active
    // item is resolved in didChangeDependencies, which runs after initState
    // and before the first build, once the GoRouter inherited widget is
    // attached.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dependencies (and therefore GoRouterState) are guaranteed ready here,
    // and this is called again on every route change, so the active item
    // stays in sync without any external notifier.
    final route = GoRouterState.of(context).matchedLocation;
    if (route != _currentRoute) {
      _currentRoute = route;
      _updateActiveFromRoute();
    }
  }

  void _updateActiveFromRoute() {
    final route = GoRouterState.of(context).matchedLocation;
    int index = 0;
    int? foundIndex;
    for (final section in widget.sections) {
      for (final item in section.items) {
        if (item.route == route) {
          foundIndex = index;
        }
        index++;
      }
    }
    if (foundIndex == null || foundIndex == _activeIndex) return;

    _activeIndex = foundIndex;
    // Marking the active index is safe here: this runs either from
    // didChangeDependencies (first build, after super) or from a post-frame
    // callback. Both are valid points to schedule a rebuild.
    if (mounted) setState(() {});

    // The capsule animation needs the item's render box to exist, which is not
    // true during the first build (the ListView has not laid out yet). Defer
    // it to the next frame so we never index into an empty _itemKeys list.
    _scheduleAnimation(foundIndex);
  }

  void _scheduleAnimation(int index) {
    if (!_controller.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateToItem(index);
      });
    }
  }

  void _animateToItem(int index) {
    final context = this.context;
    if (!context.mounted) return;
    // Guard against the keys not being populated yet (first layout) or the
    // index being out of range.
    if (index < 0 || index >= _itemKeys.length) return;
    final key = _itemKeys[index];
    final itemBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (itemBox == null) return;

    // Find the Stack's render box by walking up from the item.
    // We use the item's global position and subtract the Stack's global origin
    // so the capsule's `top` is in Stack-local coordinates.
    //
    // We locate the Stack by looking at the Expanded child of this Column.
    // The simplest reliable approach: get the item's global Y, then subtract
    // the global Y of the first item in the list to work in list-local space,
    // and add the list's padding offset.
    final itemGlobalPos = itemBox.localToGlobal(Offset.zero);

    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final itemLocalToStack = stackBox.globalToLocal(itemGlobalPos);

    // Store current animated Y before changing targets (for smooth chaining)
    final currentT = Curves.easeOutCubic.transform(_controller.value);
    _fromY = _fromY + (_toY - _fromY) * currentT;
    if (_fromY < 0) {
      // First time: snap directly to target with no animation from 0
      _fromY = itemLocalToStack.dy;
    }
    _toY = itemLocalToStack.dy;
    _controller.forward(from: 0);
    setState(() {});
  }

  final List<GlobalKey> _itemKeys = [];
  final GlobalKey _stackKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    _itemKeys.clear();
    int flatIndex = 0;
    final allItems = <_FlatItem>[];

    for (final section in widget.sections) {
      allItems.add(_FlatItem(isHeader: true, headerLabel: section.label));
      for (final item in section.items) {
        allItems.add(_FlatItem(isHeader: false, item: item, index: flatIndex));
        _itemKeys.add(GlobalKey());
        flatIndex++;
      }
    }

    for (final item in widget.footer) {
      allItems.add(_FlatItem(isHeader: false, item: item, index: flatIndex));
      _itemKeys.add(GlobalKey());
      flatIndex++;
    }

    final children = <Widget>[];

    if (widget.logo != null || widget.title != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              if (widget.logo != null) widget.logo!,
              if (widget.logo != null && widget.title != null)
                const SizedBox(width: 10),
              if (widget.title != null) widget.title!,
            ],
          ),
        ),
      );
      children.add(const SizedBox(height: 4));
    }

    // List + animated indicator overlay (Stack only around the list area)
    children.add(
      Expanded(
        child: Stack(
          key: _stackKey,
          children: [
            // The liquid indicator (animated capsule)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_controller.value);
                final y = _fromY + (_toY - _fromY) * t;
                // Don't render the capsule until we have a valid position
                if (_fromY < 0) return const SizedBox.shrink();
                return Positioned(
                  left: 8,
                  right: 8,
                  top: y,
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: DesignTokens.accentGradient,
                      boxShadow: const [
                        BoxShadow(
                          color: DesignTokens.accentCyanGlow,
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Scrollable navigation list
            ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: allItems.length,
              itemBuilder: (context, i) {
                final flat = allItems[i];
                if (flat.isHeader) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                    child: Text(
                      flat.headerLabel!,
                      style: textTheme.labelSmall?.copyWith(
                        color: DesignTokens.textTertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  );
                }
                return _LiquidSidebarItemTile(
                  key: _itemKeys[flat.index!],
                  item: flat.item!,
                  isActive: _activeIndex == flat.index,
                  onTap: () {
                    context.go(flat.item!.route);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );

    return Container(
      width: widget.width,
      decoration: const BoxDecoration(
        color: DesignTokens.bgDeep,
        border: Border(
          right: BorderSide(color: DesignTokens.glassBorder, width: 1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(widget.borderRadius),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _FlatItem {
  _FlatItem({this.isHeader = false, this.headerLabel, this.item, this.index});

  final bool isHeader;
  final String? headerLabel;
  final LiquidSidebarItem? item;
  final int? index;
}

class _LiquidSidebarItemTile extends StatelessWidget {
  const _LiquidSidebarItemTile({
    super.key,
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final LiquidSidebarItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // The glass pane handles the active highlight via stack order
          ),
          child: Row(
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                size: 20,
                color: isActive
                    ? DesignTokens.accentCyan
                    : DesignTokens.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isActive
                        ? DesignTokens.textPrimary
                        : DesignTokens.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
              if (item.badge != null && item.badge! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: DesignTokens.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.badge}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
