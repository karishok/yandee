import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';
import 'package:yandee/data/demo_content_seeder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheRoot;

  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp('yandee_seeder_test_');
  });

  tearDown(() async {
    if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
  });

  test('seeds the bundled demo scene into an empty cache', () async {
    await const DemoContentSeeder().seedIfEmpty(cacheRoot);

    final demoDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
    expect(await File(p.join(demoDir.path, 'scene.json')).exists(), isTrue);
    expect(await File(p.join(demoDir.path, 'background.png')).exists(), isTrue);
    expect(await File(p.join(demoDir.path, 'thumb.png')).exists(), isTrue);
    for (final name in ['ball', 'cat', 'tree', 'sun']) {
      expect(await File(p.join(demoDir.path, '$name.wav')).exists(), isTrue);
    }
  });

  test('does nothing if the cache already has a scene', () async {
    final otherDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'other'));
    await otherDir.create(recursive: true);
    await File(p.join(otherDir.path, 'scene.json')).writeAsString('{}');

    await const DemoContentSeeder().seedIfEmpty(cacheRoot);

    final demoDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
    expect(await demoDir.exists(), isFalse);
  });
}
