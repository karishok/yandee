import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('refresh', () {
    test('network failure leaves the cache untouched and does not throw', () async {
      await _seedScene(cacheRoot, 'city', version: 1, title: 'Город');
      final client = MockClient((request) async => throw const SocketException('offline'));
      final repo = ContentRepository(
        httpClient: client,
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await repo.refresh();

      final index = await repo.loadCachedIndex();
      expect(index.map((e) => e.id), ['city']);
    });

    test('a scene already at the remote version is not re-downloaded', () async {
      await _seedScene(cacheRoot, 'city', version: 3, title: 'Город');
      var sceneJsonRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/index.json') {
          return http.Response(
            jsonEncode({
              'scenesVersion': 3,
              'scenes': [
                {'id': 'city', 'version': 3, 'title': 'Город', 'thumbnail': 'city/thumb.png'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/v1/city/scene.json') sceneJsonRequests++;
        return http.Response('not found', 404);
      });
      final repo = ContentRepository(
        httpClient: client,
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await repo.refresh();

      expect(sceneJsonRequests, 0);
    });

    test('a newer remote version is downloaded and swapped in atomically', () async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/v1/index.json') {
          return http.Response(
            jsonEncode({
              'scenesVersion': 2,
              'scenes': [
                {'id': 'city', 'version': 2, 'title': 'Город', 'thumbnail': 'city/thumb.png'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (path == '/v1/city/scene.json') {
          return http.Response(
            jsonEncode({
              'id': 'city',
              'version': 2,
              'title': 'Город',
              'minAgeMonths': 12,
              'background': 'background.png',
              'objects': <Map<String, dynamic>>[
                {
                  'id': 'tree',
                  'label': 'Дерево',
                  'audio': 'tree.mp3',
                  'rect': {'x': 0.0, 'y': 0.0, 'width': 0.1, 'height': 0.1},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (path == '/v1/city/background.png') return http.Response.bytes([1, 2, 3], 200);
        if (path == '/v1/city/thumb.png') return http.Response.bytes([4, 5], 200);
        if (path == '/v1/city/tree.mp3') return http.Response.bytes([6, 7], 200);
        return http.Response('not found', 404);
      });
      final repo = ContentRepository(
        httpClient: client,
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await repo.refresh();

      final cached = await repo.loadScene('city');
      expect(cached, isNotNull);
      expect(cached!.scene.version, 2);
      expect(await File(cached.backgroundPath).exists(), isTrue);
      expect(await Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'city__tmp')).exists(), isFalse);
    });

    test('a failed asset download leaves a previously cached scene untouched', () async {
      await _seedScene(cacheRoot, 'city', version: 1, title: 'Город');
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/v1/index.json') {
          return http.Response(
            jsonEncode({
              'scenesVersion': 2,
              'scenes': [
                {'id': 'city', 'version': 2, 'title': 'Город', 'thumbnail': 'city/thumb.png'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (path == '/v1/city/scene.json') {
          return http.Response(
            jsonEncode({
              'id': 'city',
              'version': 2,
              'title': 'Город',
              'minAgeMonths': 12,
              'background': 'background.png',
              'objects': <Map<String, dynamic>>[],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        // background.png/thumb.png missing on the server -> 404
        return http.Response('not found', 404);
      });
      final repo = ContentRepository(
        httpClient: client,
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await repo.refresh();

      final cached = await repo.loadScene('city');
      expect(cached!.scene.version, 1); // unchanged
      expect(await Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'city__tmp')).exists(), isFalse);
    });
  });
}
