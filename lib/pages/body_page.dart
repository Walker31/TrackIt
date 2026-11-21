import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/body_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';

/// Asks for today's weight; saves it and returns true when logged.
Future<bool> logWeight(BuildContext context, {double? last}) async {
  final controller = TextEditingController(
    text: last == null ? '' : formatWeight(last),
  );
  final value = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Today's weight"),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: const InputDecoration(suffixText: 'kg'),
        onSubmitted: (v) => Navigator.pop(context, double.tryParse(v)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, double.tryParse(controller.text)),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value == null) return false;
  if (value < 20 || value > 400) {
    if (context.mounted) {
      AppSnackbar.error(context, 'Enter a weight between 20 and 400 kg.');
    }
    return false;
  }
  await BodyService().log(value);
  if (context.mounted) {
    AppSnackbar.success(context, 'Logged ${formatWeight(value)} kg.');
  }
  return true;
}

class BodyPage extends StatefulWidget {
  const BodyPage({super.key});

  @override
  State<BodyPage> createState() => _BodyPageState();
}

class _BodyPageState extends State<BodyPage> {
  late Future<List<WeightEntry>> _entries = BodyService().entries();

  void _reload() => setState(() => _entries = BodyService().entries());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WeightEntry>>(
      future: _entries,
      builder: (context, snap) {
        final entries = snap.data;
        return Scaffold(
          appBar: AppBar(title: const Text('Body weight')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              if (await logWeight(context, last: entries?.lastOrNull?.weight)) {
                _reload();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Log weight'),
          ),
          body: entries == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                      children: entries.isEmpty
                          ? const [
                              EmptyState(
                                card: true,
                                icon: Icons.monitor_weight_outlined,
                                title: 'No weigh-ins yet',
                                message:
                                    'Log your weight now and then. A smoothed '
                                    'trend line shows the real direction.',
                              ),
                            ]
                          : [
                              _Summary(entries: entries),
                              const SizedBox(height: 12),
                              if (entries.length >= 2)
                                AppCard(
                                  child: SizedBox(
                                    height: 220,
                                    child: _WeightChart(entries: entries),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              const Text('Entries', style: AppTextStyles.h3),
                              const SizedBox(height: 8),
                              for (final e in entries.reversed)
                                Dismissible(
                                  key: ValueKey(e.date),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 16),
                                    color: AppColors.expense.withValues(
                                      alpha: 0.12,
                                    ),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                  onDismissed: (_) async {
                                    await BodyService().delete(e.date);
                                    _reload();
                                    if (!context.mounted) return;
                                    AppSnackbar.info(
                                      context,
                                      'Entry deleted.',
                                      actionLabel: 'Undo',
                                      onAction: () async {
                                        await BodyService().log(
                                          e.weight,
                                          on: e.date,
                                        );
                                        _reload();
                                      },
                                    );
                                  },
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${formatWeight(e.weight)} kg',
                                      style: AppTextStyles.bodyMd.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: Text(
                                      DateFormat(
                                        'EEE d MMM yyyy',
                                      ).format(e.date),
                                      style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  final List<WeightEntry> entries;
  const _Summary({required this.entries});

  @override
  Widget build(BuildContext context) {
    final change = weightChange(entries);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${formatWeight(entries.last.weight)} kg',
                  style: AppTextStyles.h2,
                ),
              ],
            ),
          ),
          if (change != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '30 days',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${change > 0
                      ? '+'
                      : change < 0
                      ? '−'
                      : ''}'
                  '${formatWeight(change.abs())} kg',
                  style: AppTextStyles.h3,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  const _WeightChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final first = entries.first.date;
    double x(DateTime d) => d.difference(first).inDays.toDouble();
    final weights = entries.map((e) => e.weight);
    final lo = weights.reduce((a, b) => a < b ? a : b);
    final hi = weights.reduce((a, b) => a > b ? a : b);
    final avg = movingAverage(entries);
    return Semantics(
      label:
          'Weight chart from ${formatWeight(entries.first.weight)} to '
          '${formatWeight(entries.last.weight)} kg.',
      child: LineChart(
        LineChartData(
          minY: (lo - 1).floorToDouble(),
          maxY: (hi + 1).ceilToDouble(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.textTertiary.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (x(entries.last.date) / 3).clamp(1, 1e9),
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat(
                      'd MMM',
                    ).format(first.add(Duration(days: v.round()))),
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, meta) => Text(
                  formatWeight(v),
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final e in entries) FlSpot(x(e.date), e.weight)],
              color: AppColors.textTertiary.withValues(alpha: 0.6),
              barWidth: 0,
              dotData: const FlDotData(show: true),
            ),
            LineChartBarData(
              spots: [for (final e in avg) FlSpot(x(e.date), e.weight)],
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today-screen card: latest weight and its trend, with a quick log.
class BodyWeightCard extends StatefulWidget {
  const BodyWeightCard({super.key});

  @override
  State<BodyWeightCard> createState() => _BodyWeightCardState();
}

class _BodyWeightCardState extends State<BodyWeightCard> {
  late Future<List<WeightEntry>> _entries = BodyService().entries();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WeightEntry>>(
      future: _entries,
      builder: (context, snap) {
        final entries = snap.data ?? const <WeightEntry>[];
        final change = weightChange(entries);
        final last = entries.lastOrNull;
        final loggedToday =
            last != null && DateUtils.isSameDay(last.date, DateTime.now());
        return AppCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await context.push('/body');
              if (mounted) {
                setState(() => _entries = BodyService().entries());
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Icon(Icons.monitor_weight_outlined, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          last == null
                              ? 'Body weight'
                              : '${formatWeight(last.weight)} kg',
                          style: AppTextStyles.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          last == null
                              ? 'Track your weight and see the trend'
                              : change == null
                              ? 'Logged ${DateFormat('d MMM').format(last.date)}'
                              : '${change > 0
                                        ? '+'
                                        : change < 0
                                        ? '−'
                                        : '±'}'
                                    '${formatWeight(change.abs())} kg in 30 days',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!loggedToday)
                    TextButton(
                      onPressed: () async {
                        if (await logWeight(context, last: last?.weight) &&
                            mounted) {
                          setState(() => _entries = BodyService().entries());
                        }
                      },
                      child: const Text('Log'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
