import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../domain/models/scene.dart';
import '../domain/models/scene_manifest_entry.dart';
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

  /// Downloads currently in progress, keyed by scene id. Lets overlapping
  /// `refresh()` calls (e.g. a double-tapped retry button) join an
  /// already-running download instead of racing a second one that would
  /// delete the first's in-progress `__tmp` directory out from under it.
  final Map<String, Future<void>> _inFlightDownloads = {};

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

  /// Fetches the remote index, downloads any new or updated scenes, and
  /// atomically swaps each one in only once fully downloaded. Never
  /// throws — any failure just means "try again on the next refresh()".
  Future<void> refresh() async {
    final List<SceneManifestEntry> remoteEntries;
    try {
      final response = await _httpClient.get(_baseUrl.resolve('index.json'));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      remoteEntries = (decoded['scenes'] as List<dynamic>)
          .map((e) => SceneManifestEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return; // offline or unreachable: keep serving whatever is cached
    }

    final root = await _cacheRoot();
    final pending = <Future<void>>[];
    for (final entry in remoteEntries) {
      final localVersion = (await _readSceneJson(Directory(p.join(root.path, entry.id))))?.version;
      if (localVersion != null && localVersion >= entry.version) continue;
      pending.add(_downloadSceneDeduped(root, entry));
    }
    await Future.wait(pending);
  }

  Future<void> _downloadSceneDeduped(Directory root, SceneManifestEntry entry) async {
    final existing = _inFlightDownloads[entry.id];
    if (existing != null) return existing;
    final future = _downloadScene(root, entry);
    _inFlightDownloads[entry.id] = future;
    try {
      await future;
    } finally {
      _inFlightDownloads.remove(entry.id);
    }
  }

  Future<void> _downloadScene(Directory root, SceneManifestEntry entry) async {
    final tmpDir = Directory(p.join(root.path, '${entry.id}__tmp'));
    try {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      await tmpDir.create(recursive: true);

      final sceneBytes = await _downloadBytes('${entry.id}/scene.json');
      final scene = Scene.fromJson(jsonDecode(utf8.decode(sceneBytes)) as Map<String, dynamic>);
      await File(p.join(tmpDir.path, 'scene.json')).writeAsBytes(sceneBytes);

      await File(p.join(tmpDir.path, scene.background))
          .writeAsBytes(await _downloadBytes('${entry.id}/${scene.background}'));

      // entry.thumbnail is already root-relative (e.g. "city/thumb.png");
      // it is stored locally under the fixed name "thumb.png", which is
      // what loadCachedIndex() expects regardless of the remote path.
      await File(p.join(tmpDir.path, 'thumb.png')).writeAsBytes(await _downloadBytes(entry.thumbnail));

      for (final object in scene.objects) {
        await File(p.join(tmpDir.path, object.audio))
            .writeAsBytes(await _downloadBytes('${entry.id}/${object.audio}'));
      }

      final finalDir = Directory(p.join(root.path, entry.id));
      if (await finalDir.exists()) await finalDir.delete(recursive: true);
      await tmpDir.rename(finalDir.path);
    } catch (_) {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      // Leave any previously cached version of this scene untouched; the
      // next refresh() call will retry.
    }
  }

  Future<List<int>> _downloadBytes(String relativePath) async {
    final response = await _httpClient.get(_baseUrl.resolve(relativePath));
    if (response.statusCode != 200) {
      throw HttpException('GET $relativePath -> ${response.statusCode}');
    }
    return response.bodyBytes;
  }
}
