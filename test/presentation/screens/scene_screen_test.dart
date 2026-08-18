import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';
import 'package:yandee/presentation/screens/scene_screen.dart';

import '../../support/fake_audio_sink.dart';
import '../../support/fixture_assets.dart';

Future<Directory> _seedCache() async {
  final cacheRoot = await Directory.systemTemp.createTemp('yandee_scene_screen_test_');
  final sceneDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
  await sceneDir.create(recursive: true);
  await writeFixturePng(sceneDir, 'background.png', width: 400, height: 300);
  await File(p.join(sceneDir.path, 'ball.wav')).writeAsBytes([0]);
  await File(p.join(sceneDir.path, 'cat.wav')).writeAsBytes([0]);
  await File(p.join(sceneDir.path, 'scene.json')).writeAsString(jsonEncode({
    'id': 'demo',
    'version': 1,
    'title': 'Демо',
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': [
      {
        'id': 'ball',
        'label': 'Мяч',
        'audio': 'ball.wav',
        'rect': {'x': 0.0, 'y': 0.0, 'width': 0.2, 'height': 0.2},
      },
      {
        'id': 'cat',
        'label': 'Кот',
        'audio': 'cat.wav',
        'rect': {'x': 0.5, 'y': 0.5, 'width': 0.2, 'height': 0.2},
      },
    ],
  }));
  return cacheRoot;
}

// A scene with a single object authored right at the top-left corner of the
// illustration — the same corner the back button now lives in. Regression
// coverage for the illustration's top inset: it must clear the whole top
// bar (back button, find banner, mode switch), or this object's tap zone
// would sit right under the back button.
Future<Directory> _seedCacheWithCornerObject() async {
  final cacheRoot = await Directory.systemTemp.createTemp('yandee_scene_screen_corner_test_');
  final sceneDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
  await sceneDir.create(recursive: true);
  await writeFixturePng(sceneDir, 'background.png', width: 400, height: 300);
  await File(p.join(sceneDir.path, 'corner.wav')).writeAsBytes([0]);
  await File(p.join(sceneDir.path, 'scene.json')).writeAsString(jsonEncode({
    'id': 'demo',
    'version': 1,
    'title': 'Демо',
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': [
      {
        'id': 'corner',
        'label': 'Угол',
        'audio': 'corner.wav',
        'rect': {'x': 0.0, 'y': 0.0, 'width': 0.15, 'height': 0.15},
      },
    ],
  }));
  return cacheRoot;
}

// A scene with a single object authored right at the top-right corner of the
// illustration — the corner the mode switch (and, in Find mode, the find
// banner stacked underneath it) lives in. Regression coverage for the
// illustration's top inset accounting for the *taller*, two-row chrome
// Find mode shows: the banner sits directly below the mode switch, so this
// corner's tap zone must clear both rows, not just the switch alone.
Future<Directory> _seedCacheWithTopRightCornerObject() async {
  final cacheRoot = await Directory.systemTemp.createTemp('yandee_scene_screen_top_right_test_');
  final sceneDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
  await sceneDir.create(recursive: true);
  await writeFixturePng(sceneDir, 'background.png', width: 400, height: 300);
  await File(p.join(sceneDir.path, 'corner.wav')).writeAsBytes([0]);
  await File(p.join(sceneDir.path, 'scene.json')).writeAsString(jsonEncode({
    'id': 'demo',
    'version': 1,
    'title': 'Демо',
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': [
      {
        'id': 'corner',
        'label': 'Угол',
        'audio': 'corner.wav',
        'rect': {'x': 0.85, 'y': 0.0, 'width': 0.15, 'height': 0.15},
      },
    ],
  }));
  return cacheRoot;
}

