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

  group('realistic variant', () {
    final jsonWithRealistic = {
      ...json,
      'objects': [
        {
          'id': 'tree_1',
          'label': 'Дерево',
          'audio': 'tree.mp3',
          'rect': {'x': 0.12, 'y': 0.45, 'width': 0.10, 'height': 0.20},
        },
        {
          'id': 'car',
          'label': 'Машина',
          'audio': 'car.mp3',
          'rect': {'x': 0.5, 'y': 0.5, 'width': 0.2, 'height': 0.1},
        },
      ],
      'realistic': {
        'background': 'background_real.png',
        'rects': {
          'tree_1': {'x': 0.3, 'y': 0.4, 'width': 0.15, 'height': 0.25},
        },
      },
    };

    test('a scene without a realistic block has no realistic variant', () {
      expect(Scene.fromJson(json).realistic, isNull);
    });

    test('Scene.fromJson parses the realistic background and its tap zones', () {
      final realistic = Scene.fromJson(jsonWithRealistic).realistic!;
      expect(realistic.background, 'background_real.png');
      expect(realistic.rects.keys, ['tree_1']);
      expect(realistic.rects['tree_1']!.x, 0.3);
      expect(realistic.rects['tree_1']!.height, 0.25);
    });

    test('objectsFor(realistic: false) returns the objects with their own tap zones', () {
      final scene = Scene.fromJson(jsonWithRealistic);
      expect(scene.objectsFor(realistic: false).map((o) => o.rect.x), [0.12, 0.5]);
    });

    test('objectsFor(realistic: true) moves the objects to the realistic tap zones', () {
      final scene = Scene.fromJson(jsonWithRealistic);
      final objects = scene.objectsFor(realistic: true);

      // Same objects, in the same order (order is tap priority), with the
      // same words and audio — only where they are on the picture changes.
      expect(objects.map((o) => o.id), ['tree_1', 'car']);
      expect(objects.first.label, 'Дерево');
      expect(objects.first.audio, 'tree.mp3');
      expect(objects.first.rect.x, 0.3);
      expect(objects.first.rect.width, 0.15);
    });

    test('an object the realistic variant gives no tap zone keeps its own', () {
      final scene = Scene.fromJson(jsonWithRealistic);
      final car = scene.objectsFor(realistic: true).last;
      expect(car.rect.x, 0.5);
    });

    test('objectsFor(realistic: true) on a scene without the variant returns the objects unchanged', () {
      final scene = Scene.fromJson(json);
      expect(scene.objectsFor(realistic: true).single.rect.x, 0.12);
    });
  });
}
