class RepAnalysis {
  final int repNumber;
  final double durationSec;
  final double peakVelocity;
  final double avgVelocity;
  final double rangeOfMotionCm;

  final List<double> timeSec;
  final List<double> positionCm;
  final List<double> velocityMs;

  final double maxInclinationDeg;   // NEW

  RepAnalysis({
    required this.repNumber,
    required this.durationSec,
    required this.peakVelocity,
    required this.avgVelocity,
    required this.rangeOfMotionCm,
    required this.timeSec,
    required this.positionCm,
    required this.velocityMs,
    required this.maxInclinationDeg,
  });
}