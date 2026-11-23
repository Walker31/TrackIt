import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trackit/providers/app_providers.dart';
import 'package:trackit/widgets/app_shortcuts.dart';
import 'package:trackit/widgets/wallet/expense_flows.dart';
import 'package:trackit/pages/home_screen.dart';
import 'package:trackit/pages/wallet_screen.dart';
import 'package:trackit/pages/analytics_screen.dart';
import 'package:trackit/pages/workouts_screen.dart';
import 'package:trackit/theme/app_colors.dart';
import 'package:trackit/theme/app_text_styles.dart';
import 'package:trackit/theme/responsive.dart';
import 'package:trackit/widgets/brand_mark.dart';
import 'package:trackit/widgets/sync_status.dart';
import 'dart:async';
import 'package:trackit/services/launch_requests.dart';
import 'package:trackit/services/notification_service.dart';
import 'package:trackit/utils/sms_parser.dart';
import 'package:trackit/widgets/app_snackbar.dart';

/// The main tabs, each with its own address so the browser's back button,
/// refresh and bookmarks land on the right one.
enum AppTab {
  home('/home', 'Today'),
  wallet('/wallet', 'Wallet'),
  workout('/workout', 'Workout'),
  stats('/stats', 'Stats');

  const AppTab(this.path, this.title);
  final String path;

  /// Shown in the browser tab / app switcher.
  final String title;
}

/// App shell: bottom navigation on phones, a side rail on wider windows
/// (collapsed on tablets, with labels on desktop).
class Layout extends StatefulWidget {
  final AppTab tab;

  const Layout({super.key, this.tab = AppTab.home});

  @override
  State<Layout> createState() => _LayoutState();
}

class _LayoutState extends State<Layout> with SingleTickerProviderStateMixin {
  late int _currentIndex = widget.tab.index;

  late final List<Widget> _pages;

  /// Tabs opened so far. A tab is built on its first visit and then kept
  /// alive, so its scroll position and in-progress state survive switching.
  late final Set<int> _visited = {_currentIndex};

  /// Keeps the tab pages' state when a window resize swaps the bottom bar
  /// for the side rail and the pages move to a different spot in the tree.
  final _pagesKey = GlobalKey();

  /// Fades and lifts the newly selected tab in.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final Animation<double> _enterCurve = CurvedAnimation(
    parent: _enter,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _enterOffset = Tween<Offset>(
    begin: const Offset(0, 0.015),
    end: Offset.zero,
  ).animate(_enterCurve);

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

  StreamSubscription<LaunchRequest>? _launchSub;

  /// Widget buttons and shared SMS (Android), at start-up and while open.
  StreamSubscription<String>? _notificationSub;

  Future<void> _listenForLaunchRequests() async {
    _launchSub = LaunchRequests.stream.listen(_handle);
    _notificationSub = NotificationService().taps.listen(_handlePayload);
    final first = await LaunchRequests.takeInitial();
    if (first != null && mounted) _handle(first);
    final tapped = NotificationService().takeLaunchPayload();
    if (tapped != null && mounted) _handlePayload(tapped);
  }

  /// A tapped notification: nudges open "add expense".
  void _handlePayload(String payload) {
    if (!mounted) return;
    if (payload == 'add_expense') _handle(const AddExpenseRequest());
  }

  void _handle(LaunchRequest request) {
    final expenses = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(expenseProviderProvider);
    switch (request) {
      case AddExpenseRequest():
        context.go(AppTab.home.path);
        openAddExpense(context, expenses);
      case OpenWorkoutRequest():
        context.go(AppTab.workout.path);
      case SharedTextRequest(:final text):
        final sms = parseBankSms(text);
        context.go(AppTab.home.path);
        if (sms == null) {
          AppSnackbar.info(
            context,
            "That text doesn't look like a payment message. Add it by hand.",
          );
          openAddExpense(context, expenses);
        } else {
          openAddExpense(context, expenses, prefill: sms);
        }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _listenForLaunchRequests(),
    );
    _pages = [
      HomeScreen(onTabChange: _select),
      const WalletScreen(),
      const WorkoutsScreen(),
      const AnalyticsScreen(),
    ];
  }

  @override
  void dispose() {
    _launchSub?.cancel();
    _notificationSub?.cancel();
    _enter.dispose();
    super.dispose();
  }

  /// Tab taps go through the router; the new route rebuilds this shell
  /// with the new [Layout.tab] (see [didUpdateWidget]).
  void _select(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    context.go(AppTab.values[index].path);
  }

  @override
  void didUpdateWidget(Layout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.tab.index;
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
    _enter.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);

    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.maxContentWidth(context),
        ),
        child: _pageSwitcher(),
      ),
    );

    return Title(
      title: '${widget.tab.title} · TrackIt',
      color: AppColors.primary,
      child: AppShortcuts(
        onTab: _select,
        onNewExpense: () => openAddExpense(
          context,
          ProviderScope.containerOf(context).read(expenseProviderProvider),
        ),
        child: size.usesBottomNav ? _phoneShell(content) : _railShell(content),
      ),
    );
  }

  Widget _phoneShell(Widget content) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar()),
      ],
    ),
  );

  Widget _railShell(Widget content) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: Row(
      children: [
        _SideNav(
          items: _items,
          selectedIndex: _currentIndex,
          extended: WindowSize.of(context) == WindowSize.expanded,
          onSelect: _select,
        ),
        Expanded(child: content),
      ],
    ),
  );

  Widget _pageSwitcher() {
    return KeyedSubtree(
      key: _pagesKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < _pages.length; i++)
            // Same widget structure whether a tab is showing or not, so
            // switching never rebuilds a tab from scratch.
            Offstage(
              offstage: i != _currentIndex,
              child: TickerMode(
                enabled: i == _currentIndex,
                child: FadeTransition(
                  opacity: i == _currentIndex
                      ? _enterCurve
                      : kAlwaysCompleteAnimation,
                  child: SlideTransition(
                    position: i == _currentIndex
                        ? _enterOffset
                        : const AlwaysStoppedAnimation(Offset.zero),
                    child: _visited.contains(i)
                        ? _pages[i]
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ],
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
    return InkWell(
      onTap: () => _select(index),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
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
              const Spacer(),
              // Status and settings live at the foot of the rail on wide
              // windows, where page headers leave them out.
              SyncStatusIndicator(expanded: extended),
              const SizedBox(height: 6),
              _SideNavItem(
                item: const (
                  Icons.settings_outlined,
                  Icons.settings,
                  'Settings',
                ),
                selected: false,
                extended: extended,
                onTap: () => context.push('/settings'),
              ),
              if (extended)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _SideNavItem(
                    item: const (
                      Icons.keyboard_outlined,
                      Icons.keyboard,
                      'Shortcuts',
                    ),
                    selected: false,
                    extended: extended,
                    onTap: () => showShortcutHelp(context),
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
