import 'dart:io';

import '../../tool/src/placeholder_png.dart';

/// Writes a fixture PNG with a known, non-square size (to catch aspect
/// ratio bugs) into [dir] under [fileName].
Future<File> writeFixturePng(Directory dir, String fileName, {int width = 400, int height = 300}) async {
  final bytes = buildPlaceholderPng(width: width, height: height, backgroundRgb: const [150, 200, 240]);
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file;
}
