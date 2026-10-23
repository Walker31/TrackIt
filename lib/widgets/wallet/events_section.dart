import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../providers/group_provider.dart';
import '../../pages/group_detail_screen.dart';
import '../animated/fade_slide_in.dart';
import 'group_card.dart';

class EventsSection extends StatelessWidget {
  final GroupProvider provider;

  const EventsSection({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final groups = provider.groups;

    if (provider.isLoading && groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.groups_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              "No events yet.\nCreate one to split expenses with others.",
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
