import 'dart:io';
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

    final sb = StringBuffer()
      ..writeln('t_s,seq,ax,ay,az,gx,gy,gz');
    for (final s in samples) {
      sb.writeln(s.toCsv());
    }

    await file.writeAsString(sb.toString(), flush: true);
    return file;
  }
}