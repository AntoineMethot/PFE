import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/exercise_analysis_screen.dart';
import '../models/rep_analysis.dart';
import 'dart:math';

class WorkoutProgressScreen extends StatefulWidget {
  const WorkoutProgressScreen({
    super.key,
    required this.exerciseName,
    this.targetReps = 5,
  });

  final String exerciseName;
  final int targetReps;

  @override
  State<WorkoutProgressScreen> createState() => _WorkoutProgressScreenState();
}

class _WorkoutProgressScreenState extends State<WorkoutProgressScreen> {
  // Fake demo values (replace later with real sensor algorithm outputs)
  int repsCompleted = 1;
  double lastRepDurationSec = 3.0;
  double avgVelocity = 6.5;

  Timer? _demoTimer;

  @override
  void initState() {
    super.initState();

    // Demo: every 4 seconds, add a rep until target (for UI testing)
    _demoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;

      if (repsCompleted < widget.targetReps) {
        setState(() {
          repsCompleted += 1;
          lastRepDurationSec = 2.5 + (repsCompleted * 0.1);
          avgVelocity = 6.5 - (repsCompleted * 0.2);
        });
      }

      if (repsCompleted >= widget.targetReps) {
        _demoTimer?.cancel();

        final reps = _fakeRepAnalyses(widget.targetReps);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => ExerciseAnalysisScreen(
                  exerciseName: widget.exerciseName,
                  reps: reps,
                ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (repsCompleted / widget.targetReps).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar: title + X
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.exerciseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Recording card
                _RecordingCard(repsCompleted: repsCompleted),

                const SizedBox(height: 18),

                // Stats card with progress bar + last rep duration + avg velocity
                _ProgressStatsCard(
                  repsCompleted: repsCompleted,
                  targetReps: widget.targetReps,
                  progress: progress,
                  lastRepDurationSec: lastRepDurationSec,
                  avgVelocity: avgVelocity,
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<RepAnalysis> _fakeRepAnalyses(int n) {
    // Creates simple V-shape position + derived-ish velocity for UI testing
    List<RepAnalysis> reps = [];

    for (int rep = 1; rep <= n; rep++) {
      final duration = 2.5 + rep * 0.1; // seconds
      final samples = 60;
      final t = List<double>.generate(
        samples,
        (i) => i * duration / (samples - 1),
      );

      // position: down then up (V shape)
      final pos =
          t.map((time) {
            final x = time / duration; // 0..1
            final v = (x <= 0.5) ? (1 - 2 * x) : (2 * x - 1); // 1..0..1
            // scale to 100cm ROM-ish and offset
            return 100 * (1 - v); // 0..100..0 flipped-ish
          }).toList();

      // crude velocity: finite difference
      final vel = List<double>.filled(samples, 0);
      for (int i = 1; i < samples; i++) {
        vel[i] =
            (pos[i] - pos[i - 1]) /
            (t[i] - t[i - 1]) /
            100.0; // convert cm/s to m/s
      }

      final peakV =
          vel.map((e) => e.abs()).reduce(max) +
          18; // make it look like your screenshot
      final avgV =
          vel.map((e) => e.abs()).reduce((a, b) => a + b) / samples + 6;

      reps.add(
        RepAnalysis(
          repNumber: rep,
          durationSec: double.parse(duration.toStringAsFixed(2)),
          peakVelocity: double.parse(peakV.toStringAsFixed(1)),
          avgVelocity: double.parse(avgV.toStringAsFixed(1)),
          rangeOfMotionCm: 100,
          timeSec: t,
          positionCm: pos,
          velocityMs:
              vel.map((e) => e.abs() + 6).toList(), // make it positive-looking
        ),
      );
    }

    return reps;
  }
}

class _RecordingCard extends StatelessWidget {
  final int repsCompleted;
  const _RecordingCard({required this.repsCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.show_chart, color: Color(0xFF22C55E)),
              SizedBox(width: 10),
              Text(
                'Recording',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$repsCompleted',
            style: const TextStyle(
              color: Color(0xFF60A5FA),
              fontSize: 64,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Reps Completed',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ProgressStatsCard extends StatelessWidget {
  final int repsCompleted;
  final int targetReps;
  final double progress;
  final double lastRepDurationSec;
  final double avgVelocity;

  const _ProgressStatsCard({
    required this.repsCompleted,
    required this.targetReps,
    required this.progress,
    required this.lastRepDurationSec,
    required this.avgVelocity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress row
          Row(
            children: [
              const Text(
                'Progress',
                style: TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$repsCompleted/$targetReps reps',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFF0B1220),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF60A5FA)),
            ),
          ),

          const SizedBox(height: 18),
          const Divider(color: Colors.white10, height: 1),

          const SizedBox(height: 18),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  title: 'Last Rep Duration',
                  value: '${lastRepDurationSec.toStringAsFixed(1)}s',
                ),
              ),
              Expanded(
                child: _StatBlock(
                  title: 'Avg Velocity',
                  value: '${avgVelocity.toStringAsFixed(1)} m/s',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String title;
  final String value;

  const _StatBlock({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
