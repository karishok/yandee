import 'dart:convert';
import 'dart:io';

import 'src/placeholder_png.dart';
import 'src/placeholder_wav.dart';

const _demoMarkers = [
  PlaceholderMarker(x: 0.10, y: 0.65, width: 0.15, height: 0.20, rgb: [220, 50, 50]), // ball
  PlaceholderMarker(x: 0.35, y: 0.55, width: 0.18, height: 0.30, rgb: [230, 140, 40]), // cat
  PlaceholderMarker(x: 0.60, y: 0.30, width: 0.20, height: 0.55, rgb: [40, 150, 70]), // tree
  PlaceholderMarker(x: 0.75, y: 0.05, width: 0.15, height: 0.15, rgb: [250, 210, 60]), // sun
];

const _demoSceneJson = '''
{
  "id": "demo",
  "version": 1,
  "title": "Демо",
  "minAgeMonths": 12,
  "background": "background.png",
  "objects": [
    {"id": "ball", "label": "Мяч", "audio": "ball.wav", "rect": {"x": 0.10, "y": 0.65, "width": 0.15, "height": 0.20}},
    {"id": "cat", "label": "Кот", "audio": "cat.wav", "rect": {"x": 0.35, "y": 0.55, "width": 0.18, "height": 0.30}},
    {"id": "tree", "label": "Дерево", "audio": "tree.wav", "rect": {"x": 0.60, "y": 0.30, "width": 0.20, "height": 0.55}},
    {"id": "sun", "label": "Солнце", "audio": "sun.wav", "rect": {"x": 0.75, "y": 0.05, "width": 0.15, "height": 0.15}}
  ]
}
''';

Future<void> _write(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  stdout.writeln('wrote $path (${bytes.length} bytes)');
}

Future<void> main() async {
  for (final name in ['find_intro', 'wrong_hint', 'correct', 'round_complete']) {
    await _write('assets/audio/system/$name.wav', buildSilentWav());
  }

  await _write('assets/demo_content/demo/scene.json', utf8.encode(_demoSceneJson));
  await _write(
    'assets/demo_content/demo/background.png',
    buildPlaceholderPng(width: 800, height: 600, backgroundRgb: const [150, 200, 240], markers: _demoMarkers),
  );
  await _write(
    'assets/demo_content/demo/thumb.png',
    buildPlaceholderPng(width: 200, height: 150, backgroundRgb: const [150, 200, 240], markers: _demoMarkers),
  );
  for (final name in ['ball', 'cat', 'tree', 'sun']) {
    await _write('assets/demo_content/demo/$name.wav', buildSilentWav());
  }
}
