import 'package:flutter/foundation.dart';

class SensorData extends ChangeNotifier {
  SensorData._privateConstructor();
  static final SensorData instance = SensorData._privateConstructor();

  int sequence = 0;
  double ax = 0.0;
  double ay = 0.0;
  double az = 0.0;
  double gx = 0.0;
  double gy = 0.0;
  double gz = 0.0;

  // Scale applied to raw int16 values (adjust as needed)
  static const double _scale = 100.0;

  /// Parse a 14-byte packet: [seq(2), ax(2), ay(2), az(2), gx(2), gy(2), gz(2)]
  void updateFromBytes(List<int> bytes) {
    if (bytes.length < 14) return;
    int seq = _toUint16(bytes, 0);
    int rawAx = _toInt16(bytes, 2);
    int rawAy = _toInt16(bytes, 4);
    int rawAz = _toInt16(bytes, 6);
    int rawGx = _toInt16(bytes, 8);
    int rawGy = _toInt16(bytes, 10);
    int rawGz = _toInt16(bytes, 12);

    sequence = seq;
    ax = rawAx / _scale;
    ay = rawAy / _scale;
    az = rawAz / _scale;
    gx = rawGx / _scale;
    gy = rawGy / _scale;
    gz = rawGz / _scale;

    notifyListeners();
  }

  static int _toUint16(List<int> b, int offset) {
    return (b[offset] & 0xff) | ((b[offset + 1] & 0xff) << 8);
  }

  static int _toInt16(List<int> b, int offset) {
    int v = _toUint16(b, offset);
    if (v & 0x8000 != 0) v = v - 0x10000;
    return v;
  }
}
