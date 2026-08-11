import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';

Future<Directory> _tempCacheRoot() => Directory.systemTemp.createTemp('yandee_repo_test_');

Future<void> _seedScene(
  Directory cacheRoot,
  String id, {
  required int version,
  required String title,
}) async {
  final dir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, id));
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'scene.json')).writeAsString(jsonEncode({
    'id': id,
    'version': version,
    'title': title,
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': <Map<String, dynamic>>[],
  }));
  await File(p.join(dir.path, 'thumb.png')).writeAsBytes([1, 2, 3]);
}

void main() {
  late Directory cacheRoot;
  late ContentRepository repository;

  setUp(() async {
    cacheRoot = await _tempCacheRoot();
    repository = ContentRepository(
      httpClient: http.Client(),
      baseUrl: Uri.parse('https://example.invalid/v1/'),
      cacheRootProvider: () async => cacheRoot,
    );
  });

  tearDown(() async {
    if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
  });

  test('loadCachedIndex on an empty cache returns an empty list', () async {
    expect(await repository.loadCachedIndex(), isEmpty);
  });

  test('loadCachedIndex lists cached scenes sorted by title', () async {
    await _seedScene(cacheRoot, 'farm', version: 1, title: 'Ферма');
    await _seedScene(cacheRoot, 'city', version: 3, title: 'Город');

    final index = await repository.loadCachedIndex();

    expect(index.map((e) => e.id), ['city', 'farm']); // 'Город' < 'Ферма'
  });

  test('loadCachedIndex ignores __tmp directories and dirs without scene.json', () async {
    await _seedScene(cacheRoot, 'city', version: 1, title: 'Город');
    await Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'city__tmp'))
        .create(recursive: true);
    await Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'empty')).create(recursive: true);

    final index = await repository.loadCachedIndex();

    expect(index.map((e) => e.id), ['city']);
  });

  test('loadCachedIndex skips a scene with corrupted scene.json', () async {
    final dir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'broken'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'scene.json')).writeAsString('not json');

    expect(await repository.loadCachedIndex(), isEmpty);
  });

  test('loadScene returns null when the scene is not cached', () async {
    expect(await repository.loadScene('missing'), isNull);
  });

  test('loadScene returns the parsed scene and resolvable paths', () async {
    await _seedScene(cacheRoot, 'city', version: 3, title: 'Город');

    final cached = await repository.loadScene('city');

    expect(cached, isNotNull);
    expect(cached!.scene.id, 'city');
    expect(cached.scene.version, 3);
    expect(cached.backgroundPath, p.join(cached.directoryPath, 'background.png'));
  });
}
