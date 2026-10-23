import 'workout_type.dart';
import 'exercise.dart';

class Workout {
  final int? id;
  final WorkoutType type;
  final DateTime timestamp;
  final List<Exercise> exercises;
  final String? notes;

  Workout({
    this.id,
    required this.type,
    required this.timestamp,
    this.exercises = const [],
    this.notes,
  });

  double getTotalSessionVolume() {
    return exercises.fold(0, (sum, e) => sum + e.getTotalVolume());
  }

  int getTotalSets() {
    return exercises.fold(0, (sum, e) => sum + e.sets.length);
  }

  int getTotalCompletedSets() {
    return exercises.fold(0, (sum, e) => sum + e.getCompletedSetsCount());
  }

  double getSessionCompletionPercentage() {
    if (getTotalSets() == 0) return 0.0;
    return (getTotalCompletedSets() / getTotalSets()) * 100;
  }

  Map<String, dynamic> getSessionSummary() {
    return {
      'id': id,
      'type': type.displayName,
      'date': timestamp.toIso8601String(),
      'totalVolume': getTotalSessionVolume(),
      'completedSets': getTotalCompletedSets(),
      'totalSets': getTotalSets(),
      'completionPercentage': getSessionCompletionPercentage(),
      'notes': notes,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] as int?,
      type: WorkoutType.fromString(map['type'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      notes: map['notes'] as String?,
      exercises: map['exercises'] != null
          ? (map['exercises'] as List).map((e) => Exercise.fromMap(e)).toList()
          : [],
    );
  }

  Workout copyWith({
    int? id,
    WorkoutType? type,
    DateTime? timestamp,
    List<Exercise>? exercises,
    String? notes,
  }) {
    return Workout(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      exercises: exercises ?? this.exercises,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'Workout(type: ${type.displayName}, totalVolume: ${getTotalSessionVolume()}, completionPercentage: ${getSessionCompletionPercentage().toStringAsFixed(2)}%)';
  }
}
