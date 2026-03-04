import 'package:flutter/material.dart';
import 'screens/select_exercise_screen.dart';
import 'screens/connect_devices_screen.dart';
import '../screens/saved_sets_screen.dart';

void main() {
  runApp(const LiftTrackerApp());
}

class LiftTrackerApp extends StatelessWidget {
  const LiftTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LiftTracker',
      theme: ThemeData.dark(useMaterial3: true),
      routes: {
        '/': (_) => const SelectExerciseScreen(),
        '/connect-devices': (_) => const ConnectDevicesScreen(),
        SavedSetsScreen.routeName: (_) => const SavedSetsScreen(),
      },
      initialRoute: '/',
    );
  }
}
