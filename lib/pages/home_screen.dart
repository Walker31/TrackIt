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

class HomeScreen extends ConsumerWidget {
  final Function(int)? onTabChange;
  const HomeScreen({super.key, this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseProvider = ref.watch(expenseProviderProvider);
    final workoutProvider = ref.watch(workoutProviderProvider);

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
            FadeSlideIn(
              child: PageHeader(
                title: 'Today',
                overline: DateFormat('EEEE, d MMM').format(DateTime.now()),
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
                  FadeSlideIn(
                    index: 3,
                    child: FitnessGoalSection(
                      provider: workoutProvider,
                      onViewAll: () => onTabChange?.call(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
