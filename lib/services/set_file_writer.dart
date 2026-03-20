import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'ble_imu_stream.dart';

class SetFileWriter {
  static Future<File> writeCsv({
    required String exerciseName,
    required List<ImuSample> samples,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final setsDir = Directory(p.join(dir.path, 'sets'));
    if (!await setsDir.exists()) {
      await setsDir.create(recursive: true);
    }

    final safeName = exerciseName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File(p.join(setsDir.path, '${safeName}_$ts.csv'));

    // We'll compute a simple gravity low-pass per-sample (same approach as
    // the live sensor screen) to derive an inclination (degrees) from the
    // gravity vector and append it to the CSV.
    const double accelLsbPerG = 16384.0;
    const double g = 9.80665;
    const double tau = 0.5;

    double gravityX = 0.0, gravityY = 0.0, gravityZ = 0.0;
    double lastT = 0.0;
    var inited = false;

    final sb = StringBuffer()
      ..writeln('t_s,seq,ax,ay,az,gx,gy,gz,inclination_deg');

    for (final s in samples) {
      // convert raw -> m/s^2
      final axMs2 = s.ax / accelLsbPerG * g;
      final ayMs2 = s.ay / accelLsbPerG * g;
      final azMs2 = s.az / accelLsbPerG * g;

      if (!inited) {
        // mirror sensor_data_screen: initialize gravityX only on first sample
        gravityX = axMs2;
        lastT = s.t;
        inited = true;
        // sensor_data_screen returns early for the very first sample, so
        // record a zero inclination for this row to match behavior.
        sb.writeln('${s.toCsv()},0.000');
        lastT = s.t;
        continue;
      }

      double dt = s.t - lastT;
      if (dt <= 0) dt = 0.001;
      if (dt > 0.5) dt = 0.02;

      final alpha = tau / (tau + dt);
      gravityX = alpha * gravityX + (1 - alpha) * axMs2;
      gravityY = alpha * gravityY + (1 - alpha) * ayMs2;
      gravityZ = alpha * gravityZ + (1 - alpha) * azMs2;

      final gNorm = sqrt(gravityX * gravityX + gravityY * gravityY + gravityZ * gravityZ);
      double inclDeg = 0.0;
      if (gNorm > 1e-6) {
        inclDeg = asin((gravityY / gNorm).clamp(-1.0, 1.0)) * 180.0 / pi;
      }

      sb.writeln('${s.toCsv()},${inclDeg.toStringAsFixed(3)}');

      lastT = s.t;
    }

    await file.writeAsString(sb.toString(), flush: true);
    return file;
  }
}