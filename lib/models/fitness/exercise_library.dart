/// A common lift and the muscle group it trains.
class LibraryExercise {
  final String name;
  final String muscleGroup;
  const LibraryExercise(this.name, this.muscleGroup);
}

/// Muscle groups used by the library, in display order.
const muscleGroups = [
  'Chest',
  'Back',
  'Shoulders',
  'Biceps',
  'Triceps',
  'Quads',
  'Hamstrings',
  'Glutes',
  'Calves',
  'Core',
  'Full body',
  'Cardio',
];

const exerciseLibrary = <LibraryExercise>[
  // Chest
  LibraryExercise('Bench Press', 'Chest'),
  LibraryExercise('Incline Bench Press', 'Chest'),
  LibraryExercise('Dumbbell Bench Press', 'Chest'),
  LibraryExercise('Incline Dumbbell Press', 'Chest'),
  LibraryExercise('Chest Fly', 'Chest'),
  LibraryExercise('Cable Crossover', 'Chest'),
  LibraryExercise('Push-up', 'Chest'),
  LibraryExercise('Dips', 'Chest'),
  // Back
  LibraryExercise('Deadlift', 'Back'),
  LibraryExercise('Pull-up', 'Back'),
  LibraryExercise('Chin-up', 'Back'),
  LibraryExercise('Lat Pulldown', 'Back'),
  LibraryExercise('Barbell Row', 'Back'),
  LibraryExercise('Dumbbell Row', 'Back'),
  LibraryExercise('Seated Cable Row', 'Back'),
  LibraryExercise('T-Bar Row', 'Back'),
  LibraryExercise('Face Pull', 'Back'),
  // Shoulders
  LibraryExercise('Overhead Press', 'Shoulders'),
  LibraryExercise('Dumbbell Shoulder Press', 'Shoulders'),
  LibraryExercise('Lateral Raise', 'Shoulders'),
  LibraryExercise('Front Raise', 'Shoulders'),
  LibraryExercise('Rear Delt Fly', 'Shoulders'),
  LibraryExercise('Arnold Press', 'Shoulders'),
  LibraryExercise('Shrug', 'Shoulders'),
  // Arms
  LibraryExercise('Barbell Curl', 'Biceps'),
  LibraryExercise('Dumbbell Curl', 'Biceps'),
  LibraryExercise('Hammer Curl', 'Biceps'),
  LibraryExercise('Preacher Curl', 'Biceps'),
  LibraryExercise('Cable Curl', 'Biceps'),
  LibraryExercise('Tricep Pushdown', 'Triceps'),
  LibraryExercise('Skull Crusher', 'Triceps'),
  LibraryExercise('Overhead Tricep Extension', 'Triceps'),
  LibraryExercise('Close-Grip Bench Press', 'Triceps'),
  // Legs
  LibraryExercise('Squat', 'Quads'),
  LibraryExercise('Front Squat', 'Quads'),
  LibraryExercise('Leg Press', 'Quads'),
  LibraryExercise('Leg Extension', 'Quads'),
  LibraryExercise('Bulgarian Split Squat', 'Quads'),
  LibraryExercise('Lunge', 'Quads'),
  LibraryExercise('Hack Squat', 'Quads'),
  LibraryExercise('Romanian Deadlift', 'Hamstrings'),
  LibraryExercise('Leg Curl', 'Hamstrings'),
  LibraryExercise('Good Morning', 'Hamstrings'),
  LibraryExercise('Hip Thrust', 'Glutes'),
  LibraryExercise('Glute Bridge', 'Glutes'),
  LibraryExercise('Cable Kickback', 'Glutes'),
  LibraryExercise('Standing Calf Raise', 'Calves'),
  LibraryExercise('Seated Calf Raise', 'Calves'),
  // Core
  LibraryExercise('Plank', 'Core'),
  LibraryExercise('Crunch', 'Core'),
  LibraryExercise('Hanging Leg Raise', 'Core'),
  LibraryExercise('Cable Crunch', 'Core'),
  LibraryExercise('Russian Twist', 'Core'),
  LibraryExercise('Ab Wheel Rollout', 'Core'),
  // Full body and cardio
  LibraryExercise('Clean and Press', 'Full body'),
  LibraryExercise('Kettlebell Swing', 'Full body'),
  LibraryExercise('Burpee', 'Full body'),
  LibraryExercise('Farmer\'s Carry', 'Full body'),
  LibraryExercise('Running', 'Cardio'),
  LibraryExercise('Cycling', 'Cardio'),
  LibraryExercise('Rowing Machine', 'Cardio'),
  LibraryExercise('Jump Rope', 'Cardio'),
];

/// Library entries (plus [extra], e.g. exercises the user has logged)
/// matching [query], best matches first. Names starting with the query rank
/// above names that merely contain it; muscle group also matches.
List<LibraryExercise> searchExercises(
  String query, {
  Iterable<LibraryExercise> extra = const [],
  int limit = 12,
}) {
  final q = query.trim().toLowerCase();
  final seen = <String>{};
  final all = [
    for (final e in [...extra, ...exerciseLibrary])
      if (seen.add(e.name.trim().toLowerCase())) e,
  ];
  if (q.isEmpty) return all.take(limit).toList();
  int rank(LibraryExercise e) {
    final name = e.name.toLowerCase();
    if (name == q) return 0;
    if (name.startsWith(q)) return 1;
    if (name.split(RegExp(r'[\s-]')).any((w) => w.startsWith(q))) return 2;
    if (name.contains(q)) return 3;
    if (e.muscleGroup.toLowerCase().startsWith(q)) return 4;
    return 99;
  }

  final matches = all.where((e) => rank(e) < 99).toList();
  // Stable: earlier entries (the user's own) win ties.
  final indexed = matches.asMap().entries.toList()
    ..sort((a, b) {
      final r = rank(a.value).compareTo(rank(b.value));
      return r != 0 ? r : a.key.compareTo(b.key);
    });
  return indexed.map((e) => e.value).take(limit).toList();
}

/// The library's muscle group for [name], if it's a known lift.
String? muscleGroupFor(String name) {
  final key = name.trim().toLowerCase();
  for (final e in exerciseLibrary) {
    if (e.name.toLowerCase() == key) return e.muscleGroup;
  }
  return null;
}
