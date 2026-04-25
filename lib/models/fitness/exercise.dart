import 'set_data.dart';

class Exercise {
  final int? id;
  final int workoutId;
  final String name;
  final String muscleGroup;
  final List<SetData> sets;
  final DateTime? createdAt;

  Exercise({
    this.id,
    required this.workoutId,
    required this.name,
    required this.muscleGroup,
    this.sets = const [],
    this.createdAt,
  });

  double getTotalVolume() {
    return sets.where((s) => s.isCompleted).fold(0, (sum, s) => sum + (s.weight * s.reps));
  }

  double getCompletionPercentage() {
    if (sets.isEmpty) return 0.0;
    final completed = sets.where((s) => s.isCompleted).length;
    return (completed / sets.length) * 100;
  }

  int getCompletedSetsCount() {
    return sets.where((s) => s.isCompleted).length;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'workout_id': workoutId,
      'name': name,
      'muscle_group': muscleGroup,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int?,
      workoutId: map['workout_id'] as int,
      name: map['name'] as String,
      muscleGroup: map['muscle_group'] as String,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }

  Exercise copyWith({
    int? id,
    int? workoutId,
    String? name,
    String? muscleGroup,
    List<SetData>? sets,
  }) {
    return Exercise(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      sets: sets ?? this.sets,
    );
  }
}
