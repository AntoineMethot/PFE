import 'dart:async';
import 'package:flutter/material.dart';

import '../services/ble_manager.dart';
import '../services/ble_imu_stream.dart';
import '../services/file_share_service.dart';
import '../services/set_file_writer.dart';
import '../screens/exercise_analysis_screen.dart';
import '../services/csv_rep_analysis_service.dart';

class WorkoutProgressScreen extends StatefulWidget {
  const WorkoutProgressScreen({super.key, required this.exerciseName});

  final String exerciseName;

  @override
  State<WorkoutProgressScreen> createState() => _WorkoutProgressScreenState();
}

class _WorkoutProgressScreenState extends State<WorkoutProgressScreen> {
  Timer? _timer;
  int _elapsedMs = 0;

  bool _starting = true;
  bool _stopping = false;

  String? _lastSavedCsvPath;
  String? _status;
  int _sampleCount = 0;

  StreamSubscription? _sampleSub;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    if (BleManager.I.device == null || !BleManager.I.isConnected) {
      setState(() {
        _starting = false;
        _status =
            "Aucun appareil BLE connecte. Ouvrez d abord Connexion des appareils.";
      });
      return;
    }

    try {
      // Start BLE streaming + notifications (0x01) and clear internal buffer
      await BleImuStream.I.start(sendStartCommand: true);

      // Track sample count (handy for debugging)
      await _sampleSub?.cancel();
      _sampleSub = BleImuStream.I.samplesStream.listen((_) {
        if (!mounted) return;
        setState(() => _sampleCount = BleImuStream.I.buffer.length);
      });

      // Timer UI
      _elapsedMs = 0;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        setState(() => _elapsedMs += 100);
      });

      setState(() {
        _starting = false;
        _stopping = false;
        _status = null;
        _lastSavedCsvPath = null;
      });
    } catch (e) {
      setState(() {
        _starting = false;
        _status = "Echec du demarrage : $e";
      });
    }
  }

  Future<void> _stopAndSave() async {
    if (_stopping || _starting) return;

    setState(() {
      _stopping = true;
      _status = "Arret et sauvegarde...";
    });

    _timer?.cancel();
    _timer = null;

    try {
      await _sampleSub?.cancel();
      _sampleSub = null;

      // Stop notifications + send 0x00
      await BleImuStream.I.stop(sendStopCommand: true);

      // Save buffered samples to Documents/sets/*.csv
      final file = await SetFileWriter.writeCsv(
        exerciseName: widget.exerciseName,
        samples: BleImuStream.I.buffer,
      );

      _lastSavedCsvPath = file.path;

      if (!mounted) return;
      setState(() {
        _stopping = false;
        _status =
            "${BleImuStream.I.buffer.length} echantillons sauvegardes :\n${file.path}";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stopping = false;
        _status = "Echec arret/sauvegarde : $e";
      });
    }
  }

  Future<void> _shareLastCsv() async {
    final path = _lastSavedCsvPath;
    if (path == null) return;

    try {
      await FileShareService.shareCsvFile(
        path,
        context: context,
        text: 'Export CSV - ${widget.exerciseName}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Echec du partage du CSV : $e')));
    }
  }

  // 2) Replace your current _openAnalysis() with this one
  Future<void> _openAnalysis() async {
    final path = _lastSavedCsvPath;
    if (path == null) return;

    try {
      setState(() => _status = "Analyse du CSV...");

      final reps = await CsvRepAnalysisService.analyzeFile(path);

      if (!mounted) return;

      if (reps.isEmpty) {
        setState(
          () =>
              _status =
                  "Aucune repetition detectee (essayez de baisser les seuils).",
        );
        return;
      }

      // Clear status (optional)
      setState(() => _status = null);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => ExerciseAnalysisScreen(
                exerciseName: widget.exerciseName,
                reps: reps,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = "Echec de l analyse : $e");
    }
  }

  String _formatTime(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sampleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(_elapsedMs);

    final canStop = !_starting && !_stopping;
    final canAnalyze = _lastSavedCsvPath != null && !_starting && !_stopping;
    final canShare = _lastSavedCsvPath != null && !_starting && !_stopping;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.exerciseName),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
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
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.show_chart,
                    color: Color(0xFF22C55E),
                    size: 36,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    _starting
                        ? "Demarrage BLE..."
                        : _stopping
                        ? "Arret..."
                        : "Echantillons : $_sampleCount",
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 16,
                    ),
                  ),

                  if (_status != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _status!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: canStop ? _stopAndSave : null,
                      icon: const Icon(Icons.stop),
                      label: const Text(
                        "Arreter et sauvegarder",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: canShare ? _shareLastCsv : null,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text(
                        "Telecharger le CSV",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: canAnalyze ? _openAnalysis : null,
                      icon: const Icon(Icons.analytics),
                      label: const Text(
                        "Voir l analyse",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
