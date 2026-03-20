import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class FileShareService {
  static Future<void> shareCsvFile(
    String path, {
    required BuildContext context,
    String? text,
  }) async {
    final file = File(path);
    final shareBox = context.findRenderObject() as RenderBox?;
    final shareOrigin =
        shareBox == null
            ? null
            : shareBox.localToGlobal(Offset.zero) & shareBox.size;

    if (!file.existsSync()) {
      throw Exception("Le fichier n existe pas : $path");
    }

    await Share.shareXFiles(
      [XFile(path)],
      text: text ?? 'CSV exporte',
      subject:
          file.uri.pathSegments.isEmpty
              ? 'CSV exporte'
              : file.uri.pathSegments.last,
      sharePositionOrigin: shareOrigin,
    );
  }
}
