import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/format.dart';
import '../app_card.dart';

/// Stats tab's month summary: income vs spending, what's left, the change
/// from last month and the biggest categories. Arrows step through months.
class MonthlyReportCard extends StatefulWidget {
  const MonthlyReportCard({super.key});

  @override
  State<MonthlyReportCard> createState() => _MonthlyReportCardState();
}

class _MonthlyReportCardState extends State<MonthlyReportCard> {
  final _service = ReportService();
  late DateTime _month;
  late Future<MonthlyReport> _report;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _report = _service.monthly(_month);
  }

  bool get _isCurrent {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _step(int months) => setState(() {
    _month = DateTime(_month.year, _month.month + months);
    _report = _service.monthly(_month);
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_month),
                  style: AppTextStyles.h3,
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
                onPressed: () => _step(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
                onPressed: _isCurrent ? null : () => _step(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<MonthlyReport>(
            future: _report,
            builder: (context, snapshot) {
              final report = snapshot.data;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: report == null
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        height: 160,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : KeyedSubtree(
                        key: ValueKey(report.month),
                        child: _body(report),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _body(MonthlyReport r) {
    if (r.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Nothing recorded this month.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    final previousName = DateFormat(
      'MMMM',
    ).format(DateTime(r.month.year, r.month.month - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _figure('Money in', r.income, AppColors.income)),
            Expanded(child: _figure('Spent', r.spent, AppColors.outflow)),
            Expanded(
              child: _figure(
                r.net >= 0 ? 'Saved' : 'Overspent',
                r.net.abs(),
                r.net >= 0 ? AppColors.textPrimary : AppColors.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _changeLine(r, previousName),
        if (r.topCategories.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('TOP CATEGORIES', style: AppTextStyles.overline),
          const SizedBox(height: 10),
          for (final c in r.topCategories) _categoryRow(c, r.spent),
        ],
      ],
    );
  }

  Widget _figure(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatRupees(amount),
            style: AppTextStyles.bodyLg.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// "▲ 12% more than September" — up is orange (more spent), down teal.
  Widget _changeLine(MonthlyReport r, String previousName) {
    final change = r.change;
    if (change == null) {
      return Text(
        'Nothing spent in $previousName to compare with.',
        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
      );
    }
    final percent = (change.abs() * 100).round();
    final up = change > 0;
    final color = percent == 0
        ? AppColors.textSecondary
        : up
        ? AppColors.outflow
        : AppColors.income;
    return Row(
      children: [
        Icon(
          percent == 0
              ? Icons.trending_flat_rounded
              : up
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            percent == 0
                ? 'About the same as $previousName'
                : '$percent% ${up ? 'more' : 'less'} than $previousName '
                      '(${formatRupees(r.previousSpent)})',
            style: AppTextStyles.bodySm.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Widget _categoryRow(CategorySpend c, double total) {
    final share = total > 0 ? c.amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(c.icon, size: 18, color: c.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${formatRupees(c.amount)} · ${(share * 100).round()}%',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 5,
                    color: c.color,
                    backgroundColor: AppColors.surfaceVariant,
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
