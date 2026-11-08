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
  double _targetY = 0;
  final double _currentY = 0;
  int? _activeIndex;
  String? _currentRoute;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _updateActiveFromRoute();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    if (foundIndex != null && foundIndex != _activeIndex) {
      setState(() => _activeIndex = foundIndex);
      _animateToItem(foundIndex);
    }
  }

  void _animateToItem(int index) {
    final context = this.context;
    if (!context.mounted) return;
    final key = _itemKeys[index];
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero);
      setState(() => _targetY = pos.dy);
      _controller.forward(from: 0);
    }
  }

  final List<GlobalKey> _itemKeys = [];

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

    // The liquid indicator (animated capsule)
    children.add(
      AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          final y = _currentY + (_targetY - _currentY) * t;
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
    );

    children.add(
      Expanded(
        child: ListView.builder(
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
                setState(() => _activeIndex = flat.index);
                _animateToItem(flat.index!);
              },
            );
          },
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
        child: Stack(children: children),
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
