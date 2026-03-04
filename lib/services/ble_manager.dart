import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager {
  BleManager._();
  static final BleManager I = BleManager._();

  BluetoothDevice? _device;
  BluetoothDevice? get device => _device;

  StreamSubscription<BluetoothConnectionState>? _connSub;

  BluetoothConnectionState _state = BluetoothConnectionState.disconnected;
  BluetoothConnectionState get state => _state;

  final _stateController =
      StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get stateStream => _stateController.stream;

  bool get isConnected => _state == BluetoothConnectionState.connected;

  Future<void> connect(BluetoothDevice dev) async {
    // Already connected to same device
    if (_device?.remoteId == dev.remoteId && isConnected) return;

    _device = dev;

    // Listen to connection state
    await _connSub?.cancel();
    _connSub = _device!.connectionState.listen((s) async {
      _state = s;
      _stateController.add(s);

      // Optional auto reconnect
      if (s == BluetoothConnectionState.disconnected) {
        try {
          await _device!.connect(
            license: License.free,
            timeout: const Duration(seconds: 10),
          );
        } catch (_) {}
      }
    });

    // CONNECT (requires license)
    await _device!.connect(
      license: License.free,
      timeout: const Duration(seconds: 12),
    );
  }

  Future<void> disconnect() async {
    try {
      await _connSub?.cancel();
      _connSub = null;

      if (_device != null) {
        await _device!.disconnect();
      }
    } finally {
      _state = BluetoothConnectionState.disconnected;
      _stateController.add(_state);
      _device = null;
    }
  }
}