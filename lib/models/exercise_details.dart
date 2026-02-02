class ExerciseDetails {
  final String exerciseId;
  final List<String> setupSteps;
  final List<String> executionSteps;

  const ExerciseDetails({
    required this.exerciseId,
    required this.setupSteps,
    required this.executionSteps,
  });
}
