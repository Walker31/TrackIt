import 'package:intl/intl.dart';

import '../models/expenses.dart';
import 'catalog_service.dart';
import 'database_service.dart';

/// One CSV field: quoted when it holds a comma, quote or line break, and
/// guarded against spreadsheet formula injection.
String csvField(Object? value) {
  var s = value?.toString() ?? '';
  if (s.isNotEmpty && '=+-@'.contains(s[0]) && double.tryParse(s) == null) {
    s = "'$s";
  }
  if (s.contains(RegExp(r'[",\r\n]'))) s = '"${s.replaceAll('"', '""')}"';
  return s;
}

String csvRow(Iterable<Object?> fields) => fields.map(csvField).join(',');

/// Spreadsheet-friendly exports (CSV) of transactions and workouts.
class ExportService {
  final DatabaseService _db = DatabaseService();
  final CatalogService _catalog = CatalogService();

  static final _date = DateFormat('yyyy-MM-dd');
  static final _time = DateFormat('HH:mm');

  /// Every transaction, oldest first. [from]/[to] limit the dates
  /// (inclusive).
  Future<String> transactionsCsv({DateTime? from, DateTime? to}) async {
    final db = await _db.getDatabase();
    final rows = await db.query('expenses', orderBy: 'timestamp ASC');
    final categories = {
      for (final c in await _catalog.getCategories()) c.id: c,
    };
    final subcategories = <String, String>{};
    for (final c in categories.values) {
      for (final s in await _catalog.getSubcategories(c.id)) {
        subcategories[s.id] = s.name;
      }
    }
    final events = {for (final e in await _catalog.getEvents()) e.id: e.title};

    final out = StringBuffer()
      ..writeln(
        csvRow([
          'Date',
          'Time',
          'Type',
          'Amount',
          'Category',
          'Subcategory',
          'Paid with',
          'Note',
          'Trip',
          'Currency',
          'Amount in currency',
        ]),
      );
    for (final row in rows) {
      final e = Expense.fromMap(row);
      final day = DateTime(
        e.timestamp.year,
        e.timestamp.month,
        e.timestamp.day,
      );
      if (from != null && day.isBefore(from)) continue;
      if (to != null && day.isAfter(to)) continue;
      final category =
          categories[e.categoryId]?.name ??
          defaultCategories
              .where((c) => c.legacy == e.category && c.type == e.type)
              .firstOrNull
              ?.name ??
          e.category.displayName;
      out.writeln(
        csvRow([
          _date.format(e.timestamp),
          _time.format(e.timestamp),
          e.isIncome ? 'Income' : 'Expense',
          e.amount.toStringAsFixed(2),
          category,
          subcategories[e.subcategoryId] ?? '',
          e.paymentMethod?.label ?? '',
          e.description ?? '',
          events[e.eventId] ?? '',
          e.isForeign ? e.currency : 'INR',
          e.isForeign ? e.originalAmount!.toStringAsFixed(2) : '',
        ]),
      );
    }
    return out.toString();
  }

  /// One row per set, oldest workout first.
  Future<String> workoutsCsv() async {
    final db = await _db.getDatabase();
    final rows = await db.rawQuery('''
      SELECT w.timestamp, w.type, w.notes, e.name, e.muscle_group,
             s.set_number, s.weight, s.reps, s.is_completed
      FROM workouts w
      JOIN exercises e ON e.workout_id = w.id
      JOIN sets s ON s.exercise_id = e.id
      ORDER BY w.timestamp ASC, w.id ASC, e.id ASC, s.set_number ASC
    ''');
    final out = StringBuffer()
      ..writeln(
        csvRow([
          'Date',
          'Workout',
          'Exercise',
          'Muscle group',
          'Set',
          'Weight (kg)',
          'Reps',
          'Done',
          'Notes',
        ]),
      );
    for (final r in rows) {
      final when = DateTime.parse(r['timestamp'] as String);
      out.writeln(
        csvRow([
          _date.format(when),
          _typeName(r['type'] as String),
          r['name'],
          r['muscle_group'],
          r['set_number'],
          r['weight'],
          r['reps'],
          r['is_completed'] == 1 ? 'Yes' : 'No',
          r['notes'] ?? '',
        ]),
      );
    }
    return out.toString();
  }
}

String _typeName(String raw) =>
    raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
