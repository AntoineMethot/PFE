import 'dart:math';
import 'package:flutter/material.dart';

import '../models/rep_analysis.dart';

class ViewAnalysisScreen extends StatefulWidget {
  final List<RepAnalysis> reps;
  final String title;

  const ViewAnalysisScreen({super.key, required this.reps, this.title = 'View Analysis'});

  @override
  State<ViewAnalysisScreen> createState() => _ViewAnalysisScreenState();
}

class _ViewAnalysisScreenState extends State<ViewAnalysisScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final reps = widget.reps;
    final rep = reps.isNotEmpty ? reps[_selected] : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bar Path', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              if (reps.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text('No recorded reps to display', style: TextStyle(color: Color(0xFF94A3B8))),
                )
              else ...[
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: reps.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final selected = i == _selected;
                      return SizedBox(
                        width: 64,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selected ? const Color(0xFF2563EB) : const Color(0xFF1F2937),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => setState(() => _selected = i),
                          child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: _BarPathChart(
                    x: rep!.timeSec,
                    y: rep.positionCm,
                    yLabel: 'Position (cm)',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple chart painter (adapted from project style)
class _BarPathChart extends StatelessWidget {
  final List<double> x;
  final List<double> y;
  final String yLabel;

  const _BarPathChart({required this.x, required this.y, required this.yLabel});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarPathPainter(x: x, y: y, yLabel: yLabel),
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

class _BarPathPainter extends CustomPainter {
  final List<double> x;
  final List<double> y;
  final String yLabel;

  _BarPathPainter({required this.x, required this.y, required this.yLabel});

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
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), bg);

    if (x.isEmpty || y.isEmpty || x.length != y.length) return;

    final minX = x.reduce(min);
    final maxX = x.reduce(max);
    final minY = y.reduce(min);
    final maxY = y.reduce(max);

    double sx(double v) => rect.left + (v - minX) / ((maxX - minX) == 0 ? 1 : (maxX - minX)) * rect.width;
    double sy(double v) => rect.bottom - (v - minY) / ((maxY - minY) == 0 ? 1 : (maxY - minY)) * rect.height;

    // Grid
    final gridPaint = Paint()..color = Colors.white10..strokeWidth = 1;
    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final yLine = rect.top + rect.height * i / gridLines;
      canvas.drawLine(Offset(rect.left, yLine), Offset(rect.right, yLine), gridPaint);
    }
    for (int i = 0; i <= gridLines; i++) {
      final xLine = rect.left + rect.width * i / gridLines;
      canvas.drawLine(Offset(xLine, rect.top), Offset(xLine, rect.bottom), gridPaint);
    }

    // Line
    final line = Paint()..color = const Color(0xFF60A5FA)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final path = Path()..moveTo(sx(x[0]), sy(y[0]));
    for (int i = 1; i < x.length; i++) {
      path.lineTo(sx(x[i]), sy(y[i]));
    }
    canvas.drawPath(path, line);

    // Label
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(text: yLabel, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11));
    tp.layout(maxWidth: 120);
    tp.paint(canvas, Offset(8, rect.top + rect.height / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
