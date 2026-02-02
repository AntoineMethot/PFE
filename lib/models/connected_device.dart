import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ConnectedDevice {
  final BluetoothDevice device;
  final String? type; // optional (you can set later from your own logic)
  final int? batteryPercent; // optional (read from Battery Service later)

  const ConnectedDevice({
    required this.device,
    this.type,
    this.batteryPercent,
  });

  String get id => device.id.id;

  String get displayName {
    final n = device.name.trim();
    return n.isNotEmpty ? n : id;
  }
}
