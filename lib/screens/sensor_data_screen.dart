import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SensorDataScreen extends StatefulWidget {
  const SensorDataScreen({
    super.key,
    required this.device,
    required this.imuDataCharacteristicUuid,
    required this.imuServiceUuid,
  });

  /// Connected device (must already be connected)
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
  double _velY = 0.0; // m/s (for display)
  double _posY = 0.0; // meters (for display)

  // Inclination (degrees) computed from gravity vector
  double _inclinationDeg = 0.0;

  // Parameters
  final double _accelLsbPerG = 16384.0; // default sensor scale (LSB per g)
  final double _g = 9.80665;

  // Debug
  bool _debug = false;
  int _logCounter = 0;

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
      // Discover services/characteristics (device must be connected)
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

      // IMPORTANT: subscribe BEFORE listening
      await _setNotify(true);

      // Listen to incoming notifications
      await _notifySub?.cancel();
      _notifySub = imuChar.onValueReceived.listen((data) {
        if (data.length != 14) return;

        final p = _parsePacket14(data);

        // update raw fields
        seq = p.seq;
        ax = p.ax;
        ay = p.ay;
        az = p.az;
        gx = p.gx;
        gy = p.gy;
        gz = p.gz;

        // process
        _processImuPacket(p);

        if (!mounted) return;
        setState(() {});
      });

      // auto-cancel when disconnected (prevents leaks)
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
      // ignore (some platforms throw if already set)
    }
  }

  /// Packet: [0..1]=uint16 seq, then 6x int16: ax ay az gx gy gz (little-endian)
  ImuPacket _parsePacket14(List<int> bytes) {
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));

    final seq = bd.getUint16(0, Endian.little);

    final ax = bd.getInt16(2, Endian.little);
    final ay = bd.getInt16(4, Endian.little);
    final az = bd.getInt16(6, Endian.little);

    final gx = bd.getInt16(8, Endian.little);
    final gy = bd.getInt16(10, Endian.little);
    final gz = bd.getInt16(12, Endian.little);

    return ImuPacket(seq: seq, ax: ax, ay: ay, az: az, gx: gx, gy: gy, gz: gz);
  }

  // Convert raw -> m/s^2, estimate gravity via LPF, compute inclination,
  // integrate Y axis for simple position readout (debug).
  void _processImuPacket(ImuPacket p) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    // raw int16 -> m/s^2
    final axMs2 = p.ax / _accelLsbPerG * _g;
    final ayMs2 = p.ay / _accelLsbPerG * _g;
    final azMs2 = p.az / _accelLsbPerG * _g;

    if (_lastTs == 0.0) {
      // initialize gravity estimate to first sample (all axes)
      _gravityX = axMs2;
      _gravityY = ayMs2;
      _gravityZ = azMs2;
      _lastTs = now;
      return;
    }

    var dt = now - _lastTs;
    if (dt <= 0) dt = 0.001;
    if (dt > 0.5) dt = 0.02;

    // LPF gravity estimate
    const tau = 0.5; // seconds
    final alpha = tau / (tau + dt);

    _gravityX = alpha * _gravityX + (1 - alpha) * axMs2;
    _gravityY = alpha * _gravityY + (1 - alpha) * ayMs2;
    _gravityZ = alpha * _gravityZ + (1 - alpha) * azMs2;

    // linear accel
    final linearY = ayMs2 - _gravityY;

    // integrate for a simple "position" display (not bar path)
    _velY += linearY * dt;
    _posY += _velY * dt;

    // inclination from gravity vector (tilt)
    final gNorm = sqrt(_gravityX * _gravityX + _gravityY * _gravityY + _gravityZ * _gravityZ);
    if (gNorm > 1e-6) {
      // Use Y component for "tilt" (adjust if you prefer a different axis)
      _inclinationDeg = asin((_gravityY / gNorm).clamp(-1.0, 1.0)) * 180.0 / pi;
    }

    _lastTs = now;

    if (_debug) {
      _logCounter++;
      if (_logCounter % 10 == 0) {
        // ignore: avoid_print
        print(
          'seq:${p.seq} dt:${dt.toStringAsFixed(4)} '
          'ay:${ayMs2.toStringAsFixed(3)} linY:${linearY.toStringAsFixed(3)} '
          'velY:${_velY.toStringAsFixed(3)} posYcm:${(_posY * 100).toStringAsFixed(2)} '
          'incl:${_inclinationDeg.toStringAsFixed(1)}',
        );
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
        actions: [
          IconButton(
            tooltip: 'Reconnect Stream',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _notifySub?.cancel();
              await _setNotify(false);
              if (!mounted) return;
              setState(() {
                _subscribed = false;
                _error = null;
              });
              await _setupNotifications();
            },
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _error != null
              ? _ErrorBox(message: _error!)
              : ListView(
                  children: [
                    Text(
                      _subscribed ? 'Receiving packets…' : 'Not subscribed',
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 16),

                    _kv('Sequence', '$seq'),
                    const SizedBox(height: 12),

                    const Text(
                      'Accelerometer (raw int16)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _triple('ax', ax, 'ay', ay, 'az', az),

                    const SizedBox(height: 16),

                    const Text(
                      'Gyroscope (raw int16)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _triple('gx', gx, 'gy', gy, 'gz', gz),

                    const SizedBox(height: 16),

                    _kv('Position (cm)', '${(_posY * 100.0).toStringAsFixed(1)}'),
                    const SizedBox(height: 10),
                    _kv('Velocity Y (m/s)', _velY.toStringAsFixed(3)),
                    const SizedBox(height: 10),
                    _kv('Inclination (°)', _inclinationDeg.toStringAsFixed(1)),
                  ],
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
                Text(
                  '$v',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
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