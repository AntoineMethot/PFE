import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../widgets/exercise_card.dart';
import '../widgets/app_menu_drawer.dart';

class SelectExerciseScreen extends StatelessWidget {
  const SelectExerciseScreen({super.key});

  static const List<Exercise> exercises = [
    Exercise(
      id: 'bench',
      name: 'Bench Press',
      description:
          'Upper body compound exercise targeting chest, shoulders, and triceps',
      muscles: ['Pectorals', 'Anterior Deltoids', 'Triceps'],
    ),
    Exercise(
      id: 'deadlift',
      name: 'Deadlift',
      description:
          'Full body compound exercise focusing on posterior chain development',
      muscles: ['Hamstrings', 'Glutes', 'Lower Back', 'Traps'],
    ),
    Exercise(
      id: 'squat',
      name: 'Squat',
      description: 'Lower body compound exercise for overall leg development',
      muscles: ['Quadriceps', 'Glutes', 'Hamstrings', 'Core'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      endDrawer: AppMenuDrawer(
        onConnectDevices:
            () => Navigator.of(context).pushNamed('/connect-devices'),
        onSensorData: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Open Sensor Data from Connect Devices after connecting.',
              ),
            ),
          );
        },
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.fitness_center, color: Color(0xFF60A5FA)),
            SizedBox(width: 8),
            Text('LiftTracker'),
          ],
        ),
        actions: [
          Builder(
            builder:
                (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Text(
              'Select Your Exercise',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose an exercise to begin tracking your lift',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            ...exercises.map((e) => ExerciseCard(exercise: e)),
          ],
        ),
      ),
    );
  }
}
