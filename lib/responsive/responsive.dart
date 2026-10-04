import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/widgets.dart';

/// Adaptive layout primitives for phones, tablets, laptops, desktops and TVs.
///
/// Breakpoints:
/// - compact  < 600   : phones
/// - medium   600-1100: tablets / iPads
/// - expanded 1100-1600: laptops / desktops
/// - wide     > 1600  : large monitors / TVs

enum ResponsiveBreakpoint { compact, medium, expanded, wide }

ResponsiveBreakpoint breakpointFor(double width) {
  if (width < 600) return ResponsiveBreakpoint.compact;
  if (width < 1100) return ResponsiveBreakpoint.medium;
  if (width < 1600) return ResponsiveBreakpoint.expanded;
  return ResponsiveBreakpoint.wide;
}

extension ResponsiveContext on BuildContext {
  ResponsiveBreakpoint get breakpoint =>
      breakpointFor(MediaQuery.sizeOf(this).width);

  bool get isCompact => breakpoint == ResponsiveBreakpoint.compact;
  bool get isMedium => breakpoint == ResponsiveBreakpoint.medium;
  bool get isExpanded => breakpoint == ResponsiveBreakpoint.expanded;
  bool get isWide => breakpoint == ResponsiveBreakpoint.wide;

  /// Phones.
  bool get isHandset => isCompact;

  /// Tablets / iPads.
  bool get isTablet => isMedium;

  /// Laptops, desktops, large monitors, TVs.
  bool get isDesktop => isExpanded || isWide;
}

/// Picks a value per breakpoint with graceful fallback to smaller sizes.
class ResponsiveValue<T> {
  final T compact;
  final T? medium;
  final T? expanded;
  final T? wide;

  const ResponsiveValue({
    required this.compact,
    this.medium,
    this.expanded,
    this.wide,
  });

  T of(BuildContext context) {
    switch (context.breakpoint) {
      case ResponsiveBreakpoint.compact:
        return compact;
      case ResponsiveBreakpoint.medium:
        return medium ?? compact;
      case ResponsiveBreakpoint.expanded:
        return expanded ?? medium ?? compact;
      case ResponsiveBreakpoint.wide:
        return wide ?? expanded ?? medium ?? compact;
    }
  }
}

/// Constrains content to a max width and centers it, so pages don't stretch
/// edge-to-edge on laptops, desktops and TVs.
class MaxWidthBox extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const MaxWidthBox({super.key, required this.child, this.maxWidth = 1200});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class NavDestinationItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final String? badgeLabel;

  const NavDestinationItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.badgeLabel,
  });
}

class NavSection {
  final String title;
  final List<NavDestinationItem> items;

  const NavSection(this.title, this.items);
}

class _FlatDest {
  final String? section;
  final NavDestinationItem dest;

  const _FlatDest(this.section, this.dest);
}

