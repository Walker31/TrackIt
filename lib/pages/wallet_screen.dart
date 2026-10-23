import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/section_header.dart';
import '../widgets/glass_container.dart';
import '../providers/app_providers.dart';
import '../widgets/wallet/financial_analysis_card.dart';
import '../widgets/wallet/transaction_list.dart';
import '../widgets/wallet/add_expense_sheet.dart';
import '../widgets/wallet/events_section.dart';
import '../widgets/wallet/trips_section.dart';
import '../widgets/wallet/budgets_card.dart';
import '../widgets/wallet/create_group_sheet.dart';
import '../widgets/animated/animated_segmented_tabs.dart';
import '../widgets/animated/fade_slide_in.dart';

enum _WalletTab { personal, events, trips }

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  DateTime _selectedDate = DateTime.now();
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

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
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
                        ? Column(
                            key: const ValueKey('personal'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionHeader(
                                title: "Financial Analysis",
                                subtitle: "Monthly Spending",
                                action: _buildMonthSelector(),
                              ),
                              const SizedBox(height: 24),
                              FadeSlideIn(
                                child: FinancialAnalysisCard(
                                  provider: provider,
                                ),
                              ),
                              const SizedBox(height: 24),
                              BudgetsCard(provider: provider),
                              const SizedBox(height: 40),
                              const SectionHeader(
                                title: "Transactions",
                                subtitle: "History",
                              ),
                              const SizedBox(height: 16),
                              TransactionList(provider: provider),
                            ],
                          )
                        : _tab == _WalletTab.trips
                        ? Column(
                            key: const ValueKey('trips'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(
                                title: "Trips",
                                subtitle: "Tagged Spending",
                              ),
                              const SizedBox(height: 16),
                              TripsSection(refresh: _tripsRefresh),
                            ],
                          )
                        : Column(
                            key: const ValueKey('events'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(
                                title: "Events",
                                subtitle: "Shared Expenses",
                              ),
                              const SizedBox(height: 16),
                              EventsSection(provider: groupProvider),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _tab == _WalletTab.personal
              ? FloatingActionButton.extended(
                  key: const ValueKey('add_expense'),
                  onPressed: () => _showAddExpenseSheet(context),
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Expense"),
                )
              : _tab == _WalletTab.trips
              ? FloatingActionButton.extended(
                  key: const ValueKey('new_trip'),
                  onPressed: _createTrip,
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add),
                  label: const Text("New Trip"),
                )
              : FloatingActionButton.extended(
                  key: const ValueKey('new_event'),
                  onPressed: () => _showCreateGroupSheet(context),
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add),
                  label: const Text("New Event"),
                ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        centerTitle: false,
        title: const Text("Wallet", style: AppTextStyles.h2),
      ),
      actions: [
        IconButton(
          onPressed: () => switch (_tab) {
            _WalletTab.personal => _showAddExpenseSheet(context),
            _WalletTab.trips => _createTrip(),
            _WalletTab.events => _showCreateGroupSheet(context),
          },
          icon: const Icon(
            Icons.add_circle_outline,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMonthSelector() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() => _selectedDate = date);
        }
      },
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        borderRadius: 12,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('MMM yyyy').format(_selectedDate),
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
          ],
        ),
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
              '₹${expense.amount.toStringAsFixed(0)} added to ${expense.category.displayName}.';
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
