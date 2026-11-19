import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../layout.dart' show AppTab;
import '../widgets/wallet/expense_flows.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/responsive.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../widgets/app_card.dart';
import '../widgets/page_header.dart';
import '../widgets/section_header.dart';
import '../services/expense_service.dart';
import '../services/workout_service.dart';
import '../widgets/analytics/monthly_report_card.dart';
import '../widgets/analytics/spending_chart.dart';
import '../widgets/analytics/volume_chart.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // The tab stays alive between visits, so charts reload when the
  // underlying expenses or workouts change rather than on every visit.
  late Future<Map<DateTime, double>> _spending = ExpenseService()
      .getWeeklyExpenseData();
  late Future<Map<DateTime, double>> _volume = WorkoutService()
      .getWeeklyVolumeData();

  @override
  Widget build(BuildContext context) {
    ref.listen(expenseProviderProvider, (_, _) {
      setState(() => _spending = ExpenseService().getWeeklyExpenseData());
    });
    ref.listen(workoutProviderProvider, (_, _) {
      setState(() => _volume = WorkoutService().getWeeklyVolumeData());
    });

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: PageHeader(title: 'Stats')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                Responsive.pageBottomPadding(context),
              ),
              child: ResponsiveColumns(
                gap: 40,
                left: [
                  const FadeSlideIn(child: SectionHeader(title: 'This month')),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 1,
                    child: MonthlyReportCard(
                      expenses: ref.watch(expenseProviderProvider),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const FadeSlideIn(child: SectionHeader(title: "Spending")),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 1,
                    child: FutureBuilder<Map<DateTime, double>>(
                      future: _spending,
                      builder: (context, snapshot) => _fadeIn(
                        !snapshot.hasData && !snapshot.hasError
                            ? const _ChartLoading()
                            : SpendingChart(
                                data: snapshot.data ?? {},
                                onAdd: () => openAddExpense(
                                  context,
                                  ref.read(expenseProviderProvider),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
                right: [
                  const FadeSlideIn(
                    index: 2,
                    child: SectionHeader(title: "Training volume"),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 3,
                    child: FutureBuilder<Map<DateTime, double>>(
                      future: _volume,
                      builder: (context, snapshot) => _fadeIn(
                        !snapshot.hasData && !snapshot.hasError
                            ? const _ChartLoading()
                            : VolumeChart(
                                data: snapshot.data ?? {},
                                onStart: () => context.go(AppTab.workout.path),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cross-fades from the loading placeholder to the chart.
  Widget _fadeIn(Widget child) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    switchInCurve: Curves.easeOutCubic,
    child: KeyedSubtree(key: ValueKey(child.runtimeType), child: child),
  );
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: SizedBox(
        height: 252,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}
