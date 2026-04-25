import 'package:flutter/material.dart';
import 'package:trackit/router.dart';
import 'package:trackit/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:trackit/providers/expense_provider.dart';
import 'package:trackit/providers/workout_provider.dart';
import 'package:trackit/services/notification_service.dart';

import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await DatabaseService.initialize();
  
  // Initialize database before running the app
  await DatabaseService().getDatabase();
  await NotificationService().initialize();
  
  // Schedule a daily check-in reminder (e.g., at 8 PM)
  NotificationService().scheduleDailyReminder(
    id: 1,
    title: "Check-in Reminder",
    body: "Don't forget to log your workouts and expenses today!",
    hour: 20,
    minute: 0,
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'TrackIt',
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}