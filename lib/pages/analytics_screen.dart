import 'package:flutter/material.dart';
import '../theme/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../widgets/app_card.dart';
import '../widgets/page_header.dart';
import '../widgets/section_header.dart';
import '../services/expense_service.dart';
import '../services/workout_service.dart';
import '../widgets/analytics/spending_chart.dart';
import '../widgets/analytics/volume_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final WorkoutService _workoutService = WorkoutService();

  @override
  Widget build(BuildContext context) {
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
                  const FadeSlideIn(
                    child: SectionHeader(
                      title: "Financial Trends",
                      subtitle: "Weekly Spending",
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    index: 1,
                    child: FutureBuilder<Map<DateTime, double>>(
                      future: _expenseService.getWeeklyExpenseData(),
                      builder: (context, snapshot) => _fadeIn(
                        snapshot.connectionState == ConnectionState.waiting
                            ? const _ChartLoading()
                            : SpendingChart(data: snapshot.data ?? {}),
                      ),
                    ),
                  ),
                ],
                right: [
                  const FadeSlideIn(
                    index: 2,
                    child: SectionHeader(
                      title: "Physical Progress",
                      subtitle: "Workout Volume",
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    index: 3,
                    child: FutureBuilder<Map<DateTime, double>>(
                      future: _workoutService.getWeeklyVolumeData(),
                      builder: (context, snapshot) => _fadeIn(
                        snapshot.connectionState == ConnectionState.waiting
                            ? const _ChartLoading()
                            : VolumeChart(data: snapshot.data ?? {}),
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
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );
  }
}