/// Adaptive app shell:
/// - compact  : bottom NavigationBar
/// - medium   : NavigationRail
/// - expanded/wide : permanent NavigationDrawer
class ResponsiveScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavSection> sections;
  final List<Widget> pages;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final Widget? drawerHeader;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Optional widget rendered at the top of the permanent side drawer, below
  /// the header (e.g. the patient quick-actions grid). Ignored on phones.
  final Widget? drawerLeading;

  const ResponsiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.sections,
    required this.pages,
    this.floatingActionButton,
    this.appBar,
    this.drawerHeader,
    this.floatingActionButtonLocation,
    this.drawerLeading,
  });

  List<_FlatDest> get _flat => [
        for (final s in sections)
          for (final d in s.items) _FlatDest(s.title, d),
      ];

  Widget _badge(NavDestinationItem d, IconData icon) {
    if (d.badgeLabel == null || d.badgeLabel!.isEmpty) {
      return Icon(icon);
    }
    return Badge(label: Text(d.badgeLabel!), child: Icon(icon));
  }

  @override
  Widget build(BuildContext context) {
    final flat = _flat;
    assert(pages.length == flat.length,
        'ResponsiveScaffold: pages (${pages.length}) must match destinations (${flat.length})');
    final scheme = Theme.of(context).colorScheme;
    // Promoted local so the nullable header needs no `!` below.
    final header = drawerHeader;

    if (context.isCompact) {
      return Scaffold(
        appBar: appBar,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: IndexedStack(
            key: ValueKey<int>(selectedIndex),
            index: selectedIndex,
            children: pages,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          indicatorColor: scheme.primary.withValues(alpha: 0.14),
          destinations: [
            for (final f in flat)
              NavigationDestination(
                icon: _badge(f.dest, f.dest.icon),
                selectedIcon:
                    _badge(f.dest, f.dest.selectedIcon ?? f.dest.icon),
                label: f.dest.label,
              ),
          ],
        ),
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = dark ? RemedooTheme.darkCard : RemedooTheme.sidebarLight;

    if (context.isMedium) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            // Scrollable rail: destination lists (e.g. admin) can exceed
            // the viewport height; NavigationRail itself never scrolls.
            SingleChildScrollView(
              child: IntrinsicHeight(
                child: NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -1,
                  backgroundColor: sidebarBg,
                  selectedIconTheme:
                      IconThemeData(color: scheme.primary),
                  unselectedIconTheme: IconThemeData(
                      color: scheme.onSurfaceVariant
                          .withValues(alpha: 0.6)),
                  selectedLabelTextStyle: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                  unselectedLabelTextStyle: TextStyle(
                      color: scheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                  indicatorColor:
                      scheme.primary.withValues(alpha: 0.12),
                  indicatorShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  destinations: [
                    for (final f in flat)
                      NavigationRailDestination(
                        icon: _badge(f.dest, f.dest.icon),
                        selectedIcon: _badge(
                            f.dest, f.dest.selectedIcon ?? f.dest.icon),
                        label: Text(f.dest.label),
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: IndexedStack(
                  key: ValueKey<int>(selectedIndex),
                  index: selectedIndex,
                  children: pages,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
      );
    }

    // expanded / wide: permanent drawer, styled like the React sidebar —
    // optional leading widget (quick actions), tiny uppercase group labels,
    // and nav rows with the orange-tint active pill + left indicator bar.
    final leading = drawerLeading;
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          Container(
            key: const ValueKey('nav-drawer'),
            width: 288,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.05),
            ),
            child: Column(
              children: [
                header ?? const SizedBox.shrink(),
                if (leading != null) ...[
                  const SizedBox(height: 12),
                  leading,
                ],
                // Scrollable nav: quick actions + long destination lists
                // must never overflow a short viewport.
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(8, 16, 8, 20),
                    children: [
                      for (var i = 0; i < flat.length; i++) ...[
                        if (i == 0 ||
                            flat[i].section !=
                                flat[i - 1].section) ...[
                          if ((flat[i].section ?? '').isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                  top: i == 0 ? 0 : 16),
                              child: RSidebarGroupLabel(
                                  flat[i].section!.toUpperCase()),
                            ),
                        ],
                        RSidebarNavTile(
                          icon: i == selectedIndex
                              ? (flat[i].dest.selectedIcon ??
                                  flat[i].dest.icon)
                              : flat[i].dest.icon,
                          label: flat[i].dest.label,
                          active: i == selectedIndex,
                          badgeLabel: flat[i].dest.badgeLabel,
                          onTap: () => onDestinationSelected(i),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: IndexedStack(
                key: ValueKey<int>(selectedIndex),
                index: selectedIndex,
                children: pages,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

/// Grid whose column count adapts to the available width.
class ResponsiveGrid extends StatelessWidget {
  final int compactCols;
  final int mediumCols;
  final int expandedCols;
  final int wideCols;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    super.key,
    this.compactCols = 2,
    this.mediumCols = 3,
    this.expandedCols = 4,
    this.wideCols = 6,
    required this.itemCount,
    required this.itemBuilder,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = 1,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
    this.physics,
  });

  int colsOf(BuildContext context) => ResponsiveValue<int>(
        compact: compactCols,
        medium: mediumCols,
        expanded: expandedCols,
        wide: wideCols,
      ).of(context);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: colsOf(context),
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Sliver variant of [ResponsiveGrid] for use inside CustomScrollView.
class ResponsiveSliverGrid extends StatelessWidget {
  final int compactCols;
  final int mediumCols;
  final int expandedCols;
  final int wideCols;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  const ResponsiveSliverGrid({
    super.key,
    this.compactCols = 2,
    this.mediumCols = 3,
    this.expandedCols = 4,
    this.wideCols = 6,
    required this.itemCount,
    required this.itemBuilder,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cols = ResponsiveValue<int>(
      compact: compactCols,
      medium: mediumCols,
      expanded: expandedCols,
      wide: wideCols,
    ).of(context);
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(itemBuilder,
          childCount: itemCount),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
    );
  }
}

/// Detail pages: single column on phones, two columns (content + side panel)
/// on tablets and larger. Place inside a scroll view.
class DetailSplit extends StatelessWidget {
  final Widget main;
  final Widget side;
  final double sideWidth;

  const DetailSplit({
    super.key,
    required this.main,
    required this.side,
    this.sideWidth = 360,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [main, const SizedBox(height: 20), side],
      );
    }
    return MaxWidthBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: main),
            const SizedBox(width: 24),
            SizedBox(width: sideWidth, child: side),
          ],
        ),
      ),
    );
  }
}

/// Size-responsive dialog: modal bottom sheet on phones,
/// centered dialog on tablets/desktops.
Future<T?> showResponsiveDialog<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool dismissible = true,
}) {
  if (context.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => SafeArea(child: builder(c)),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    builder: builder,
  );
}

/// TV / D-pad friendly wrapper: visible focus ring + slight scale when focused.
/// Wrap key cards and buttons in lists that TV users navigate with a D-pad.
class FocusableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool autofocus;

  const FocusableScale({
    super.key,
    required this.child,
    this.onTap,
    this.autofocus = false,
  });

  @override
  State<FocusableScale> createState() => _FocusableScaleState();
}

class _FocusableScaleState extends State<FocusableScale> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.035 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _focused ? scheme.primary : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Large touch target button, comfortable for TV remotes and tablets.
class BigTargetButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const BigTargetButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          minimumSize: const Size(64, 56),
        ),
        child: child,
      ),
    );
  }
}
