import 'package:flutter/material.dart';
import '../../providers/group_provider.dart';
import '../empty_state.dart';
import '../../pages/group_detail_screen.dart';
import '../animated/fade_slide_in.dart';
import 'group_card.dart';

class EventsSection extends StatelessWidget {
  final GroupProvider provider;

  /// Starts creating a new event (shown in the empty state).
  final VoidCallback? onCreate;

  const EventsSection({super.key, required this.provider, this.onCreate});

  @override
  Widget build(BuildContext context) {
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
        onAction: onCreate,
      );
    }

    return Column(
      children: groups.asMap().entries.map((entry) {
        final index = entry.key;
        final group = entry.value;
        return FadeSlideIn(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FutureBuilder<double>(
              future: provider.getMyBalance(group.id!),
              builder: (context, snapshot) {
                return GroupCard(
                  group: group,
                  myBalance: snapshot.data ?? 0.0,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(groupId: group.id!),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }
}
