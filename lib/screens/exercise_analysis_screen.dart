import 'dart:math';
import 'package:flutter/material.dart';
import '../models/rep_analysis.dart';

class ExerciseAnalysisScreen extends StatefulWidget {
  const ExerciseAnalysisScreen({
    super.key,
    required this.exerciseName,
    required this.reps,
  });

  final String exerciseName;
  final List<RepAnalysis> reps;

  @override
  State<ExerciseAnalysisScreen> createState() => _ExerciseAnalysisScreenState();
}

class _ExerciseAnalysisScreenState extends State<ExerciseAnalysisScreen> {
  int _selectedRepIndex = 0;

  @override
  Widget build(BuildContext context) {
    final reps = widget.reps;
    final rep = reps[_selectedRepIndex];

    final totalReps = reps.length;
    final avgTime =
        reps.map((r) => r.durationSec).reduce((a, b) => a + b) / totalReps;
    final peakV = reps.map((r) => r.peakVelocity).reduce(max);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.exerciseName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
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
            // Summary tiles
            Row(
              children: [
                Expanded(child: _miniStat('Total Reps', '$totalReps')),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat(
                    'Avg Time',
                    '${avgTime.toStringAsFixed(1)}s',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _miniStat('Peak V', peakV.toStringAsFixed(0))),
              ],
            ),

            const SizedBox(height: 14),

            // Select rep card
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Rep',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: reps.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final selected = i == _selectedRepIndex;
                        return SizedBox(
                          width: 84,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  selected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF1F2937),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                () => setState(() => _selectedRepIndex = i),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Rep analysis card (ONLY ONE GRAPH: bar path / position)
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rep ${rep.repNumber} Analysis',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bar Path (Position)',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 220,
                    child: _LineChart(
                      x: rep.timeSec,
                      y: rep.positionCm,
                      yLabel: 'Position (cm)',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Rep data
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rep ${rep.repNumber} Data',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _kv(
                          'Duration',
                          '${rep.durationSec.toStringAsFixed(2)}s',
                        ),
                      ),
                      Expanded(
                        child: _kv(
                          'Peak Velocity',
                          '${rep.peakVelocity.toStringAsFixed(1)} m/s',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _kv(
                          'Avg Velocity',
                          '${rep.avgVelocity.toStringAsFixed(1)} m/s',
                        ),
                      ),
                      Expanded(
                        child: _kv(
                          'Range of Motion',
                          '${rep.rangeOfMotionCm.toStringAsFixed(0)} cm',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Recommendations
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommendations',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _recCard(
                    icon: Icons.check_circle,
                    iconColor: const Color(0xFF22C55E),
                    bg: const Color(0xFF0B3B2B),
                    text: 'Great velocity maintenance throughout the set!',
                    textColor: const Color(0xFFBBF7D0),
                  ),
                  const SizedBox(height: 10),
                  _recCard(
                    icon: Icons.info,
                    iconColor: const Color(0xFFFACC15),
                    bg: const Color(0xFF3B2D0B),
                    text:
                        'Inconsistent rep tempo. Focus on controlled, steady movement.',
                    textColor: const Color(0xFFFDE68A),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recCard({
    required IconData icon,
    required Color iconColor,
    required Color bg,
    required String text,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple chart painter (no external libs)
class _LineChart extends StatelessWidget {
  final List<double> x;
  final List<double> y;
  final String yLabel;

  const _LineChart({required this.x, required this.y, required this.yLabel});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(x: x, y: y, yLabel: yLabel),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> x;
  final List<double> y;
  final String yLabel;

  _LineChartPainter({required this.x, required this.y, required this.yLabel});

  @override
  void paint(Canvas canvas, Size size) {
    final plotPadding = const EdgeInsets.fromLTRB(40, 14, 12, 26);
    final rect = Rect.fromLTWH(
      plotPadding.left,
      plotPadding.top,
      size.width - plotPadding.left - plotPadding.right,
      size.height - plotPadding.top - plotPadding.bottom,
    );

    final bg = Paint()..color = const Color(0xFF0B1220);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      bg,
    );

    if (x.isEmpty || y.isEmpty || x.length != y.length) return;

    final minX = x.reduce(min);
    final maxX = x.reduce(max);
    final minY = y.reduce(min);
    final maxY = y.reduce(max);

    double sx(double v) =>
        rect.left +
        (v - minX) / ((maxX - minX) == 0 ? 1 : (maxX - minX)) * rect.width;
    double sy(double v) =>
        rect.bottom -
        (v - minY) / ((maxY - minY) == 0 ? 1 : (maxY - minY)) * rect.height;

    // Grid
    final gridPaint =
        Paint()
          ..color = Colors.white10
          ..strokeWidth = 1;

    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final yLine = rect.top + rect.height * i / gridLines;
      canvas.drawLine(
        Offset(rect.left, yLine),
        Offset(rect.right, yLine),
        gridPaint,
      );
    }
    for (int i = 0; i <= gridLines; i++) {
      final xLine = rect.left + rect.width * i / gridLines;
      canvas.drawLine(
        Offset(xLine, rect.top),
        Offset(xLine, rect.bottom),
        gridPaint,
      );
    }

    // Line
    final line =
        Paint()
          ..color = const Color(0xFF60A5FA)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(sx(x[0]), sy(y[0]));
    for (int i = 1; i < x.length; i++) {
      path.lineTo(sx(x[i]), sy(y[i]));
    }
    canvas.drawPath(path, line);

    // Label
    final tp = TextPainter(textDirection: TextDirection.ltr);

    tp.text = TextSpan(
      text: yLabel,
      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
    );
    tp.layout(maxWidth: 120);
    tp.paint(canvas, Offset(8, rect.top + rect.height / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
