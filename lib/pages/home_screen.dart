import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/responsive.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/app_providers.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../widgets/dashboard/daily_summary_card.dart';
import '../widgets/dashboard/recent_expenses_section.dart';
import '../widgets/dashboard/fitness_goal_section.dart';

class HomeScreen extends ConsumerWidget {
  final Function(int)? onTabChange;
  const HomeScreen({super.key, this.onTabChange});

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseProvider = ref.watch(expenseProviderProvider);
    final workoutProvider = ref.watch(workoutProviderProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
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
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              Responsive.pageBottomPadding(context),
            ),
            children: [
              FadeSlideIn(child: _header(context)),
              const SizedBox(height: 28),
              ResponsiveColumns(
                gap: 36,
                // Phones stack left then right: summary, expenses, workout.
                left: [
                  FadeSlideIn(
                    index: 1,
                    child: DailySummaryCard(
                      expenseProvider: expenseProvider,
                      workoutProvider: workoutProvider,
                    ),
                  ),
                  const SizedBox(height: 36),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              const Text('Today', style: AppTextStyles.h1),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: Icon(Icons.settings_outlined, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
