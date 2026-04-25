import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
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
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: "Financial Trends",
                    subtitle: "Weekly Spending",
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<Map<DateTime, double>>(
                    future: _expenseService.getWeeklyExpenseData(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const AppCard(child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
                      }
                      return SpendingChart(data: snapshot.data ?? {});
                    },
                  ),
                  const SizedBox(height: 40),
                  const SectionHeader(
                    title: "Physical Progress",
                    subtitle: "Workout Volume",
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<Map<DateTime, double>>(
                    future: _workoutService.getWeeklyVolumeData(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const AppCard(child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
                      }
                      return VolumeChart(data: snapshot.data ?? {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return const SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 20, bottom: 16),
        centerTitle: false,
        title: Text("Analytics", style: AppTextStyles.h2),
      ),
    );
  }
}
