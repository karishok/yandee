import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yandee/domain/models/object_outline.dart';
import 'package:yandee/domain/models/scene.dart';

/// Checks the scenes shipped in `assets/demo_content` against the files
/// that sit next to them — the mistakes that are easy to make by hand when
/// adding a scene or marking up a new picture.
void main() {
  final sceneDirs = Directory('assets/demo_content')
      .listSync()
      .whereType<Directory>()
      .where((dir) => File(p.join(dir.path, 'scene.json')).existsSync())
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  Scene readScene(Directory dir) =>
      Scene.fromJson(jsonDecode(File(p.join(dir.path, 'scene.json')).readAsStringSync()) as Map<String, dynamic>);

  test('there are bundled scenes to check', () {
    expect(sceneDirs, isNotEmpty);
  });

  for (final dir in sceneDirs) {
    final sceneId = p.basename(dir.path);

    test('$sceneId: every file the scene refers to exists', () {
      final scene = readScene(dir);
      expect(scene.id, sceneId);
      expect(File(p.join(dir.path, scene.background)).existsSync(), isTrue, reason: scene.background);
      expect(File(p.join(dir.path, 'thumb.png')).existsSync(), isTrue, reason: 'thumb.png');
      for (final object in scene.objects) {
        expect(File(p.join(dir.path, object.audio)).existsSync(), isTrue, reason: object.audio);
        final sound = object.sound;
        if (sound != null) expect(File(p.join(dir.path, sound)).existsSync(), isTrue, reason: sound);
      }
      final realistic = scene.realistic;
      if (realistic != null) {
        expect(File(p.join(dir.path, realistic.background)).existsSync(), isTrue, reason: realistic.background);
      }
    });

    test('$sceneId: a realistic picture gives every object its own tap zone', () {
      final scene = readScene(dir);
      final realistic = scene.realistic;
      if (realistic == null) return;
      // The realistic art is a different drawing: nothing sits exactly
      // where it does on the default picture, so a zone left out (or one
      // for an object that doesn't exist) is a mark-up mistake.
      expect(realistic.rects.keys.toSet(), scene.objects.map((o) => o.id).toSet());
    });

    test('$sceneId: outlines are polygons inside the picture, for objects that exist', () {
      final scene = readScene(dir);
      final outlines = {
        for (final object in scene.objects)
          if (object.outline != null) object.id: object.outline!,
        for (final entry in (scene.realistic?.outlines ?? const <String, ObjectOutline>{}).entries)
          '${entry.key} (realistic)': entry.value,
      };
      for (final entry in outlines.entries) {
        expect(entry.value.points.length, greaterThanOrEqualTo(3), reason: entry.key);
        for (final point in entry.value.points) {
          expect(point.x, inInclusiveRange(0, 1), reason: entry.key);
          expect(point.y, inInclusiveRange(0, 1), reason: entry.key);
        }
      }
      final ids = scene.objects.map((o) => o.id).toSet();
      expect(ids, containsAll(scene.realistic?.outlines.keys ?? const <String>[]));
    });

    test('$sceneId: a flashlight target has an outline on the realistic picture too', () {
      final scene = readScene(dir);
      final realistic = scene.realistic;
      if (realistic == null) return;
      // Without one a found target falls back to a blurry oval over its
      // tap zone on that picture — it works, but it is a mark-up gap.
      final targets = scene.objects.where((o) => o.outline != null).map((o) => o.id).toSet();
      expect(realistic.outlines.keys.toSet(), targets);
    });
  }

  test('the forest and the zoo have a realistic picture', () {
    final withRealistic = [
      for (final dir in sceneDirs)
        if (readScene(dir).realistic != null) p.basename(dir.path),
    ];
    expect(withRealistic, containsAll(['forest', 'zoo']));
  });

  // Every scene has the flashlight game, and everything on the picture is
  // something to find, so every object needs its outline. The versions
  // are the ones that added them: bumping a scene's version is what gets
  // it re-seeded on devices that already have the scene.
  const flashlightVersions = {
    'bathroom': 5,
    'farm': 6,
    'forest': 6,
    'home': 3,
    'kitchen': 3,
    'playground': 3,
    'sea': 3,
    'street': 4,
    'toys': 3,
    'zoo': 4,
  };

  test('every bundled scene has the flashlight game', () {
    expect(sceneDirs.map((dir) => p.basename(dir.path)).toSet(), flashlightVersions.keys.toSet());
  });

  for (final MapEntry(key: sceneId, value: version) in flashlightVersions.entries) {
    test('$sceneId: every object can be found in the flashlight game', () {
      final scene = readScene(sceneDirs.singleWhere((dir) => p.basename(dir.path) == sceneId));
      expect(scene.version, greaterThanOrEqualTo(version));
      expect(scene.objects.where((o) => o.outline == null).map((o) => o.id), isEmpty);
    });
  }
}
