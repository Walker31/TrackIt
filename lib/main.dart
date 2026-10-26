import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackit/router.dart';
import 'package:trackit/services/app_mode_service.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/providers/app_providers.dart';
import 'package:trackit/services/notification_service.dart';

import 'theme/app_theme.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await DatabaseService.initialize();

  // Initialize database before running the app
  await DatabaseService().getDatabase();
  await AppModeService().load();
  await NotificationService().initialize();

  // Schedule a daily check-in reminder (e.g., at 8 PM)
  NotificationService().scheduleDailyReminder(
    id: 1,
    title: "Check-in Reminder",
    body: "Don't forget to log your workouts and expenses today!",
    hour: 20,
    minute: 0,
  );

  runApp(const ProviderScope(child: App()));
}

Brightness? _lastBrightness;

/// Marks every element dirty so the next frame repaints with the new palette.
void _rebuildAll() {
  void visit(Element element) {
    element.markNeedsBuild();
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}

class App extends ConsumerWidget {
  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final effectiveBrightness = switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
    if (effectiveBrightness != _lastBrightness) {
      final switched = _lastBrightness != null;
      _lastBrightness = effectiveBrightness;
      AppColors.sync(effectiveBrightness);
      // AppColors getters aren't an InheritedWidget, so widgets that read
      // them (and don't depend on Theme) would keep the old palette.
      if (switched) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
      }
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'TrackIt',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: goRouter,
    );
  }
}
