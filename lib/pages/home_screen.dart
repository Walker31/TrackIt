import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/section_header.dart';
import '../providers/app_providers.dart';
import '../widgets/dashboard/daily_summary_card.dart';
import '../widgets/dashboard/recent_expenses_section.dart';
import '../widgets/dashboard/fitness_goal_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Function(int)? onTabChange;
  const HomeScreen({super.key, this.onTabChange});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final expenseProvider = ref.watch(expenseProviderProvider);
    final workoutProvider = ref.watch(workoutProviderProvider);

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
                    title: "Today's Overview",
                    subtitle: "Your Summary",
                  ),
                  const SizedBox(height: 24),
                  DailySummaryCard(
                    expenseProvider: expenseProvider,
                    workoutProvider: workoutProvider,
                  ),
                  const SizedBox(height: 40),
                  RecentExpensesSection(
                    provider: expenseProvider,
                    onViewAll: () => widget.onTabChange?.call(1),
                  ),
                  const SizedBox(height: 40),
                  FitnessGoalSection(
                    provider: workoutProvider,
                    onViewAll: () => widget.onTabChange?.call(2),
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
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        centerTitle: false,
        title: Row(
          children: [
            const Text("Dashboard", style: AppTextStyles.h2),
            const Spacer(),
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: Icon(
                Icons.settings_outlined,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: const Icon(
                  Icons.person,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
