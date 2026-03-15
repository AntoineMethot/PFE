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

  static const double _inclinationWarnThreshold = 25.0;

  @override
  Widget build(BuildContext context) {
    final reps = widget.reps;
    final rep = reps[_selectedRepIndex];

    final totalReps = reps.length;
    final avgTime =
        reps.map((r) => r.durationSec).reduce((a, b) => a + b) / totalReps;
    final peakV = reps.map((r) => r.peakVelocity).reduce(max);

    final showInclinationWarning =
        rep.maxInclinationDeg > _inclinationWarnThreshold;

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
            Row(
              children: [
                Expanded(child: _miniStat('Repetitions', '$totalReps')),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat(
                    'Temps moy',
                    '${avgTime.toStringAsFixed(1)} s',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat('Vitesse max', peakV.toStringAsFixed(0)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selectionner rep',
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
                        final hasInclinationWarning =
                            reps[i].maxInclinationDeg >
                            _inclinationWarnThreshold;

                        Color backgroundColor;
                        if (selected) {
                          backgroundColor = const Color(0xFF2563EB);
                        } else if (hasInclinationWarning) {
                          backgroundColor = const Color(0xFFDC2626);
                        } else {
                          backgroundColor = const Color(0xFF1F2937);
                        }

                        return SizedBox(
                          width: 84,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: backgroundColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () =>
                                setState(() => _selectedRepIndex = i),
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
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Donnees rep ${rep.repNumber}',
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
                          'Duree',
                          '${rep.durationSec.toStringAsFixed(2)} s',
                        ),
                      ),
                      Expanded(
                        child: _kv(
                          'Vitesse max',
                          rep.peakVelocity.toStringAsFixed(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _kv(
                          'Vitesse moy',
                          rep.avgVelocity.toStringAsFixed(1),
                        ),
                      ),
                      Expanded(
                        child: _kv(
                          'Amplitude',
                          '${rep.rangeOfMotionCm.toStringAsFixed(0)} cm',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _kv(
                          'Inclinaison max',
                          '${rep.maxInclinationDeg.toStringAsFixed(1)} deg',
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
            if (showInclinationWarning) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B0B0B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Inclinaison depassee 25 deg (${rep.maxInclinationDeg.toStringAsFixed(1)} deg).\n'
                        'Essayez de garder la barre/le clip plus horizontal pendant la repetition.',
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
}