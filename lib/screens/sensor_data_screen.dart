import 'dart:async';
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
        setState(() {
          seq = p.seq;
          ax = p.ax; ay = p.ay; az = p.az;
          gx = p.gx; gy = p.gy; gz = p.gz;
        });
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
              : Column(
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

                    const Spacer(),

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
                        child: const Text('Reconnect Stream',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
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
