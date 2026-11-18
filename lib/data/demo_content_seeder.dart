import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'content_repository.dart';

/// Copies the scenes bundled with the app into the content cache, which is
/// the only place the UI reads scenes from.
///
/// Runs on every launch and is per-scene: a bundled scene is copied when
/// the cache doesn't have it yet, or has an older `version` of it. That is
/// what delivers scenes added (or updated) in an app update to a device
/// whose cache was already filled by an earlier version. A cached scene
/// that is the same version or newer — e.g. one `ContentRepository.refresh`
/// downloaded from hosting — is left alone, as are cached scenes that
/// aren't bundled at all.
class DemoContentSeeder {
  const DemoContentSeeder();

  static const _bundleRoot = 'assets/demo_content';
  static const _sceneIds = [
    'home',
    'kitchen',
    'farm',
    'street',
    'bathroom',
    'playground',
    'zoo',
    'forest',
    'toys',
    'sea',
  ];

  Future<void> seed(Directory cacheRoot) async {
    final contentCacheDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName));
    for (final sceneId in _sceneIds) {
      await _seedScene(contentCacheDir, sceneId);
    }
  }

  Future<void> _seedScene(Directory contentCacheDir, String sceneId) async {
    final bundleDir = '$_bundleRoot/$sceneId';
    final sceneJson = jsonDecode(await rootBundle.loadString('$bundleDir/scene.json')) as Map<String, dynamic>;

    final targetDir = Directory(p.join(contentCacheDir.path, sceneId));
    final cachedVersion = await _cachedVersion(targetDir);
    if (cachedVersion != null && cachedVersion >= (sceneJson['version'] as int)) return;

    final objects = (sceneJson['objects'] as List<dynamic>).cast<Map<String, dynamic>>();
    final objectAudioFiles = {
      for (final object in objects) object['audio'] as String,
      for (final object in objects)
        if (object['sound'] != null) object['sound'] as String,
    };
    // A scene may also ship a realistic picture the child can switch to.
    final realisticBackground = (sceneJson['realistic'] as Map<String, dynamic>?)?['background'] as String?;
    // scene.json goes last: it is what marks the scene as cached at this
    // version, so a copy interrupted partway is simply redone next launch.
    final files = [
      'background.png',
      if (realisticBackground != null) realisticBackground,
      'thumb.png',
      ...objectAudioFiles,
      'scene.json',
    ];

    await targetDir.create(recursive: true);
    for (final fileName in files) {
      final data = await rootBundle.load('$bundleDir/$fileName');
      await File(p.join(targetDir.path, fileName))
          .writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
  }

  /// The `version` of the scene cached in [sceneDir], or null if there is
  /// none (or its scene.json is unreadable, in which case it gets re-seeded).
  Future<int?> _cachedVersion(Directory sceneDir) async {
    final file = File(p.join(sceneDir.path, 'scene.json'));
    if (!await file.exists()) return null;
    try {
      return (jsonDecode(await file.readAsString()) as Map<String, dynamic>)['version'] as int?;
    } catch (_) {
      return null;
    }
  }
}
