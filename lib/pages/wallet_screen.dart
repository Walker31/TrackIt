import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme/responsive.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/page_header.dart';
import '../widgets/section_header.dart';
import '../widgets/glass_container.dart';
import '../widgets/empty_state.dart';
import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../models/expenses.dart';
import '../widgets/wallet/financial_analysis_card.dart';
import '../widgets/wallet/transaction_list.dart';
import '../widgets/wallet/add_expense_sheet.dart';
import '../widgets/wallet/events_section.dart';
import '../widgets/wallet/trips_section.dart';
import '../widgets/wallet/budgets_card.dart';
import '../widgets/wallet/create_group_sheet.dart';
import '../widgets/animated/animated_segmented_tabs.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../utils/format.dart';

enum _WalletTab { personal, events, trips }

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  _WalletTab _tab = _WalletTab.personal;
  final ValueNotifier<int> _tripsRefresh = ValueNotifier(0);

  @override
  void dispose() {
    _tripsRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(expenseProviderProvider);
    final groupProvider = ref.watch(groupProviderProvider);
    // Splitting needs other people, so it needs an account and a server;
    // without one the app is personal-only.
    final signedIn =
        ref.watch(authProvider).state.status == AuthStatus.authenticated;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: PageHeader(title: 'Wallet')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                Responsive.pageBottomPadding(context, hasFab: true),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSegmentedTabs(
                    labels: const ["Personal", "Events", "Trips"],
                    selectedIndex: _tab.index,
                    onChanged: (index) =>
                        setState(() => _tab = _WalletTab.values[index]),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topLeft,
                      children: [...previous, ?current],
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _tab == _WalletTab.personal
                        ? ResponsiveColumns(
                            key: const ValueKey('personal'),
                            gap: 40,
                            left: [
                              SectionHeader(
                                title: "Spending",
                                action: _buildMonthSelector(provider),
                              ),
                              const SizedBox(height: 16),
                              FadeSlideIn(
                                child: FinancialAnalysisCard(
                                  provider: provider,
                                ),
                              ),
                              const SizedBox(height: 16),
                              BudgetsCard(provider: provider),
                            ],
                            right: [
                              const SectionHeader(title: "Transactions"),
                              const SizedBox(height: 8),
                              TransactionList(
                                provider: provider,
                                onEdit: _showEditExpenseSheet,
                              ),
                            ],
                          )
                        : _tab == _WalletTab.trips
                        ? TripsSection(
                            key: const ValueKey('trips'),
                            refresh: _tripsRefresh,
                            onCreate: _createTrip,
                          )
                        : signedIn
                        ? EventsSection(
                            key: const ValueKey('events'),
                            provider: groupProvider,
                            onCreate: () => _showCreateGroupSheet(context),
                          )
                        : EmptyState(
                            key: const ValueKey('events-signed-out'),
                            icon: Icons.groups_outlined,
                            title: 'Split costs with friends',
                            message:
                                'Sign in to create events, share expenses '
                                'and settle up. Your personal spending stays '
                                'on this phone either way.',
                            actionLabel: 'Sign in',
                            actionIcon: Icons.login_rounded,
                            onAction: () => context.push('/login'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: Responsive.navInset(context)),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _tab == _WalletTab.personal
              ? FloatingActionButton(
                  key: const ValueKey('add_expense'),
                  onPressed: () => _showAddExpenseSheet(context),
                  tooltip: 'Add expense',
                  child: const Icon(Icons.add),
                )
              : _tab == _WalletTab.trips
              ? FloatingActionButton(
                  key: const ValueKey('new_trip'),
                  onPressed: _createTrip,
                  tooltip: 'New trip',
                  child: const Icon(Icons.add),
                )
              : !signedIn
              ? const SizedBox.shrink(key: ValueKey('no_fab'))
              : FloatingActionButton(
                  key: const ValueKey('new_event'),
                  onPressed: () => _showCreateGroupSheet(context),
                  tooltip: 'New event',
                  child: const Icon(Icons.add),
                ),
        ),
      ),
    );
  }

  /// ‹ Oct 2026 › — steps through months; the future is never selectable.
  Widget _buildMonthSelector(ExpenseProvider provider) {
    final month = provider.selectedMonth;
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;

    Widget arrow(IconData icon, String tooltip, DateTime? target) => IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: target == null ? null : () => provider.selectMonth(target),
      icon: Icon(icon, size: 20),
      color: AppColors.textPrimary,
      disabledColor: AppColors.textTertiary.withValues(alpha: 0.4),
    );

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      borderRadius: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          arrow(
            Icons.chevron_left_rounded,
            'Previous month',
            DateTime(month.year, month.month - 1),
          ),
          Text(
            DateFormat('MMM yyyy').format(month),
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          arrow(
            Icons.chevron_right_rounded,
            'Next month',
            isCurrent ? null : DateTime(month.year, month.month + 1),
          ),
        ],
      ),
    );
  }

  Future<void> _createTrip() async {
    final event = await showCreateTripDialog(context);
    if (event == null || !mounted) return;
    _tripsRefresh.value++;
    AppSnackbar.success(
      context,
      'Trip "${event.title}" created. Tag expenses to it when adding.',
      aboveNav: true,
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    final provider = ref.read(expenseProviderProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseSheet(
        onAdd: (expense) async {
          await provider.addExpense(expense);
          if (!mounted) return;
          final label =
              '${formatRupees(expense.amount)} added to '
              '${provider.categoryOf(expense).name}.';
          if (provider.monthlySpent > provider.monthlyBudget) {
            AppSnackbar.warning(
              this.context,
              '$label You are over your monthly budget.',
              aboveNav: true,
            );
          } else {
            AppSnackbar.success(this.context, label, aboveNav: true);
          }
        },
      ),
    );
  }

  void _showEditExpenseSheet(Expense expense) {
    final provider = ref.read(expenseProviderProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(
        initial: expense,
        onAdd: (updated) async {
          await provider.updateExpense(updated);
          if (!mounted) return;
          AppSnackbar.success(
            context,
            '${updated.isIncome ? 'Income' : 'Expense'} updated.',
            aboveNav: true,
          );
        },
      ),
    );
  }

  void _showCreateGroupSheet(BuildContext context) {
    final provider = ref.read(groupProviderProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateGroupSheet(
        onCreate: (name, icon) async {
          await provider.createGroup(name, icon);
          if (!mounted) return;
          AppSnackbar.success(
            this.context,
            'Event "$name" created. Add members to start splitting.',
            aboveNav: true,
          );
        },
      ),
    );
  }
}
