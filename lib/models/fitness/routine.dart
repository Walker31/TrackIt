import 'workout_type.dart';

class Routine {
  final int? id;
  final String name;
  final WorkoutType type;
  final List<RoutineExercise> exercises;

  Routine({
    this.id,
    required this.name,
    required this.type,
    this.exercises = const [],
  });

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'name': name, 'type': type.name};
  }

  factory Routine.fromMap(Map<String, dynamic> map) {
    return Routine(
      id: map['id'],
      name: map['name'],
      type: WorkoutType.fromString(map['type'] as String),
    );
  }

  Routine copyWith({
    int? id,
    String? name,
    WorkoutType? type,
    List<RoutineExercise>? exercises,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      exercises: exercises ?? this.exercises,
    );
  }
}

class RoutineExercise {
  final int? id;
  final int routineId;
  final String name;
  final String muscleGroup;
  final int setsCount;

  RoutineExercise({
    this.id,
    required this.routineId,
    required this.name,
    required this.muscleGroup,
    required this.setsCount,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'routine_id': routineId,
      'name': name,
      'muscle_group': muscleGroup,
      'sets_count': setsCount,
    };
  }

  factory RoutineExercise.fromMap(Map<String, dynamic> map) {
    return RoutineExercise(
      id: map['id'],
      routineId: map['routine_id'],
      name: map['name'],
      muscleGroup: map['muscle_group'],
      setsCount: map['sets_count'],
    );
  }

  RoutineExercise copyWith({
    int? id,
    int? routineId,
    String? name,
    String? muscleGroup,
    int? setsCount,
  }) {
    return RoutineExercise(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      setsCount: setsCount ?? this.setsCount,
    );
  }
}
