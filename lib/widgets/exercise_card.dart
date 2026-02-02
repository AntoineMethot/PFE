import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/exercise_details.dart';
import '../screens/exercise_details_screen.dart';
import 'muscle_chip.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;

  const ExerciseCard({super.key, required this.exercise});

  // Hardcoded details for now (you can move this to a repository later)
  ExerciseDetails _detailsFor(String id) {
    if (id == 'deadlift') {
      return const ExerciseDetails(
        exerciseId: 'deadlift',
        setupSteps: [
          'Stand with feet hip-width apart, bar over mid-foot',
          'Bend down and grip the bar just outside your legs',
          'Keep your back straight and chest up',
          'Engage your lats and brace your core',
        ],
        executionSteps: [
          'Push through your heels to lift the bar',
          'Keep the bar close to your body',
          'Extend your hips and knees simultaneously',
          'Stand tall at the top, then lower with control',
        ],
      );
    }

    // default for other exercises (placeholder)
    return const ExerciseDetails(
      exerciseId: 'generic',
      setupSteps: [
        'Get into starting position',
        'Brace your core',
      ],
      executionSteps: [
        'Perform the movement with control',
        'Return to start position',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final details = _detailsFor(exercise.id);

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExerciseDetailsScreen(
              exercise: exercise,
              details: details,
              onStart: () {
                // Later: navigate to your "workout / tracking" screen
                Navigator.of(context).pop(); // for now just close details
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              exercise.description,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  exercise.muscles.map((m) => MuscleChip(label: m)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
