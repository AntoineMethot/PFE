import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_manager.dart';

class ImuSample {
  final double t; // seconds since start()
  final int seq;
  final int ax, ay, az; // raw (mg if your firmware sends mg)
  final int gx, gy, gz; // raw (centi-deg/s if your firmware sends that)

  ImuSample({
    required this.t,
    required this.seq,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  String toCsv() => '$t,$seq,$ax,$ay,$az,$gx,$gy,$gz';
}

class BleImuStream {
  BleImuStream._();
  static final BleImuStream I = BleImuStream._();

  // UUIDs
  final Guid imuServiceUuid = Guid("12345678-1234-1234-1234-1234567890AB");
  final Guid imuNotifyUuid  = Guid("12345678-1234-1234-1234-1234567890AC");
  final Guid imuCmdUuid     = Guid("12345678-1234-1234-1234-1234567890AD"); // your write uuid

  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _cmdChar;

  StreamSubscription<List<int>>? _notifySub;

  final _controller = StreamController<ImuSample>.broadcast();
  Stream<ImuSample> get samplesStream => _controller.stream;

  bool _running = false;
  bool get isRunning => _running;

  double? _t0; // epoch seconds at start

  // Optional: keep last N samples for easy “save on stop”
  final List<ImuSample> _buffer = [];
  List<ImuSample> get buffer => List.unmodifiable(_buffer);
  void clearBuffer() => _buffer.clear();

  Future<void> start({bool sendStartCommand = true}) async {
    final device = BleManager.I.device;
    if (device == null) {
      throw Exception("No device connected. Connect first.");
    }
    if (!BleManager.I.isConnected) {
      throw Exception("Device is not connected.");
    }
    if (_running) return;

    // Discover services/characteristics
    final services = await device.discoverServices();

    final imuService = services.firstWhere(
      (s) => s.uuid == imuServiceUuid,
      orElse: () => throw Exception("IMU service not found: $imuServiceUuid"),
    );

    _notifyChar = imuService.characteristics.firstWhere(
      (c) => c.uuid == imuNotifyUuid,
      orElse: () => throw Exception("Notify characteristic not found: $imuNotifyUuid"),
    );

    _cmdChar = imuService.characteristics.firstWhere(
      (c) => c.uuid == imuCmdUuid,
      orElse: () => throw Exception("Cmd characteristic not found: $imuCmdUuid"),
    );

    // Enable notifications first
    await _notifyChar!.setNotifyValue(true);

    // Subscribe to stream
    _t0 = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _buffer.clear();

    await _notifySub?.cancel();
    _notifySub = _notifyChar!.onValueReceived.listen((data) {
      final sample = _parsePacket(data);
      if (sample == null) return;
      _buffer.add(sample);
      _controller.add(sample);
    });

    // Optional: tell device to start streaming
    if (sendStartCommand) {
      await sendCommand(0x01);
    }

    _running = true;
  }

  Future<void> stop({bool sendStopCommand = true}) async {
    if (!_running) return;

    // Optional: tell device to stop streaming
    if (sendStopCommand) {
      try {
        await sendCommand(0x00);
      } catch (_) {
        // ignore; we still shut down notifications locally
      }
    }

    await _notifySub?.cancel();
    _notifySub = null;

    if (_notifyChar != null) {
      try {
        await _notifyChar!.setNotifyValue(false);
      } catch (_) {}
    }

    _running = false;
  }

  Future<void> resetSeq() async => sendCommand(0x02);

  Future<void> sendCommand(int byte) async {
    if (_cmdChar == null) {
      throw Exception("Cmd characteristic not ready (start() first).");
    }

    // Most firmwares use writeWithoutResponse for commands; both usually work.
    // We'll try withoutResponse first.
    try {
      await _cmdChar!.write([byte], withoutResponse: true);
    } catch (_) {
      await _cmdChar!.write([byte], withoutResponse: false);
    }
  }

  ImuSample? _parsePacket(List<int> data) {
    // Expect 14 bytes: seq + 6x int16
    if (data.length < 14) return null;

    final bytes = Uint8List.fromList(data);
    final bd = ByteData.sublistView(bytes);

    int i16(int offset) => bd.getInt16(offset, Endian.little);
    int u16(int offset) => bd.getUint16(offset, Endian.little);

    final seq = u16(0);
    final ax = i16(2);
    final ay = i16(4);
    final az = i16(6);
    final gx = i16(8);
    final gy = i16(10);
    final gz = i16(12);

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final t = (now - (_t0 ?? now));

    return ImuSample(
      t: t,
      seq: seq,
      ax: ax,
      ay: ay,
      az: az,
      gx: gx,
      gy: gy,
      gz: gz,
    );
  }

  void dispose() {
    _notifySub?.cancel();
    _controller.close();
  }
}