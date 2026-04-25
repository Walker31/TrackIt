import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../../models/workouts.dart';

class SessionSummaryCard extends StatelessWidget {
  final Workout workout;

  const SessionSummaryCard({
    super.key,
    required this.workout,
  });

  @override
  Widget build(BuildContext context) {
    final progress = workout.getSessionCompletionPercentage() / 100;
    return AppCard(
      gradient: AppColors.primaryGradient,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(workout.type.displayName.toUpperCase(), style: AppTextStyles.label.copyWith(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(workout.notes ?? "Workout Session", style: AppTextStyles.h2.copyWith(fontSize: 24)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TOTAL VOLUME", style: AppTextStyles.label.copyWith(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text("${workout.getTotalSessionVolume().toStringAsFixed(0)} kg", style: AppTextStyles.h3),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Icon(workout.type.icon, color: Colors.white24, size: 64),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("Session Progress", style: AppTextStyles.bodySm.copyWith(color: Colors.white70)),
                Text("${(progress * 100).toStringAsFixed(0)}%", style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
