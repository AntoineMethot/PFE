import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/rep_analysis.dart';
import 'view_analysis_screen.dart';

class SensorDataScreen extends StatefulWidget {
  const SensorDataScreen({
    super.key,
    required this.device,
    required this.imuDataCharacteristicUuid,
    required this.imuServiceUuid,
  });

  /// Connected device
  final BluetoothDevice device;

  /// Service UUID that contains the notify characteristic
  final Guid imuServiceUuid;

  /// Notify characteristic UUID for the 14-byte IMU packets
  final Guid imuDataCharacteristicUuid;

  @override
  State<SensorDataScreen> createState() => _SensorDataScreenState();
}

class _SensorDataScreenState extends State<SensorDataScreen> {
  BluetoothCharacteristic? _imuChar;
  StreamSubscription<List<int>>? _notifySub;

  bool _subscribed = false;
  String? _error;

  // Latest parsed values
  int seq = 0;
  int ax = 0, ay = 0, az = 0;
  int gx = 0, gy = 0, gz = 0;

  // Processing state (physical units)
  double _lastTs = 0.0; // seconds
  double _gravityX = 0.0, _gravityY = 0.0, _gravityZ = 0.0;

  // Integrated state (meters / m/s)
  double _velX = 0.0; // m/s
  double _posX = 0.0; // meters
  double _velY = 0.0; // m/s (for reps)
  double _posY = 0.0; // meters (for reps)

  // Inclination (degrees) computed from gravity vector (X axis)
  double _inclinationDeg = 0.0;

  // Detection thresholds and buffers
  final double _accelLsbPerG = 16384.0; // default sensor scale (LSB per g)
  final double _g = 9.80665;

  // Raw-peak based rep detection (raw int16 on Y axis)
  final int _posPeakRaw = 4000; // example positive peak threshold
  final int _negPeakRaw = -5000; // example negative peak threshold
  int _lastPeakSign = 0; // -1, 0, +1
  double _lastPeakTs = 0.0;
  final double _minPeakInterval = 0.08; // seconds between opposite peaks
  // Gyro-based peak detection (use gy)
  final int _posGyPeakRaw = 300; // example positive gyro threshold
  final int _negGyPeakRaw = -300; // example negative gyro threshold

  // Movement detection
  bool _inMotion = false;
  double _motionStartTs = 0.0;
  double _lastMotionEndTs = 0.0;
  int _repCount = 0;
  int _setCount = 0;

  // Debug / drift handling
  bool _debug = true;
  int _logCounter = 0;
  double _idleStart = 0.0;
  
  // Use Y axis for reps by default
  final bool _useYAxisForReps = true;

  // Buffers for current rep
  final List<double> _curTimes = [];
  final List<double> _curPositions = [];
  final List<double> _curVelocities = [];

  // Collected reps
  final List<RepAnalysis> _reps = [];
  // Reps specifically recorded for analysis (start/stop)
  final List<RepAnalysis> _recordedReps = [];

  bool _recording = false;

