import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'content_repository.dart';

/// Copies the bundled placeholder scenes into the content cache the first
/// time the app runs with an empty cache, so there is something to see and
/// tap before any real hosted content has been published. Once real content
/// exists, `ContentRepository.refresh` naturally replaces it (a real
/// scene's higher `version` wins) — no special-casing needed.
class DemoContentSeeder {
  const DemoContentSeeder();

  static const _bundleRoot = 'assets/demo_content';
  static const _sceneIds = ['home', 'kitchen', 'farm', 'street', 'bathroom'];

  Future<void> seedIfEmpty(Directory cacheRoot) async {
    final contentCacheDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName));
    if (await contentCacheDir.exists()) {
      final hasAnyScene = await contentCacheDir.list().any((e) => e is Directory);
      if (hasAnyScene) return;
    }

    for (final sceneId in _sceneIds) {
      await _seedScene(contentCacheDir, sceneId);
    }
  }

  Future<void> _seedScene(Directory contentCacheDir, String sceneId) async {
    final bundleDir = '$_bundleRoot/$sceneId';
    final sceneJson = jsonDecode(await rootBundle.loadString('$bundleDir/scene.json')) as Map<String, dynamic>;
    final objectAudioFiles = (sceneJson['objects'] as List<dynamic>)
        .map((object) => (object as Map<String, dynamic>)['audio'] as String);
    final files = ['scene.json', 'background.png', 'thumb.png', ...objectAudioFiles];

    final targetDir = Directory(p.join(contentCacheDir.path, sceneId));
    await targetDir.create(recursive: true);
    for (final fileName in files) {
      final data = await rootBundle.load('$bundleDir/$fileName');
      await File(p.join(targetDir.path, fileName))
          .writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
  }
}
