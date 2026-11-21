import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../layout.dart' show AppTab;
import '../models/expenses.dart';
import '../widgets/wallet/expense_flows.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../providers/expense_provider.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/responsive.dart';
import '../utils/format.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import '../widgets/section_header.dart';
import '../widgets/analytics/monthly_report_card.dart';
import '../widgets/analytics/range_bar_chart.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _StatsData {
  final List<StatPoint> spending;
  final List<StatPoint> volume;
  final List<({String group, int sets})> muscles;
  final List<Expense> expenses;
  _StatsData(this.spending, this.volume, this.muscles, this.expenses);
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  StatsRange _range = StatsRange.week;
  late Future<_StatsData> _data = _load();

  // The tab stays alive between visits, so figures reload when expenses or
  // workouts change rather than on every visit.
  Future<_StatsData> _load() async {
    final s = StatsService();
    final (spending, volume, muscles, rows) = await (
      s.spending(_range),
      s.volume(_range),
      s.muscleSets(_range),
      s.expenseRows(_range),
    ).wait;
    return _StatsData(
      spending,
      volume,
      muscles,
      rows.map(Expense.fromMap).toList(),
    );
  }

  void _reload() => setState(() => _data = _load());

  void _openDay(StatPoint p) {
    final end = _range.monthly
        ? DateTime(p.start.year, p.start.month + 1, 0)
        : p.start;
    final f = DateFormat('yyyy-MM-dd');
    context.push(
      '/transactions?from=${f.format(p.start)}&to=${f.format(end)}&type=expense',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(expenseProviderProvider, (_, _) => _reload());
    ref.listen(workoutProviderProvider, (_, _) => _reload());
    final expenses = ref.watch(expenseProviderProvider);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Stats',
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _RangePicker(
                    range: _range,
                    onChanged: (r) {
                      _range = r;
                      _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                Responsive.pageBottomPadding(context),
              ),
              child: FutureBuilder<_StatsData>(
                future: _data,
                builder: (context, snap) {
                  final d = snap.data;
                  return ResponsiveColumns(
                    gap: 40,
                    left: [
                      const FadeSlideIn(
                        child: SectionHeader(title: 'This month'),
                      ),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        index: 1,
                        child: MonthlyReportCard(expenses: expenses),
                      ),
                      const SizedBox(height: 32),
                      const SectionHeader(title: 'Spending'),
                      const SizedBox(height: 12),
                      _fadeIn(
                        d == null
                            ? const _ChartLoading()
                            : RangeBarChart(
                                key: ValueKey('spend-$_range'),
                                points: d.spending,
                                range: _range,
                                color: AppColors.primary,
                                format: formatRupees,
                                formatAxis: formatRupeesCompact,
                                semanticNoun: 'spent',
                                emptyTitle: 'Nothing spent',
                                emptyMessage:
                                    'Your spending for '
                                    '${_range.caption.toLowerCase()} shows up here.',
                                emptyActionLabel: 'Add expense',
                                onEmptyAction: () => openAddExpense(
                                  context,
                                  ref.read(expenseProviderProvider),
                                ),
                                onTapBar: _openDay,
                              ),
                      ),
                      if (d != null && d.expenses.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _CategoryBreakdown(
                          expenses: d.expenses,
                          provider: expenses,
                          caption: _range.caption,
                        ),
                      ],
                    ],
                    right: [
                      const SectionHeader(title: 'Training'),
                      const SizedBox(height: 12),
                      _fadeIn(
                        d == null
                            ? const _ChartLoading()
                            : RangeBarChart(
                                key: ValueKey('vol-$_range'),
                                points: d.volume,
                                range: _range,
                                color: AppColors.workout,
                                format: (v) => '${formatWeight(v)} kg',
                                formatAxis: (v) => v >= 1000
                                    ? '${formatWeight(v / 1000)}t'
                                    : formatWeight(v),
                                semanticNoun: 'lifted',
                                emptyTitle: 'No training logged',
                                emptyMessage:
                                    'Volume (weight × reps) you lift shows up '
                                    'here.',
                                emptyActionLabel: 'Start a workout',
                                onEmptyAction: () =>
                                    context.go(AppTab.workout.path),
                              ),
                      ),
                      if (d != null) ...[
                        const SizedBox(height: 16),
                        _MuscleHeatMap(
                          muscles: d.muscles,
                          caption: _range.caption,
                        ),
                      ],
                    ],
                  );
                },
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
    child: child,
  );
}

class _RangePicker extends StatelessWidget {
  final StatsRange range;
  final ValueChanged<StatsRange> onChanged;
  const _RangePicker({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) => SegmentedButton<StatsRange>(
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    segments: [
      for (final r in StatsRange.values)
        ButtonSegment(value: r, label: Text(r.label)),
    ],
    selected: {range},
    onSelectionChanged: (s) => onChanged(s.first),
  );
}

/// Spending per category in the range, largest first, as bars.
class _CategoryBreakdown extends StatelessWidget {
  final List<Expense> expenses;
  final ExpenseProvider provider;
  final String caption;

  const _CategoryBreakdown({
    required this.expenses,
    required this.provider,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final rows = provider.spendByCategory(expenses);
    final total = rows.fold<double>(0, (a, r) => a + r.value);
    if (total <= 0) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By category', style: AppTextStyles.h3),
          Text(
            caption,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          for (final r in rows.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(r.key.iconData, size: 16, color: r.key.colorValue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r.key.name, style: AppTextStyles.bodyMd),
                      ),
                      Text(
                        '${formatRupees(r.value)} · '
                        '${(r.value / total * 100).round()}%',
                        style: AppTextStyles.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: r.value / rows.first.value,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(r.key.colorValue),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Completed sets per muscle group, shaded by how much each was trained.
class _MuscleHeatMap extends StatelessWidget {
  final List<({String group, int sets})> muscles;
  final String caption;

  const _MuscleHeatMap({required this.muscles, required this.caption});

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) {
      return const EmptyState(
        card: true,
        icon: Icons.accessibility_new_rounded,
        title: 'No muscle groups yet',
        message: 'Tag exercises with a muscle group to see your balance here.',
      );
    }
    final peak = muscles.first.sets;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Muscle groups', style: AppTextStyles.h3),
          Text(
            'Sets done · $caption',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in muscles)
                Semantics(
                  label: '${m.group}: ${m.sets} sets',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.workout.withValues(
                        alpha: 0.12 + 0.6 * (m.sets / peak),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${m.group}  ${m.sets}',
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: m.sets / peak > 0.5
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: 252,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(context, 90, 12),
            const SizedBox(height: 8),
            _bar(context, 140, 22),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final h in const <double>[60, 110, 80, 140, 70, 120, 90])
                  _bar(context, 16, h),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}
