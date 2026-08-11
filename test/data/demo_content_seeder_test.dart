import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';
import 'package:yandee/data/demo_content_seeder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheRoot;

  const sceneIds = ['home', 'kitchen', 'farm', 'street', 'bathroom'];

  // Started at 10 objects each; extra objects were added per scene to
  // match new items drawn into the updated background art.
  const expectedObjectCounts = {'home': 12, 'kitchen': 14, 'farm': 14, 'street': 12, 'bathroom': 13};

  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp('yandee_seeder_test_');
  });

  tearDown(() async {
    if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
  });

  test('seeds every bundled scene into an empty cache', () async {
    await const DemoContentSeeder().seedIfEmpty(cacheRoot);

    for (final sceneId in sceneIds) {
      final sceneDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, sceneId));
      expect(await File(p.join(sceneDir.path, 'scene.json')).exists(), isTrue);
      expect(await File(p.join(sceneDir.path, 'background.png')).exists(), isTrue);
      expect(await File(p.join(sceneDir.path, 'thumb.png')).exists(), isTrue);

      final sceneJson =
          jsonDecode(await File(p.join(sceneDir.path, 'scene.json')).readAsString()) as Map<String, dynamic>;
      final objects = sceneJson['objects'] as List<dynamic>;
      expect(objects, hasLength(expectedObjectCounts[sceneId]!), reason: 'scene $sceneId');
      for (final object in objects) {
        final audio = (object as Map<String, dynamic>)['audio'] as String;
        expect(await File(p.join(sceneDir.path, audio)).exists(), isTrue);
      }
    }
  });

  test('does nothing if the cache already has a scene', () async {
    final otherDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'other'));
    await otherDir.create(recursive: true);
    await File(p.join(otherDir.path, 'scene.json')).writeAsString('{}');

    await const DemoContentSeeder().seedIfEmpty(cacheRoot);

    for (final sceneId in sceneIds) {
      final sceneDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, sceneId));
      expect(await sceneDir.exists(), isFalse);
    }
  });
}
