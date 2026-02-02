class RepAnalysis {
  final int repNumber;

  // Stats
  final double durationSec;
  final double peakVelocity; // m/s
  final double avgVelocity;  // m/s
  final double rangeOfMotionCm;

  // Series for plotting
  final List<double> timeSec;
  final List<double> positionCm;
  final List<double> velocityMs;

  const RepAnalysis({
    required this.repNumber,
    required this.durationSec,
    required this.peakVelocity,
    required this.avgVelocity,
    required this.rangeOfMotionCm,
    required this.timeSec,
    required this.positionCm,
    required this.velocityMs,
  });
}
