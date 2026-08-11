import 'dart:convert';
import 'dart:io';

import 'src/placeholder_png.dart';
import 'src/placeholder_wav.dart';

/// One tappable object in a placeholder scene: its content-facing id/label
/// (the real, agreed-on vocabulary for that scene) plus generated
/// placeholder art/audio, same as everything else in this tool.
class _ObjectSpec {
  const _ObjectSpec(this.id, this.label);
  final String id;
  final String label;
}

class _SceneSpec {
  const _SceneSpec(this.id, this.title, this.backgroundRgb, this.objects);
  final String id;
  final String title;
  final List<int> backgroundRgb;
  final List<_ObjectSpec> objects;
}

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

// The app's first 5 real content scenes (see
// docs/superpowers/plans/2026-08-11-yandee-interactive-scenes.md) — still
// placeholder art/audio, generated the same way as everything else here,
// but with the actual planned vocabulary rather than throwaway names.
final _scenes = [
  const _SceneSpec('home', 'Дом', [235, 222, 200], [
    _ObjectSpec('bed', 'Кровать'),
    _ObjectSpec('table', 'Стол'),
    _ObjectSpec('chair', 'Стул'),
    _ObjectSpec('lamp', 'Лампа'),
    _ObjectSpec('book', 'Книга'),
    _ObjectSpec('clock', 'Часы'),
    _ObjectSpec('window', 'Окно'),
    _ObjectSpec('door', 'Дверь'),
    _ObjectSpec('sofa', 'Диван'),
    _ObjectSpec('rug', 'Ковёр'),
  ]),
  const _SceneSpec('kitchen', 'Кухня', [255, 240, 200], [
    _ObjectSpec('plate', 'Тарелка'),
    _ObjectSpec('cup', 'Чашка'),
    _ObjectSpec('spoon', 'Ложка'),
    _ObjectSpec('fork', 'Вилка'),
    _ObjectSpec('fridge', 'Холодильник'),
    _ObjectSpec('stove', 'Плита'),
    _ObjectSpec('kettle', 'Чайник'),
    _ObjectSpec('apple', 'Яблоко'),
    _ObjectSpec('bread', 'Хлеб'),
    _ObjectSpec('pot', 'Кастрюля'),
  ]),
  const _SceneSpec('farm', 'Ферма', [200, 230, 180], [
    _ObjectSpec('cow', 'Корова'),
    _ObjectSpec('pig', 'Свинья'),
    _ObjectSpec('chicken', 'Курица'),
    _ObjectSpec('rooster', 'Петух'),
    _ObjectSpec('horse', 'Лошадь'),
    _ObjectSpec('sheep', 'Овца'),
    _ObjectSpec('goat', 'Коза'),
    _ObjectSpec('duck', 'Утка'),
    _ObjectSpec('dog', 'Собака'),
    _ObjectSpec('tractor', 'Трактор'),
  ]),
  const _SceneSpec('street', 'Улица', [210, 215, 220], [
    _ObjectSpec('car', 'Машина'),
    _ObjectSpec('bus', 'Автобус'),
    _ObjectSpec('bicycle', 'Велосипед'),
    _ObjectSpec('traffic_light', 'Светофор'),
    _ObjectSpec('tree', 'Дерево'),
    _ObjectSpec('bench', 'Скамейка'),
    _ObjectSpec('lamppost', 'Фонарь'),
    _ObjectSpec('scooter', 'Самокат'),
    _ObjectSpec('truck', 'Грузовик'),
    _ObjectSpec('road_sign', 'Дорожный знак'),
  ]),
  const _SceneSpec('bathroom', 'Ванная', [210, 235, 245], [
    _ObjectSpec('soap', 'Мыло'),
    _ObjectSpec('toothbrush', 'Зубная щётка'),
    _ObjectSpec('toothpaste', 'Зубная паста'),
    _ObjectSpec('towel', 'Полотенце'),
    _ObjectSpec('bathtub', 'Ванна'),
    _ObjectSpec('sink', 'Раковина'),
    _ObjectSpec('shampoo', 'Шампунь'),
    _ObjectSpec('duck_toy', 'Уточка'),
    _ObjectSpec('mirror', 'Зеркало'),
    _ObjectSpec('comb', 'Расчёска'),
  ]),
];

/// Lays out N objects on a 5x2 grid (every scene above has exactly 10),
/// each marker centered in its cell at 70% of the cell's size so
/// neighboring markers never touch.
List<PlaceholderMarker> _layoutMarkers(List<_ObjectSpec> objects) {
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

Map<String, dynamic> _buildSceneJson(_SceneSpec scene, List<PlaceholderMarker> markers) {
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

  for (final scene in _scenes) {
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