void main() {
  testWidgets('opens in explore mode; switching to find shows the banner and completing it shows congrats', (tester) async {
    late Directory cacheRoot;
    final audio = FakeAudioSink();
    late ContentRepository repository;

    // `testWidgets` bodies run inside a FakeAsync zone. Real dart:io calls
    // (Directory.createTemp, File.writeAsBytes) and FileImage's real native
    // decode callback never complete inside that zone, so all real I/O
    // setup plus pumpWidget() (whose initState chain triggers
    // SceneIllustration's FileImage.resolve().addListener(), which captures
    // whatever zone is current at that moment) must run inside the same
    // tester.runAsync() block used to wait for the image decode.
    await tester.runAsync(() async {
      cacheRoot = await _seedCache();

      repository = ContentRepository(
        httpClient: http.Client(),
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await tester.pumpWidget(MaterialApp(
        home: SceneScreen(
          contentRepository: repository,
          sceneId: 'demo',
          audioSinkFactory: () => audio,
        ),
      ));

      // Poll with real delays + real pumps until both the scene load
      // (async loadScene future) and the background image decode have
      // completed and the widget has rebuilt with its tap zones.
      for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    addTearDown(() => cacheRoot.delete(recursive: true));

    await tester.pump();

    expect(find.byKey(const ValueKey('mode_switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('find_banner')), findsNothing);
    expect(find.byKey(const ValueKey('congrats_overlay')), findsNothing);

    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('find_banner')), findsOneWidget);
    expect(find.text('Мяч'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('object_zone_cat')))); // wrong
    await tester.pump();
    expect(find.text('Мяч'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('object_zone_ball')))); // correct
    await tester.pump();
    expect(find.text('Кот'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('object_zone_cat')))); // correct, last
    await tester.pump();

    expect(find.byKey(const ValueKey('congrats_overlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('find_banner')), findsNothing);

    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('congrats_overlay')), findsNothing);
    final toggle = tester.widget<ToggleButtons>(find.byType(ToggleButtons));
    expect(toggle.isSelected, [true, false]); // back to Explore
  });

  testWidgets('back button pops the route', (tester) async {
    late Directory cacheRoot;
    final audio = FakeAudioSink();
    late ContentRepository repository;

    // Same zone caveat as the test above: SceneScreen's initState (real
    // loadScene()) and SceneIllustration's FileImage listener registration
    // both need to run inside the same runAsync() zone as the setup I/O, so
    // the push that mounts SceneScreen happens inside runAsync() too.
    await tester.runAsync(() async {
      cacheRoot = await _seedCache();
      repository = ContentRepository(
        httpClient: http.Client(),
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SceneScreen(
                    contentRepository: repository,
                    sceneId: 'demo',
                    audioSinkFactory: () => audio,
                  ),
                )),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ));

      // Not pumpAndSettle(): SceneScreen briefly shows an indeterminate
      // CircularProgressIndicator while loadScene() resolves, and that
      // never lets pumpAndSettle's "no more scheduled frames" condition
      // become true. A bare pump() lands the push transition's first frame,
      // then advancing by the transition duration completes it (same
      // pattern as scene_list_screen_test.dart's navigation test).
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    addTearDown(() => cacheRoot.delete(recursive: true));

    await tester.pump();

    expect(find.byKey(const ValueKey('scene_back_button')), findsOneWidget);
    expect(find.text('Open'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('scene_back_button')));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('a scene missing from the cache shows an error state instead of spinning forever', (tester) async {
    late Directory cacheRoot;

    await tester.runAsync(() async {
      cacheRoot = await Directory.systemTemp.createTemp('yandee_scene_screen_missing_test_');
      final repository = ContentRepository(
        httpClient: http.Client(),
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await tester.pumpWidget(MaterialApp(
        home: SceneScreen(
          contentRepository: repository,
          sceneId: 'missing', // never seeded: loadScene resolves to null
          audioSinkFactory: () => FakeAudioSink(),
        ),
      ));

      for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    addTearDown(() => cacheRoot.delete(recursive: true));

    await tester.pump();

    expect(find.text('Не удалось открыть сцену'), findsOneWidget);
    expect(find.text('Назад'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the back button never overlaps a tap zone near the top-left corner', (tester) async {
    late Directory cacheRoot;
    final audio = FakeAudioSink();
    late ContentRepository repository;

    await tester.runAsync(() async {
      cacheRoot = await _seedCacheWithCornerObject();

      repository = ContentRepository(
        httpClient: http.Client(),
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await tester.pumpWidget(MaterialApp(
        home: SceneScreen(
          contentRepository: repository,
          sceneId: 'demo',
          audioSinkFactory: () => audio,
        ),
      ));

      for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    addTearDown(() => cacheRoot.delete(recursive: true));

    await tester.pump();

    final backButtonFinder = find.byKey(const ValueKey('scene_back_button'));
    final cornerZoneFinder = find.byKey(const ValueKey('object_zone_corner'));
    expect(backButtonFinder, findsOneWidget);
    expect(cornerZoneFinder, findsOneWidget);

    final backButtonRect = tester.getRect(backButtonFinder);
    final cornerZoneRect = tester.getRect(cornerZoneFinder);
    expect(
      backButtonRect.overlaps(cornerZoneRect),
      isFalse,
      reason: 'back button $backButtonRect must not overlap the corner tap zone $cornerZoneRect',
    );

    // Also confirm the tap zone is genuinely reachable (not just
    // geometrically clear): tapping it must still dispatch to the
    // controller, not silently hit the back button underneath it.
    await tester.tapAt(tester.getCenter(cornerZoneFinder));
    await tester.pump();
    final expectedAudioPath =
        p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo', 'corner.wav');
    expect(audio.playedFiles, [expectedAudioPath]);
  });

  testWidgets(
    'in Find mode, the mode switch + banner never overlap a tap zone near the top-right corner',
    (tester) async {
      late Directory cacheRoot;
      final audio = FakeAudioSink();
      late ContentRepository repository;

      await tester.runAsync(() async {
        cacheRoot = await _seedCacheWithTopRightCornerObject();

        repository = ContentRepository(
          httpClient: http.Client(),
          baseUrl: Uri.parse('https://example.invalid/v1/'),
          cacheRootProvider: () async => cacheRoot,
        );

        await tester.pumpWidget(MaterialApp(
          home: SceneScreen(
            contentRepository: repository,
            sceneId: 'demo',
            audioSinkFactory: () => audio,
          ),
        ));

        for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      addTearDown(() => cacheRoot.delete(recursive: true));

      await tester.pump();
      await tester.tap(find.text('Найти'));
      await tester.pumpAndSettle();

      final modeSwitchFinder = find.byKey(const ValueKey('mode_switch'));
      final bannerFinder = find.byKey(const ValueKey('find_banner'));
      final cornerZoneFinder = find.byKey(const ValueKey('object_zone_corner'));
      expect(modeSwitchFinder, findsOneWidget);
      expect(bannerFinder, findsOneWidget);
      expect(cornerZoneFinder, findsOneWidget);

      final cornerZoneRect = tester.getRect(cornerZoneFinder);
      final modeSwitchRect = tester.getRect(modeSwitchFinder);
      final bannerRect = tester.getRect(bannerFinder);
      expect(
        modeSwitchRect.overlaps(cornerZoneRect),
        isFalse,
        reason: 'mode switch $modeSwitchRect must not overlap the corner tap zone $cornerZoneRect',
      );
      expect(
        bannerRect.overlaps(cornerZoneRect),
        isFalse,
        reason: 'find banner $bannerRect must not overlap the corner tap zone $cornerZoneRect',
      );

      // And genuinely reachable, not silently swallowed by chrome on top:
      // the scene's only object is the current Find target, so a real tap
      // reaching the controller completes the round immediately.
      await tester.tapAt(tester.getCenter(cornerZoneFinder));
      await tester.pump();
      expect(find.byKey(const ValueKey('congrats_overlay')), findsOneWidget);
    },
  );
}
