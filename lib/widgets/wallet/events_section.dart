import 'package:flutter/material.dart';
import '../../models/expenses.dart';
import '../../providers/group_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/format.dart';
import '../app_card.dart';
import '../empty_state.dart';
import '../../pages/group_detail_screen.dart';
import '../animated/fade_slide_in.dart';
import 'group_card.dart';

/// The events list, laid out like Splitwise's groups tab: an overall
/// balance line, then every event in one list.
class EventsSection extends StatefulWidget {
  final GroupProvider provider;

  /// Starts creating a new event.
  final VoidCallback? onCreate;

  const EventsSection({super.key, required this.provider, this.onCreate});

  @override
  State<EventsSection> createState() => _EventsSectionState();
}

class _EventsSectionState extends State<EventsSection> {
  List<Group>? _loadedFor;
  late Future<List<double>> _balances;

  /// Your balance in each event, refetched only when the list changes.
  Future<List<double>> _balancesFor(List<Group> groups) {
    if (!identical(groups, _loadedFor)) {
      _loadedFor = groups;
      _balances = Future.wait([
        for (final g in groups) widget.provider.getMyBalance(g.id!),
      ]);
    }
    return _balances;
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final groups = provider.groups;

    if (provider.isLoading && groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (groups.isEmpty) {
      return EmptyState(
        icon: Icons.groups_outlined,
        title: 'No events yet',
        message: 'Create one to split expenses with friends.',
        actionLabel: 'New event',
        onAction: widget.onCreate,
      );
    }

    return FutureBuilder<List<double>>(
      future: _balancesFor(groups),
      builder: (context, snapshot) {
        final balances = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (balances != null) _OverallBalance(balances: balances),
            FadeSlideIn(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < groups.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 82),
                      GroupCard(
                        group: groups[i],
                        myBalance: balances?[i] ?? 0,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                GroupDetailScreen(groupId: groups[i].id!),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.onCreate != null) ...[
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton.icon(
                  onPressed: widget.onCreate,
                  icon: const Icon(Icons.group_add_outlined, size: 20),
                  label: const Text('Start a new event'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// "Overall, you are owed ₹1,200" across every event.
class _OverallBalance extends StatelessWidget {
  final List<double> balances;
  const _OverallBalance({required this.balances});

  @override
  Widget build(BuildContext context) {
    final owed = balances.where((b) => b > 0).fold<double>(0, (a, b) => a + b);
    final owe = balances.where((b) => b < 0).fold<double>(0, (a, b) => a - b);
    final base = AppTextStyles.bodyLg.copyWith(
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    );

    List<InlineSpan> part(String label, double amount, Color color) => [
      TextSpan(text: label),
      TextSpan(
        text: formatRupees(amount),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    ];

    final spans = <InlineSpan>[
      if (owed < 0.01 && owe < 0.01)
        const TextSpan(text: 'You are all settled up')
      else ...[
        const TextSpan(text: 'Overall, '),
        if (owed >= 0.01) ...part('you are owed ', owed, AppColors.income),
        if (owed >= 0.01 && owe >= 0.01) const TextSpan(text: ' and '),
        if (owe >= 0.01) ...part('you owe ', owe, AppColors.outflow),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      child: Text.rich(TextSpan(style: base, children: spans)),
    );
  }
}
