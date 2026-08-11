import 'dart:convert';
import 'dart:io';

import 'src/placeholder_png.dart';
import 'src/placeholder_wav.dart';
import 'src/scene_vocabulary.dart';

// Cycled across each scene's objects so neighboring markers in the
// generated placeholder art are always visually distinguishable.
const _markerPalette = [
  [220, 50, 50],
  [230, 140, 40],
  [230, 200, 40],
  [90, 170, 60],
  [40, 150, 120],
  [40, 120, 200],
  [90, 80, 200],
  [170, 60, 190],
  [220, 60, 140],
  [120, 90, 60],
];


/// Lays out N objects on a 5x2 grid (every scene above has exactly 10),
/// each marker centered in its cell at 70% of the cell's size so
/// neighboring markers never touch.
List<PlaceholderMarker> _layoutMarkers(List<ObjectSpec> objects) {
  const cols = 5;
  const rows = 2;
  const cellWidth = 1 / cols;
  const cellHeight = 1 / rows;
  const fill = 0.7;
  const objectWidth = cellWidth * fill;
  const objectHeight = cellHeight * fill;

  return [
    for (var i = 0; i < objects.length; i++)
      PlaceholderMarker(
        x: (i % cols) * cellWidth + (cellWidth - objectWidth) / 2,
        y: (i ~/ cols) * cellHeight + (cellHeight - objectHeight) / 2,
        width: objectWidth,
        height: objectHeight,
        rgb: _markerPalette[i % _markerPalette.length],
      ),
  ];
}

// Rounds away the float-arithmetic noise (e.g. 0.030000000000000013) so the
// committed scene.json files read as clean, hand-authored-looking numbers.
double _round(double value) => double.parse(value.toStringAsFixed(4));

Map<String, dynamic> _buildSceneJson(SceneSpec scene, List<PlaceholderMarker> markers) {
  return {
    'id': scene.id,
    'version': 1,
    'title': scene.title,
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': [
      for (var i = 0; i < scene.objects.length; i++)
        {
          'id': scene.objects[i].id,
          'label': scene.objects[i].label,
          'audio': '${scene.objects[i].id}.wav',
          'rect': {
            'x': _round(markers[i].x),
            'y': _round(markers[i].y),
            'width': _round(markers[i].width),
            'height': _round(markers[i].height),
          },
        },
    ],
  };
}

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

  for (final scene in scenes) {
    final markers = _layoutMarkers(scene.objects);
    final dir = 'assets/demo_content/${scene.id}';

    await _write('$dir/scene.json', utf8.encode(jsonEncode(_buildSceneJson(scene, markers))));
    await _write(
      '$dir/background.png',
      buildPlaceholderPng(width: 800, height: 600, backgroundRgb: scene.backgroundRgb, markers: markers),
    );
    await _write(
      '$dir/thumb.png',
      buildPlaceholderPng(width: 200, height: 150, backgroundRgb: scene.backgroundRgb, markers: markers),
    );
    for (final object in scene.objects) {
      await _write('$dir/${object.id}.wav', buildSilentWav());
    }
  }
}
