class SetData {
  final int? id;
  final int exerciseId;
  final int setNumber;
  final double weight;
  final int reps;
  final bool isCompleted;
  final DateTime? createdAt;

  SetData({
    this.id,
    required this.exerciseId,
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.isCompleted = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'exercise': exerciseId, // Django field name
      'set_number': setNumber,
      'weight': weight.toString(), // Send as string for EncryptedCharField
      'reps': reps,
      'is_completed': isCompleted, // Send as bool for Django
    };
  }

  factory SetData.fromMap(Map<String, dynamic> map) {
    return SetData(
      id: map['id'] as int?,
      exerciseId: map['exercise'] as int, // Django uses 'exercise'
      setNumber: map['set_number'] as int,
      weight: double.parse(map['weight'].toString()),
      reps: map['reps'] as int,
      isCompleted: map['is_completed'] as bool, // Django returns bool
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  SetData copyWith({
    int? id,
    int? exerciseId,
    int? setNumber,
    double? weight,
    int? reps,
    bool? isCompleted,
  }) {
    return SetData(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      setNumber: setNumber ?? this.setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
