import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/responsive.dart';
import '../providers/app_providers.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../widgets/page_header.dart';
import '../widgets/dashboard/daily_summary_card.dart';
import '../widgets/dashboard/recent_expenses_section.dart';
import '../widgets/dashboard/fitness_goal_section.dart';
import '../widgets/dashboard/quick_add_card.dart';
import '../widgets/wallet/expense_flows.dart';
import 'body_page.dart' show BodyWeightCard;
import '../widgets/onboarding.dart' show OnboardingGate;

class HomeScreen extends ConsumerWidget {
  final Function(int)? onTabChange;
  const HomeScreen({super.key, this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseProvider = ref.watch(expenseProviderProvider);
    final workoutProvider = ref.watch(workoutProviderProvider);
    final twoColumns = WindowSize.of(context) == WindowSize.expanded;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            expenseProvider.refreshData(),
            workoutProvider.refreshData(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.only(
            bottom: Responsive.pageBottomPadding(context),
          ),
          children: [
            const OnboardingGate(),
            FadeSlideIn(
              child: PageHeader(
                title: 'Today',
                overline: DateFormat('EEEE, d MMM').format(DateTime.now()),
                actions: [
                  // Phones add from the Wallet button or Quick add below.
                  if (!WindowSize.of(context).usesBottomNav)
                    HeaderAddButton(
                      label: 'Add expense',
                      onPressed: () => openAddExpense(context, expenseProvider),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: ResponsiveColumns(
                gap: 32,
                // Phones stack left then right: summary, expenses, workout.
                left: [
                  FadeSlideIn(
                    index: 1,
                    child: DailySummaryCard(
                      expenseProvider: expenseProvider,
                      workoutProvider: workoutProvider,
                    ),
                  ),
                  // Stacked layouts want it straight after the summary.
                  if (!twoColumns) ...[
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      index: 2,
                      child: QuickAddCard(provider: expenseProvider),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FadeSlideIn(
                    index: 2,
                    child: RecentExpensesSection(
                      provider: expenseProvider,
                      onViewAll: () => onTabChange?.call(1),
                    ),
                  ),
                ],
                right: [
                  if (twoColumns) ...[
                    FadeSlideIn(
                      index: 3,
                      child: QuickAddCard(provider: expenseProvider),
                    ),
                    const SizedBox(height: 32),
                  ],
                  FadeSlideIn(
                    index: 4,
                    child: FitnessGoalSection(
                      provider: workoutProvider,
                      onViewAll: () => onTabChange?.call(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const FadeSlideIn(index: 5, child: BodyWeightCard()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
