import 'dart:io';
import 'dart:math';

import '../models/rep_analysis.dart';

class CsvRepAnalysisService {
  // Same parameters as your Python
  static const double thresholdStartDeg = 12.0;
  static const double thresholdStopDeg = 6.0;
  static const double minRepDuration = 0.8;

  // NEW: inclination threshold for warnings
  static const double maxAllowedInclinationDeg = 25.0;

  /// Loads the CSV saved by SetFileWriter
  /// Expected header contains at least:
  /// t_s, gx, gy, gz, inclination_deg
  ///
  /// Detects reps and returns RepAnalysis objects.
  static Future<List<RepAnalysis>> analyzeFile(String csvPath) async {
    final file = File(csvPath);
    if (!await file.exists()) {
      throw Exception("Le fichier n existe pas : $csvPath");
    }

    final lines = await file.readAsLines();
    if (lines.isEmpty) {
      throw Exception("Le CSV est vide");
    }

    final header = lines.first.split(',').map((s) => s.trim()).toList();

    int col(String name) {
      final idx = header.indexOf(name);
      if (idx < 0) throw Exception("Colonne '$name' manquante dans l en-tete CSV.");
      return idx;
    }

    final tIdx = col('t_s');
    final gxIdx = col('gx');
    final gyIdx = col('gy');
    final gzIdx = col('gz');

    // NEW column
    final incIdx = col('inclination_deg');

    // Raw rows
    final t = <double>[];
    final gmagDeg = <double>[]; // gyro magnitude in deg/s
    final inclDeg = <double>[]; // inclination in degrees

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length < header.length) continue;

      final ts = double.tryParse(parts[tIdx]);
      final gxRaw = double.tryParse(parts[gxIdx]);
      final gyRaw = double.tryParse(parts[gyIdx]);
      final gzRaw = double.tryParse(parts[gzIdx]);
      final inc = double.tryParse(parts[incIdx]);

      if (ts == null || gxRaw == null || gyRaw == null || gzRaw == null) continue;

      // Firmware sends centi-deg/s -> convert to deg/s
      final gx = gxRaw / 100.0;
      final gy = gyRaw / 100.0;
      final gz = gzRaw / 100.0;

      final gmag = sqrt(gx * gx + gy * gy + gz * gz);

      t.add(ts);
      gmagDeg.add(gmag);
      inclDeg.add(inc ?? 0.0);
    }

    if (t.length < 2) return [];

    // Detect rep intervals using hysteresis
    final intervals = _detectIntervals(t, gmagDeg);

    // Build RepAnalysis list by slicing each interval
    final reps = <RepAnalysis>[];
    int repNum = 1;

    for (final (startIdx, endIdx) in intervals) {
      final t0 = t[startIdx];
      final t1 = t[endIdx];
      final duration = t1 - t0;
      if (duration < minRepDuration) continue;

      final timeSec = <double>[];
      final velLike = <double>[]; // store gmag (deg/s) in velocityMs

      double maxInclination = 0.0;

      for (int i = startIdx; i <= endIdx; i++) {
        timeSec.add(t[i] - t0);
        velLike.add(gmagDeg[i]);

        final inc = inclDeg[i];
        if (inc > maxInclination) maxInclination = inc;
      }

      // Create a "position" curve by integrating velLike over time (trapezoid)
      final pos = _integrateToPositionCm(timeSec, velLike);

      final peak = velLike.reduce(max);
      final avg = velLike.reduce((a, b) => a + b) / velLike.length;

      final minPos = pos.reduce(min);
      final maxPos = pos.reduce(max);
      final rom = maxPos - minPos;

      reps.add(
        RepAnalysis(
          repNumber: repNum++,
          durationSec: double.parse(duration.toStringAsFixed(2)),
          peakVelocity: double.parse(peak.toStringAsFixed(2)),
          avgVelocity: double.parse(avg.toStringAsFixed(2)),
          rangeOfMotionCm: double.parse(rom.toStringAsFixed(1)),
          timeSec: timeSec,
          positionCm: pos,
          velocityMs: velLike,

          // NEW: you must add this field to RepAnalysis model
          maxInclinationDeg: double.parse(maxInclination.toStringAsFixed(2)),
        ),
      );
    }

    return reps;
  }

  static List<(int, int)> _detectIntervals(List<double> t, List<double> gmag) {
    final out = <(int, int)>[];

    bool inRep = false;
    int startIdx = 0;

    for (int i = 0; i < gmag.length; i++) {
      if (!inRep && gmag[i] > thresholdStartDeg) {
        inRep = true;
        startIdx = i;
      } else if (inRep && gmag[i] < thresholdStopDeg) {
        final endIdx = i;
        final dur = t[endIdx] - t[startIdx];
        if (dur >= minRepDuration) {
          out.add((startIdx, endIdx));
        }
        inRep = false;
      }
    }

    return out;
  }

  static List<double> _integrateToPositionCm(List<double> timeSec, List<double> y) {
    // Trapezoidal integration, then scale to cm-ish for nicer visuals.
    // NOTE: This is not true bar path; it just gives a curve for your existing graph.
    final pos = List<double>.filled(timeSec.length, 0.0);
    for (int i = 1; i < timeSec.length; i++) {
      final dt = timeSec[i] - timeSec[i - 1];
      final area = 0.5 * (y[i] + y[i - 1]) * dt; // deg
      pos[i] = pos[i - 1] + area;
    }

    // Scale down so it doesn't blow up visually
    for (int i = 0; i < pos.length; i++) {
      pos[i] = pos[i] * 0.2;
    }

    return pos;
  }
}
