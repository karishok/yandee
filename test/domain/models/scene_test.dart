import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/scene.dart';

void main() {
  final json = {
    'id': 'city',
    'version': 3,
    'title': 'Город',
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': [
      {
        'id': 'tree_1',
        'label': 'Дерево',
        'audio': 'tree_1.mp3',
        'rect': {'x': 0.12, 'y': 0.45, 'width': 0.10, 'height': 0.20},
      },
    ],
  };

  test('Scene.fromJson parses top-level fields', () {
    final scene = Scene.fromJson(json);
    expect(scene.id, 'city');
    expect(scene.version, 3);
    expect(scene.title, 'Город');
    expect(scene.minAgeMonths, 12);
    expect(scene.background, 'background.png');
    expect(scene.objects, hasLength(1));
  });

  test('SceneObject.fromJson parses id/label/audio/rect', () {
    final object = Scene.fromJson(json).objects.first;
    expect(object.id, 'tree_1');
    expect(object.label, 'Дерево');
    expect(object.audio, 'tree_1.mp3');
    expect(object.rect.x, 0.12);
    expect(object.rect.y, 0.45);
    expect(object.rect.width, 0.10);
    expect(object.rect.height, 0.20);
  });

  test('SceneObject equality compares by id', () {
    final a = Scene.fromJson(json).objects.first;
    final b = Scene.fromJson(json).objects.first;
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}
