import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';
import 'package:yandee/presentation/screens/scene_screen.dart';
import 'package:yandee/presentation/widgets/scene_illustration.dart';

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

// A scene that also has a realistic picture, on which the ball sits
// somewhere else than on the default one. The second object is authored at
// the illustration's top-left corner — right under where the picture toggle
// lives — to cover the toggle never sitting on top of a tap zone.
Future<Directory> _seedCacheWithRealisticPicture() async {
  final cacheRoot = await Directory.systemTemp.createTemp('yandee_scene_screen_realistic_test_');
  final sceneDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
  await sceneDir.create(recursive: true);
  await writeFixturePng(sceneDir, 'background.png', width: 400, height: 300);
  await writeFixturePng(sceneDir, 'background_real.png', width: 400, height: 300);
  await File(p.join(sceneDir.path, 'ball.wav')).writeAsBytes([0]);
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
      {
        'id': 'ball',
        'label': 'Мяч',
        'audio': 'ball.wav',
        'rect': {'x': 0.1, 'y': 0.6, 'width': 0.2, 'height': 0.2},
      },
    ],
    'realistic': {
      'background': 'background_real.png',
      'rects': {
        'ball': {'x': 0.7, 'y': 0.6, 'width': 0.2, 'height': 0.2},
      },
    },
  }));
  return cacheRoot;
}

// A farm-like scene: five animals with a sound of their own (enough for
// finding by sound), the first with an outline (so the flashlight is there
// too).
Future<Directory> _seedCacheWithSounds() async {
  final cacheRoot = await Directory.systemTemp.createTemp('yandee_scene_screen_sounds_test_');
  final sceneDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
  await sceneDir.create(recursive: true);
  await writeFixturePng(sceneDir, 'background.png', width: 400, height: 300);
  const animals = {'cow': 'Корова', 'pig': 'Свинья', 'hen': 'Курица', 'horse': 'Лошадь', 'duck': 'Утка'};
  final ids = animals.keys.toList();
  for (final id in ids) {
    await File(p.join(sceneDir.path, '$id.wav')).writeAsBytes([0]);
    await File(p.join(sceneDir.path, '${id}_sound.wav')).writeAsBytes([0]);
  }
  await File(p.join(sceneDir.path, 'scene.json')).writeAsString(jsonEncode({
    'id': 'demo',
    'version': 1,
    'title': 'Демо',
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': [
      for (var i = 0; i < ids.length; i++)
        {
          'id': ids[i],
          'label': animals[ids[i]],
          'audio': '${ids[i]}.wav',
          'sound': '${ids[i]}_sound.wav',
          'rect': {'x': 0.02 + i * 0.19, 'y': 0.4, 'width': 0.15, 'height': 0.15},
          if (i == 0)
            'outline': [
              [0.02, 0.4],
              [0.17, 0.4],
              [0.1, 0.55],
            ],
        },
    ],
  }));
  return cacheRoot;
}

// Opens the scene in [cacheRoot] and waits until it is on screen (see the
// first test for why all of this runs inside runAsync).
Future<void> _openScene(WidgetTester tester, Future<Directory> Function() seed, FakeAudioSink audio,
    void Function(Directory) onCacheRoot) async {
  await tester.runAsync(() async {
    final cacheRoot = await seed();
    onCacheRoot(cacheRoot);
    final repository = ContentRepository.local(cacheRootProvider: () async => cacheRoot);
    await tester.pumpWidget(MaterialApp(
      home: SceneScreen(contentRepository: repository, sceneId: 'demo', audioSinkFactory: () => audio),
    ));
    for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  });
  await tester.pump();
}

// Like _pumpUntilFound, for a condition on what has been played.
Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 20 && !condition(); i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

