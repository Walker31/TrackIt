import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expenses.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../animated/fade_slide_in.dart';
import '../glass_container.dart';
import '../../utils/format.dart';

class _TripData {
  final SpendEvent event;
  final double total;
  final int count;
  final List<MapEntry<Category, double>> breakdown;
  const _TripData(this.event, this.total, this.count, this.breakdown);
}

/// Blueprint "event view": each trip/occasion with its total, transaction
/// count and mini category breakdown. Reloads whenever [refresh] changes.
class TripsSection extends StatefulWidget {
  final Listenable refresh;
  const TripsSection({super.key, required this.refresh});

  @override
  State<TripsSection> createState() => _TripsSectionState();
}

class _TripsSectionState extends State<TripsSection> {
  final _catalog = CatalogService();
  late Future<List<_TripData>> _future = _load();

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_reload);
  }

  @override
  void didUpdateWidget(TripsSection old) {
    super.didUpdateWidget(old);
    if (old.refresh != widget.refresh) {
      old.refresh.removeListener(_reload);
      widget.refresh.addListener(_reload);
    }
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_reload);
    super.dispose();
  }

  void _reload() => setState(() => _future = _load());

  Future<List<_TripData>> _load() async {
    final categories = {
      for (final c in await _catalog.getCategories()) c.id: c,
    };
    final result = <_TripData>[];
    for (final e in await _catalog.getEvents()) {
      final totals = await _catalog.getEventTotals(e.id);
      final breakdown = await _catalog.getEventBreakdown(e.id);
      result.add(
        _TripData(e, totals.total, totals.count, [
          for (final b in breakdown.entries)
            if (categories[b.key] != null)
              MapEntry(categories[b.key]!, b.value),
        ]),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_TripData>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final trips = snap.data!;
        if (trips.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.luggage_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No trips yet.\nCreate one and tag expenses to see totals.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < trips.length; i++)
              FadeSlideIn(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TripCard(data: trips[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  final _TripData data;
  const _TripCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final e = data.event;
    final fmt = DateFormat('d MMM');
    final dates = e.endDate == null
        ? fmt.format(e.eventDate)
        : '${fmt.format(e.eventDate)} – ${fmt.format(e.endDate!)}';

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dates,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupees(data.total),
                    style: AppTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.expense,
                    ),
                  ),
                  Text(
                    '${data.count} transaction${data.count == 1 ? '' : 's'}',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (data.breakdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (final b in data.breakdown)
                      Expanded(
                        flex: (b.value * 100).round().clamp(1, 1 << 30),
                        child: Container(color: b.key.colorValue),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final b in data.breakdown.take(4))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(b.key.iconData, size: 14, color: b.key.colorValue),
                      const SizedBox(width: 4),
                      Text(
                        '${b.key.name} ${formatRupees(b.value)}',
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog to create a trip/occasion; returns after saving.
Future<SpendEvent?> showCreateTripDialog(BuildContext context) async {
  final title = TextEditingController();
  DateTimeRange? range;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('New trip / event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'e.g. Goa trip'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                range == null
                    ? 'Dates (optional)'
                    : '${DateFormat('d MMM').format(range!.start)} – '
                          '${DateFormat('d MMM').format(range!.end)}',
              ),
              onPressed: () async {
                final r = await showDateRangePicker(
                  context: ctx,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (r != null) setState(() => range = r);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
  final name = title.text.trim();
  title.dispose();
  if (result != true || name.isEmpty) return null;
  final end = range?.end;
  final start = range?.start;
  return CatalogService().addEvent(
    title: name,
    eventDate: start,
    endDate: (start != null && end != null && end != start) ? end : null,
  );
}
