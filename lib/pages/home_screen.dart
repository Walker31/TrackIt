import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/section_header.dart';
import '../providers/expense_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/dashboard/daily_summary_card.dart';
import '../widgets/dashboard/recent_expenses_section.dart';
import '../widgets/dashboard/fitness_goal_section.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  const HomeScreen({super.key, this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final workoutProvider = context.watch<WorkoutProvider>();

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
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        centerTitle: false,
        title: Row(
          children: [
            const Text("Dashboard", style: AppTextStyles.h2),
            const Spacer(),
            IconButton(
              onPressed: () => _showSettingsDialog(context),
              icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: AppColors.primary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final provider = context.read<ExpenseProvider>();
    final controller = TextEditingController(text: provider.monthlyBudget.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Settings", style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Set Monthly Budget", style: AppTextStyles.label),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: "₹",
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 50000;
              provider.updateBudget(amount);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
