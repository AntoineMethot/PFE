import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class RepInterval {
  final int repNumber;
  final double startTime;
  final double endTime;
  final double duration;

  RepInterval({
    required this.repNumber,
    required this.startTime,
    required this.endTime,
    required this.duration,
  });
}

class AnalysisFromCsvScreen extends StatefulWidget {
  const AnalysisFromCsvScreen({
    super.key,
    required this.csvPath,
  });

  final String csvPath;

  @override
  State<AnalysisFromCsvScreen> createState() => _AnalysisFromCsvScreenState();
}

class _AnalysisFromCsvScreenState extends State<AnalysisFromCsvScreen> {
  // ---- Same parameters as your Python script ----
  static const double thresholdStartDeg = 12.0; // start when gmag > this  :contentReference[oaicite:1]{index=1}
  static const double thresholdStopDeg = 6.0;   // stop  when gmag < this  :contentReference[oaicite:2]{index=2}
  static const double minRepDuration = 0.8;     // seconds                :contentReference[oaicite:3]{index=3}

  bool _loading = true;
  String? _error;

  List<RepInterval> _reps = [];
  int _sampleCount = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
      _reps = [];
      _sampleCount = 0;
    });

    try {
      final file = File(widget.csvPath);
      if (!await file.exists()) {
        throw Exception("File does not exist:\n${widget.csvPath}");
      }

      final lines = await file.readAsLines();
      if (lines.isEmpty) {
        throw Exception("CSV is empty.");
      }

      // Expect header: t_s,seq,ax,ay,az,gx,gy,gz
      // We'll be tolerant: find column indices by header names.
      final header = lines.first.split(',').map((s) => s.trim()).toList();

      int col(String name) {
        final idx = header.indexOf(name);
        if (idx < 0) throw Exception("Missing column '$name' in CSV header.");
        return idx;
      }

      final tIdx = col('t_s');
      final gxIdx = col('gx');
      final gyIdx = col('gy');
      final gzIdx = col('gz');

      final rows = <({double t, double gxDeg, double gyDeg, double gzDeg})>[];

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(',');
        if (parts.length < header.length) continue;

        final t = double.tryParse(parts[tIdx]) ?? double.nan;
        final gxRaw = double.tryParse(parts[gxIdx]) ?? double.nan;
        final gyRaw = double.tryParse(parts[gyIdx]) ?? double.nan;
        final gzRaw = double.tryParse(parts[gzIdx]) ?? double.nan;

        if (t.isNaN || gxRaw.isNaN || gyRaw.isNaN || gzRaw.isNaN) continue;

        // Your firmware: gyro is centi-deg/s => convert to deg/s
        final gxDeg = gxRaw / 100.0;
        final gyDeg = gyRaw / 100.0;
        final gzDeg = gzRaw / 100.0;

        rows.add((t: t, gxDeg: gxDeg, gyDeg: gyDeg, gzDeg: gzDeg));
      }

      _sampleCount = rows.length;

      final reps = _detectReps(rows);

      setState(() {
        _reps = reps;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "$e";
        _loading = false;
      });
    }
  }

  // Port of your Python hysteresis rep detection  :contentReference[oaicite:4]{index=4}
  List<RepInterval> _detectReps(
    List<({double t, double gxDeg, double gyDeg, double gzDeg})> data,
  ) {
    final reps = <RepInterval>[];

    bool inRep = false;
    double repStart = 0;

    for (final row in data) {
      final t = row.t;
      final gmag = sqrt(
        row.gxDeg * row.gxDeg +
            row.gyDeg * row.gyDeg +
            row.gzDeg * row.gzDeg,
      );

      if (!inRep && gmag > thresholdStartDeg) {
        inRep = true;
        repStart = t;
      } else if (inRep && gmag < thresholdStopDeg) {
        final repEnd = t;
        final dur = repEnd - repStart;

        if (dur >= minRepDuration) {
          reps.add(
            RepInterval(
              repNumber: reps.length + 1,
              startTime: repStart,
              endTime: repEnd,
              duration: dur,
            ),
          );
        }

        inRep = false;
      }
    }

    return reps;
  }

  String _fmt(double x, {int digits = 3}) => x.toStringAsFixed(digits);

  @override
  Widget build(BuildContext context) {
    final name = p.basename(widget.csvPath);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Analysis: $name'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _run,
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Summary',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Samples: $_sampleCount\nDetected reps: ${_reps.length}',
                              style: const TextStyle(color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Thresholds (deg/s): start > $thresholdStartDeg, stop < $thresholdStopDeg\nMin duration: ${minRepDuration}s',
                              style: const TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_reps.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Text(
                            'No reps detected. (We can tune thresholds next.)',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      else
                        ..._reps.map((r) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${r.repNumber}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Duration: ${_fmt(r.duration, digits: 2)} s',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Start: ${_fmt(r.startTime)}  •  End: ${_fmt(r.endTime)}',
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}