import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trackit/pages/home_screen.dart';
import 'package:trackit/pages/wallet_screen.dart';
import 'package:trackit/pages/analytics_screen.dart';
import 'package:trackit/pages/workouts_screen.dart';
import 'package:trackit/theme/app_colors.dart';
import 'package:trackit/theme/app_text_styles.dart';
import 'package:trackit/theme/responsive.dart';
import 'package:trackit/widgets/brand_mark.dart';

/// App shell: bottom navigation on phones, a side rail on wider windows
/// (collapsed on tablets, with labels on desktop).
class Layout extends StatefulWidget {
  const Layout({super.key});

  @override
  State<Layout> createState() => _LayoutState();
}

class _LayoutState extends State<Layout> {
  int _currentIndex = 0;

  late List<Widget> _pages;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      'Wallet',
    ),
    (Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'Workout'),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Stats'),
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(onTabChange: _select),
      const WalletScreen(),
      const WorkoutsScreen(),
      const AnalyticsScreen(),
    ];
  }

  void _select(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = WindowSize.of(context);

    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.maxContentWidth(context),
        ),
        child: _pageSwitcher(),
      ),
    );

    if (size.usesBottomNav) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          _SideNav(
            items: _items,
            selectedIndex: _currentIndex,
            extended: size == WindowSize.expanded,
            onSelect: _select,
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _pageSwitcher() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: KeyedSubtree(
        key: ValueKey(_currentIndex),
        child: _pages[_currentIndex],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isDark = AppColors.isDark;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(child: _buildNavItem(i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final (icon, activeIcon, label) = _items[index];
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textTertiary;
    return GestureDetector(
      onTap: () => _select(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                isSelected ? activeIcon : icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical navigation for tablets and desktop. [extended] shows labels.
class _SideNav extends StatelessWidget {
  final List<(IconData, IconData, String)> items;
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelect;

  const _SideNav({
    required this.items,
    required this.selectedIndex,
    required this.extended,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: extended ? 232 : 84,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: Column(
            crossAxisAlignment: extended
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(left: extended ? 6 : 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandMark(size: 36),
                    if (extended) ...[
                      const SizedBox(width: 10),
                      const Text('TrackIt', style: AppTextStyles.h3),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _SideNavItem(
                    item: items[i],
                    selected: i == selectedIndex,
                    extended: extended,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideNavItem extends StatefulWidget {
  final (IconData, IconData, String) item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final (icon, activeIcon, label) = widget.item;
    final selected = widget.selected;
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final background = selected
        ? AppColors.primary.withValues(alpha: 0.12)
        : _hovered
        ? AppColors.surfaceVariant
        : Colors.transparent;

    final tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: widget.extended ? double.infinity : 56,
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: widget.extended ? 14 : 0),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: widget.extended
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(selected ? activeIcon : icon, color: color),
              ),
              if (widget.extended) ...[
                const SizedBox(width: 14),
                Text(
                  label,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return widget.extended ? tile : Tooltip(message: label, child: tile);
  }
}
