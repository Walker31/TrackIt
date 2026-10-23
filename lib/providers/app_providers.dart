import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'expense_provider.dart';
import 'workout_provider.dart';
import 'group_provider.dart';
import 'auth_provider.dart';

// Rebuilt when the auth/mode status changes (login, logout, switching to
// local mode) so the first refresh after the change triggers a sync.
final expenseProviderProvider = ChangeNotifierProvider<ExpenseProvider>((ref) {
  ref.watch(authProvider.select((n) => n.state.status));
  return ExpenseProvider();
});

final workoutProviderProvider = ChangeNotifierProvider<WorkoutProvider>((ref) {
  ref.watch(authProvider.select((n) => n.state.status));
  return WorkoutProvider();
});

final groupProviderProvider = ChangeNotifierProvider<GroupProvider>((ref) {
  final authState = ref.watch(authProvider).state;
  final user = authState.user;
  return GroupProvider(
    currentUserId: user?['id'] as int?,
    currentUsername: user?['username'] as String?,
  );
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
