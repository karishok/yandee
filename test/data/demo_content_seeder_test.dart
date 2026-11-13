import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';
import 'package:yandee/data/demo_content_seeder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheRoot;

  const sceneIds = ['home', 'kitchen', 'farm', 'street', 'bathroom', 'playground', 'zoo', 'forest', 'toys', 'sea'];

  // The first five started at 10 objects each; extra objects were added per
  // scene to match new items drawn into the updated background art. Scenes
  // added later are capped at 7.
  const expectedObjectCounts = {
    'home': 12,
    'kitchen': 14,
    'farm': 19,
    'street': 17,
    'bathroom': 14,
    'playground': 7,
    'zoo': 7,
    'forest': 16, // 10 words; the path has 6 tap zones and the leafy tree 2
    'toys': 7,
    'sea': 17, // 12 words; the sea has 5 tap zones and the umbrella 2
  };

  Directory cachedSceneDir(String sceneId) =>
      Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, sceneId));

  Future<Map<String, dynamic>> readCachedSceneJson(String sceneId) async =>
      jsonDecode(await File(p.join(cachedSceneDir(sceneId).path, 'scene.json')).readAsString())
          as Map<String, dynamic>;

  Future<void> writeCachedSceneJson(String sceneId, {required int version}) async {
    final dir = cachedSceneDir(sceneId);
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'scene.json')).writeAsString(jsonEncode({
      'id': sceneId,
      'version': version,
      'title': 'Cached',
      'minAgeMonths': 12,
      'background': 'background.png',
      'objects': <dynamic>[],
    }));
  }

  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp('yandee_seeder_test_');
  });

  tearDown(() async {
    if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
  });

  test('seeds every bundled scene into an empty cache', () async {
    await const DemoContentSeeder().seed(cacheRoot);

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

  test("seeds a scene's realistic picture alongside its default one", () async {
    await const DemoContentSeeder().seed(cacheRoot);

    for (final sceneId in ['forest', 'zoo']) {
      final sceneJson = await readCachedSceneJson(sceneId);
      final realisticBackground = (sceneJson['realistic'] as Map<String, dynamic>)['background'] as String;
      expect(await File(p.join(cachedSceneDir(sceneId).path, realisticBackground)).exists(), isTrue,
          reason: 'scene $sceneId');
    }
  });

  // An app update ships new bundled scenes to a device whose cache was
  // filled by an earlier version — they must still show up.
  test('seeds bundled scenes missing from a cache that already has scenes', () async {
    await writeCachedSceneJson('home', version: 999);

    await const DemoContentSeeder().seed(cacheRoot);

    for (final sceneId in sceneIds) {
      expect(await File(p.join(cachedSceneDir(sceneId).path, 'scene.json')).exists(), isTrue,
          reason: 'scene $sceneId');
    }
    expect(await File(p.join(cachedSceneDir('playground').path, 'background.png')).exists(), isTrue);
  });

  test('replaces a cached scene that is older than the bundled one', () async {
    await writeCachedSceneJson('home', version: 0);

    await const DemoContentSeeder().seed(cacheRoot);

    final sceneJson = await readCachedSceneJson('home');
    expect(sceneJson['version'], greaterThan(0));
    expect(sceneJson['objects'], hasLength(expectedObjectCounts['home']!));
    expect(await File(p.join(cachedSceneDir('home').path, 'background.png')).exists(), isTrue);
  });

  test('leaves a cached scene alone when it is not older than the bundled one', () async {
    await writeCachedSceneJson('home', version: 999);

    await const DemoContentSeeder().seed(cacheRoot);

    final sceneJson = await readCachedSceneJson('home');
    expect(sceneJson['version'], 999);
    expect(sceneJson['title'], 'Cached');
  });

  test('leaves cached scenes that are not bundled untouched', () async {
    await writeCachedSceneJson('other', version: 1);

    await const DemoContentSeeder().seed(cacheRoot);

    expect((await readCachedSceneJson('other'))['title'], 'Cached');
  });
}