  // Parameters
  final double _startThreshold = 0.6; // m/s^2
  final double _endThreshold = 0.3; // m/s^2
  final double _minRepDisplacementCm = 2.0; // cm
  final double _setIdleSeconds = 3.0; // seconds to consider a new set

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    _setNotify(false);
    super.dispose();
  }

  Future<void> _setupNotifications() async {
    try {
      // Discover services/characteristics (must be connected)
      final services = await widget.device.discoverServices();

      final imuService = services.firstWhere(
        (s) => s.uuid == widget.imuServiceUuid,
        orElse: () => throw Exception('IMU service not found: ${widget.imuServiceUuid}'),
      );

      final imuChar = imuService.characteristics.firstWhere(
        (c) => c.uuid == widget.imuDataCharacteristicUuid,
        orElse: () => throw Exception('IMU characteristic not found: ${widget.imuDataCharacteristicUuid}'),
      );

      _imuChar = imuChar;

      await _setNotify(true);

      // Listen to incoming notifications
      _notifySub = imuChar.onValueReceived.listen((data) {
        if (data.length != 14) return; // ignore unexpected packets
        final p = _parsePacket14(data);
        if (!mounted) return;
        // Update raw values immediately
        seq = p.seq;
        ax = p.ax; ay = p.ay; az = p.az;
        gx = p.gx; gy = p.gy; gz = p.gz;

        // Process packet (timestamps and integration)
        _processImuPacket(p);

        if (!mounted) return;
        setState(() {});
      });

      // Optional: auto-cancel when device disconnects
      widget.device.cancelWhenDisconnected(_notifySub!);

      if (!mounted) return;
      setState(() {
        _subscribed = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _subscribed = false;
      });
    }
  }

  Future<void> _setNotify(bool enabled) async {
    final c = _imuChar;
    if (c == null) return;
    try {
      await c.setNotifyValue(enabled);
    } catch (_) {
      // some platforms throw if already set; ignore
    }
  }

  /// Packet: [0..1]=uint16 seq, then 6x int16: ax ay az gx gy gz (little-endian)
  ImuPacket _parsePacket14(List<int> bytes) {
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));

    // seq as unsigned 16
    final seq = bd.getUint16(0, Endian.little);

    final ax = bd.getInt16(2, Endian.little);
    final ay = bd.getInt16(4, Endian.little);
    final az = bd.getInt16(6, Endian.little);

    final gx = bd.getInt16(8, Endian.little);
    final gy = bd.getInt16(10, Endian.little);
    final gz = bd.getInt16(12, Endian.little);

    return ImuPacket(seq: seq, ax: ax, ay: ay, az: az, gx: gx, gy: gy, gz: gz);
  }

  // Basic processing pipeline: convert raw -> m/s^2, remove gravity via LPF,
  // integrate to velocity and position on X axis, detect reps/sets.
  void _processImuPacket(ImuPacket p) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    // convert raw int16 to m/s^2 (all axes)
    final axMs2 = p.ax / _accelLsbPerG * _g;
    final ayMs2 = p.ay / _accelLsbPerG * _g;
    final azMs2 = p.az / _accelLsbPerG * _g;

    if (_lastTs == 0.0) {
      // initialize gravity estimate to first sample
      _gravityX = axMs2;
      _lastTs = now;
      return;
    }

    double dt = now - _lastTs;
    if (dt <= 0) dt = 0.001;
    if (dt > 0.5) dt = 0.02; // clamp very large gaps

    // low-pass for gravity estimate (time constant tau) - update all axes
    const double tau = 0.5; // seconds
    final alpha = tau / (tau + dt);
    _gravityX = alpha * _gravityX + (1 - alpha) * axMs2;
    _gravityY = alpha * _gravityY + (1 - alpha) * ayMs2;
    _gravityZ = alpha * _gravityZ + (1 - alpha) * azMs2;

    final linearY = ayMs2 - _gravityY; // m/s^2 (approx) - used for reps

    // integrate on Y for reps
    _velY += linearY * dt;
    _posY += _velY * dt;

    // movement magnitude (use Y for reps)
    final mag = linearY.abs();

    // inclination from gravity vector (use X component to compute tilt)
    final denom = sqrt(_gravityY * _gravityY + _gravityZ * _gravityZ);
    if (denom > 1e-6) {
      _inclinationDeg = atan2(_gravityX, denom) * 180.0 / pi;
    }

    // --- Peak-based rep detection on gyro Y (gy) ---
    final gyRaw = p.gy;
    int sign = 0;
    if (gyRaw >= _posGyPeakRaw) sign = 1;
    if (gyRaw <= _negGyPeakRaw) sign = -1;

    if (sign != 0) {
      if (_debug) print('Peak detected gy=$gyRaw sign=$sign lastPeakSign=$_lastPeakSign');
      // if we weren't already in motion, start collecting
      if (!_inMotion) {
        _inMotion = true;
        _motionStartTs = now;
        _curTimes.clear();
        _curPositions.clear();
        _curVelocities.clear();
      }

      // if we see an opposite-sign peak after a previous peak, count a rep
      if (_lastPeakSign != 0 && _lastPeakSign == -sign) {
        final gap = now - _lastPeakTs;
        if (_debug) print('Peak pair candidate gap=${gap.toStringAsFixed(3)}s');
        if (gap >= _minPeakInterval) {
          // finalize rep using buffers
          if (_curTimes.isNotEmpty) {
            if (_debug) print('Buffers samples=${_curTimes.length}');
            final minP = _curPositions.reduce((a, b) => a < b ? a : b);
            final maxP = _curPositions.reduce((a, b) => a > b ? a : b);
            final rangeCm = (maxP - minP).abs();
            if (_debug) print('RangeCm=${rangeCm.toStringAsFixed(2)}');
            if (rangeCm >= _minRepDisplacementCm && _curTimes.length >= 3) {
              final duration = _curTimes.last - _curTimes.first;
              final peakV = _curVelocities.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
              final avgV = _curVelocities.map((v) => v.abs()).reduce((a, b) => a + b) / _curVelocities.length;

              _repCount += 1;
              final rep = RepAnalysis(
                repNumber: _repCount,
                durationSec: duration,
                peakVelocity: peakV,
                avgVelocity: avgV,
                rangeOfMotionCm: rangeCm,
                timeSec: List.of(_curTimes),
                positionCm: List.of(_curPositions),
                velocityMs: List.of(_curVelocities),
              );

              _reps.add(rep);
              if (_recording) {
                _recordedReps.add(rep);
                if (_debug) print('Added to recordedReps (#${_recordedReps.length})');
              } else {
                if (_debug) print('Recorded is false; rep stored in _reps only');
              }
              if (_debug) print('Rep (peak pair) #${_repCount}: dur=${duration.toStringAsFixed(3)}s ROM=${rangeCm.toStringAsFixed(2)}cm');
            }
          }

          // reset motion state after a detected rep
          _inMotion = false;
          _lastMotionEndTs = now;
          _lastPeakSign = 0;
          _lastPeakTs = now;
        }
      } else {
        // store this peak for potential pairing
        _lastPeakSign = sign;
        _lastPeakTs = now;
      }
    }

    // idle detection -> zero velocity to limit drift (apply to Y velocity)
    if (mag < _endThreshold) {
      if (_idleStart == 0.0) _idleStart = now;
      final idleDur = now - _idleStart;
      if (idleDur > 0.5) {
        // reset velocity when stationary for a short period
        if (_velY.abs() < 0.5) {
          _velY = 0.0;
        }
      }
    } else {
      _idleStart = 0.0;
    }

    // detect motion start
    if (!_inMotion && mag > _startThreshold) {
      _inMotion = true;
      _motionStartTs = now;

      // new set if enough idle time passed
      if (now - _lastMotionEndTs > _setIdleSeconds) {
        _setCount += 1;
      }

      // clear buffers
      _curTimes.clear();
      _curPositions.clear();
      _curVelocities.clear();
    }

    // if in motion, collect samples (use Y position/velocity)
    if (_inMotion) {
      final relT = now - _motionStartTs;
      _curTimes.add(relT);
      _curPositions.add(_posY * 100.0); // cm
      _curVelocities.add(_velY);
    }

    // detect motion end: when magnitude drops below end threshold
    if (_inMotion && mag < _endThreshold) {
      // require short buffer of low magnitude (simple debounce)
      // if last sample duration > 0.12s since start and magnitude low, end
      if (_curTimes.isNotEmpty && (_curTimes.last > 0.08)) {
        // finalize rep
        final minP = _curPositions.reduce((a, b) => a < b ? a : b);
        final maxP = _curPositions.reduce((a, b) => a > b ? a : b);
        final rangeCm = (maxP - minP).abs();

        if (rangeCm >= _minRepDisplacementCm && _curTimes.length >= 3) {
          final duration = _curTimes.last - _curTimes.first;
          final peakV = _curVelocities.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
          final avgV = _curVelocities.map((v) => v.abs()).reduce((a, b) => a + b) / _curVelocities.length;

          _repCount += 1;
          final rep = RepAnalysis(
            repNumber: _repCount,
            durationSec: duration,
            peakVelocity: peakV,
            avgVelocity: avgV,
            rangeOfMotionCm: rangeCm,
            timeSec: List.of(_curTimes),
            positionCm: List.of(_curPositions),
            velocityMs: List.of(_curVelocities),
          );

          _reps.add(rep);
          if (_debug) {
            print('Rep #${_repCount}: dur=${duration.toStringAsFixed(3)}s peakV=${peakV.toStringAsFixed(3)} avgV=${avgV.toStringAsFixed(3)} ROM=${rangeCm.toStringAsFixed(2)}cm');
          }
        }

        _inMotion = false;
        _lastMotionEndTs = now;
        // do not zero velocity/position here; keep integration running
      }
    }

    _lastTs = now;

    // periodic concise debug log
    if (_debug) {
      _logCounter++;
      if (_logCounter % 10 == 0) {
        print('IMU seq:${p.seq} dt:${dt.toStringAsFixed(4)} ay:${ayMs2.toStringAsFixed(3)} linearY:${linearY.toStringAsFixed(3)} velY:${_velY.toStringAsFixed(3)} posY:${(_posY*100).toStringAsFixed(2)}cm incl:${_inclinationDeg.toStringAsFixed(1)} mag:${mag.toStringAsFixed(3)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sensor Data'),
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
          child: _error != null
              ? _ErrorBox(message: _error!)
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _subscribed ? 'Receiving packets…' : 'Not subscribed',
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 16),

                      _kv('Sequence', '$seq'),
                      const SizedBox(height: 12),

                      const Text('Accelerometer (raw int16)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _triple('ax', ax, 'ay', ay, 'az', az),

                      const SizedBox(height: 16),

                      const Text('Gyroscope (raw int16)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _triple('gx', gx, 'gy', gy, 'gz', gz),

                      const SizedBox(height: 16),
                      _kv('Position (cm)', '${(_posY * 100.0).toStringAsFixed(1)}'),
                      const SizedBox(height: 10),
                      _kv('Reps', '$_repCount'),
                      const SizedBox(height: 10),
                      _kv('Inclination (°)', '${_inclinationDeg.toStringAsFixed(1)}'),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _recording ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (!_recording) {
                                      // start recording
                                      _recordedReps.clear();
                                      _recording = true;
                                      _repCount = 0;
                                      _setCount = 0;
                                      _posY = 0.0;
                                      _velY = 0.0;
                                    } else {
                                      // stop recording
                                      _recording = false;
                                      // if nothing was added to recordedReps during recording,
                                      // but we have detected reps in _reps, copy them so View Analysis works
                                      if (_recordedReps.isEmpty && _reps.isNotEmpty) {
                                        _recordedReps.addAll(_reps);
                                        if (_debug) print('Stop recording: copied ${_reps.length} reps into _recordedReps');
                                      }
                                    }
                                  });
                                },
                                child: Text(_recording ? 'Stop Recording' : 'Start Recording', style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1F2937),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: (!_recording && (_recordedReps.isNotEmpty || _reps.isNotEmpty))
                                    ? () {
                                        final listToShow = _recordedReps.isNotEmpty ? List.of(_recordedReps) : List.of(_reps);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ViewAnalysisScreen(reps: listToShow),
                                          ),
                                        );
                                      }
                                    : null,
                                child: const Text('View Analysis', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            // quick resubscribe button if needed
                            await _notifySub?.cancel();
                            await _setNotify(false);
                            setState(() {
                              _subscribed = false;
                              _error = null;
                            });
                            await _setupNotifications();
                          },
                          child: const Text('Reconnect Stream', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Text(k, style: const TextStyle(color: Color(0xFF94A3B8))),
          const Spacer(),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _triple(String k1, int v1, String k2, int v2, String k3, int v3) {
    Widget cell(String k, int v) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k, style: const TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                Text('$v',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        cell(k1, v1),
        const SizedBox(width: 10),
        cell(k2, v2),
        const SizedBox(width: 10),
        cell(k3, v3),
      ],
    );
  }
}

class ImuPacket {
  final int seq;
  final int ax, ay, az;
  final int gx, gy, gz;

  ImuPacket({
    required this.seq,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
