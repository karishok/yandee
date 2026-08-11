import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../domain/models/scene.dart';
import 'cached_scene.dart';

/// Reads and writes the local scene cache, and (from Task 9's `refresh()`)
/// syncs it from static hosting. The UI only ever reads through
/// `loadCachedIndex`/`loadScene` — `refresh()` is the sole network path,
/// and it never throws: every failure just means "try again next time".
class ContentRepository {
  ContentRepository({
    required http.Client httpClient,
    required Uri baseUrl,
    required Future<Directory> Function() cacheRootProvider,
  })  : _httpClient = httpClient,
        _baseUrl = baseUrl,
        _cacheRootProvider = cacheRootProvider,
        assert(baseUrl.path.endsWith('/'), 'baseUrl must end with / so Uri.resolve keeps the full path');

  static const cacheSubdirName = 'content_cache';

  final http.Client _httpClient;
  final Uri _baseUrl;
  final Future<Directory> Function() _cacheRootProvider;

  Future<Directory> _cacheRoot() async {
    final dir = Directory(p.join((await _cacheRootProvider()).path, cacheSubdirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Scenes available right now, without touching the network, sorted by
  /// title for a stable list order.
  Future<List<CachedSceneSummary>> loadCachedIndex() async {
    final root = await _cacheRoot();
    final summaries = <CachedSceneSummary>[];
    await for (final entry in root.list()) {
      if (entry is! Directory || entry.path.endsWith('__tmp')) continue;
      final scene = await _readSceneJson(entry);
      if (scene == null) continue;
      summaries.add(CachedSceneSummary(
        id: scene.id,
        title: scene.title,
        thumbnailPath: p.join(entry.path, 'thumb.png'),
      ));
    }
    summaries.sort((a, b) => a.title.compareTo(b.title));
    return summaries;
  }

  /// Loads a scene `loadCachedIndex` reported as available. Returns null
  /// if it isn't (or is no longer) cached.
  Future<CachedScene?> loadScene(String sceneId) async {
    final root = await _cacheRoot();
    final dir = Directory(p.join(root.path, sceneId));
    final scene = await _readSceneJson(dir);
    if (scene == null) return null;
    return CachedScene(scene: scene, directoryPath: dir.path);
  }

  Future<Scene?> _readSceneJson(Directory sceneDir) async {
    final file = File(p.join(sceneDir.path, 'scene.json'));
    if (!await file.exists()) return null;
    try {
      return Scene.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupted cache entry: skip it, refresh() will re-download it
    }
  }
}
