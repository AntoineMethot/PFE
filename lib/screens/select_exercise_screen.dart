import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../widgets/exercise_card.dart';
import '../widgets/app_menu_drawer.dart';
import '../screens/saved_sets_screen.dart';

class SelectExerciseScreen extends StatelessWidget {
  const SelectExerciseScreen({super.key});

  static const List<Exercise> exercises = [
    Exercise(
      id: 'bench',
      name: 'Developpe couche',
      description:
          'Exercice polyarticulaire du haut du corps ciblant les pectoraux, les epaules et les triceps',
      muscles: ['Pectoraux', 'Deltoides anterieurs', 'Triceps'],
    ),
    Exercise(
      id: 'deadlift',
      name: 'Souleve de terre',
      description:
          'Exercice polyarticulaire complet axe sur le developpement de la chaine posterieure',
      muscles: ['Ischio-jambiers', 'Fessiers', 'Bas du dos', 'Trapezes'],
    ),
    Exercise(
      id: 'squat',
      name: 'Squat',
      description: 'Exercice polyarticulaire du bas du corps pour le developpement global des jambes',
      muscles: ['Quadriceps', 'Fessiers', 'Ischio-jambiers', 'Sangle abdominale'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),

      // Hamburger menu drawer (right side, since you use endDrawer)
      endDrawer: AppMenuDrawer(
        onConnectDevices: () => Navigator.of(context).pushNamed('/connect-devices'),
        onSensorData: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ouvrez Donnees capteur depuis Connexion des appareils apres connexion.',
              ),
            ),
          );
        },
        onSavedSets: () {
          Navigator.of(context).pushNamed(SavedSetsScreen.routeName);
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
            builder: (context) => IconButton(
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
              'Choisissez votre exercice',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choisissez un exercice pour commencer le suivi',
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
