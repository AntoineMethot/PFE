import 'package:flutter/material.dart';
import 'screens/select_exercise_screen.dart';
import 'screens/connect_devices_screen.dart';

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
        ConnectDevicesScreen.routeName: (_) => const ConnectDevicesScreen(),
      },
      initialRoute: '/',
    );
  }
}