// Find mode advances only once the "correct" chime has finished playing,
// i.e. after several async hops through SceneController's voice queue. That
// queue's first future is created while the scene loads — inside
// tester.runAsync(), so in the real zone — and a continuation chained onto
// it is scheduled there too, where the FakeAsync-driven tester.pump()
// can't reach it. So after a correct tap, alternate real event-loop turns
// (for those hops) with pumped frames (for the hops and rebuilds that
// belong to the test zone) until [finder] shows the round has moved on.
// Bounded: if it never does, the caller's own expect() reports the failure.
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
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

    // FindMode now picks the round's order at random (see find_mode.dart),
    // so which of the two objects is prompted first isn't fixed — read it
    // off the rendered banner instead of assuming "Мяч" goes first.
    const zoneIdForLabel = {'Мяч': 'ball', 'Кот': 'cat'};
    final firstLabel = find.text('Мяч').evaluate().isNotEmpty ? 'Мяч' : 'Кот';
    final secondLabel = firstLabel == 'Мяч' ? 'Кот' : 'Мяч';
    expect(find.text(firstLabel), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byKey(ValueKey('object_zone_${zoneIdForLabel[secondLabel]}')))); // wrong
    await tester.pump();
    expect(find.text(firstLabel), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byKey(ValueKey('object_zone_${zoneIdForLabel[firstLabel]}')))); // correct
    await _pumpUntilFound(tester, find.text(secondLabel));
    expect(find.text(secondLabel), findsOneWidget);

    await tester.tapAt(
      tester.getCenter(find.byKey(ValueKey('object_zone_${zoneIdForLabel[secondLabel]}'))),
    ); // correct, last
    await _pumpUntilFound(tester, find.byKey(const ValueKey('congrats_overlay')));

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
      await _pumpUntilFound(tester, find.byKey(const ValueKey('congrats_overlay')));
      expect(find.byKey(const ValueKey('congrats_overlay')), findsOneWidget);
    },
  );

  testWidgets('a scene with a realistic picture has a toggle that switches the picture and its tap zones', (
    tester,
  ) async {
    late Directory cacheRoot;
    final audio = FakeAudioSink();

    await tester.runAsync(() async {
      cacheRoot = await _seedCacheWithRealisticPicture();
      final repository = ContentRepository.local(cacheRootProvider: () async => cacheRoot);

      await tester.pumpWidget(MaterialApp(
        home: SceneScreen(contentRepository: repository, sceneId: 'demo', audioSinkFactory: () => audio),
      ));

      for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    addTearDown(() => cacheRoot.delete(recursive: true));
    await tester.pump();

    final toggleFinder = find.byKey(const ValueKey('picture_toggle'));
    final ballZoneFinder = find.byKey(const ValueKey('object_zone_ball'));
    expect(toggleFinder, findsOneWidget);
    expect(
      tester.getRect(toggleFinder).overlaps(tester.getRect(find.byKey(const ValueKey('object_zone_corner')))),
      isFalse,
      reason: 'the picture toggle must not cover a tap zone in the top-left corner',
    );

    final illustrationWidth = tester.getSize(find.byType(SceneIllustration)).width;
    final defaultBallRect = tester.getRect(ballZoneFinder);

    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    // On the realistic picture the ball is authored 0.6 of the picture's
    // width further right, so its tap zone must have moved there.
    final realisticBallRect = tester.getRect(ballZoneFinder);
    expect(realisticBallRect.left - defaultBallRect.left, greaterThan(illustrationWidth * 0.4));

    // The old spot is now empty; the new one names the ball.
    final ballAudioPath = p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo', 'ball.wav');
    await tester.tapAt(defaultBallRect.center);
    await tester.pump();
    expect(audio.playedFiles, isEmpty);
    await tester.tapAt(realisticBallRect.center);
    await tester.pump();
    expect(audio.playedFiles, [ballAudioPath]);

    // And the toggle goes back again.
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();
    expect(tester.getRect(ballZoneFinder), defaultBallRect);
  });

  testWidgets('a scene with only the default picture has no picture toggle', (tester) async {
    late Directory cacheRoot;

    await tester.runAsync(() async {
      cacheRoot = await _seedCache();
      final repository = ContentRepository.local(cacheRootProvider: () async => cacheRoot);

      await tester.pumpWidget(MaterialApp(
        home: SceneScreen(
          contentRepository: repository,
          sceneId: 'demo',
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

    expect(find.byKey(const ValueKey('mode_switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('picture_toggle')), findsNothing);
  });

  testWidgets('the flashlight button is in Explore only, the ear button in Find only', (tester) async {
    final audio = FakeAudioSink();
    await _openScene(tester, _seedCacheWithSounds, audio, (root) => addTearDown(() => root.delete(recursive: true)));

    expect(find.byKey(const ValueKey('flashlight_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('who_says_button')), findsNothing);

    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flashlight_button')), findsNothing);
    expect(find.byKey(const ValueKey('who_says_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('find_banner')), findsOneWidget);
  });

  testWidgets('while the flashlight is on, Explore stays highlighted', (tester) async {
    final audio = FakeAudioSink();
    await _openScene(tester, _seedCacheWithSounds, audio, (root) => addTearDown(() => root.delete(recursive: true)));

    await tester.tap(find.byKey(const ValueKey('flashlight_button')));
    await tester.pump();
    expect(tester.widget<ToggleButtons>(find.byType(ToggleButtons)).isSelected, [true, false]);

    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('find_banner')), findsOneWidget);
  });

  testWidgets('the ear button finds by sound: a repeat button instead of the name, Find highlighted', (tester) async {
    final audio = FakeAudioSink();
    await _openScene(tester, _seedCacheWithSounds, audio, (root) => addTearDown(() => root.delete(recursive: true)));
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('who_says_button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('find_banner')), findsNothing);
    expect(find.byKey(const ValueKey('who_says_repeat')), findsOneWidget);
    expect(tester.widget<ToggleButtons>(find.byType(ToggleButtons)).isSelected, [false, true]);
    for (final label in ['Корова', 'Свинья', 'Курица', 'Лошадь', 'Утка']) {
      expect(find.text(label), findsNothing, reason: 'the name would give the answer away');
    }

    bool introWithSound() => audio.playedSequences.any(
          (s) => s.$1 == SystemPhrase.findIntro && s.$2.endsWith('_sound.wav'),
        );
    await _pumpUntil(tester, introWithSound);
    expect(introWithSound(), isTrue);

    await tester.tap(find.byKey(const ValueKey('who_says_repeat')));
    await _pumpUntil(tester, () => audio.playedFiles.isNotEmpty);
    expect(audio.playedFiles.single, endsWith('_sound.wav'));

    await tester.tap(find.byKey(const ValueKey('who_says_button')));
    await tester.pump();
    expect(find.byKey(const ValueKey('find_banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('who_says_repeat')), findsNothing);
  });

  testWidgets('a scene with too few sounds has no ear button in Find', (tester) async {
    await _openScene(tester, _seedCache, FakeAudioSink(), (root) => addTearDown(() => root.delete(recursive: true)));
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('who_says_button')), findsNothing);
  });
}
