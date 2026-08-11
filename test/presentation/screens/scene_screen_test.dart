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

    await tester.tap(find.text('Найди'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('find_banner')), findsOneWidget);
    expect(find.text('Найди: Мяч'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object_zone_cat'))); // wrong
    await tester.pump();
    expect(find.text('Найди: Мяч'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object_zone_ball'))); // correct
    await tester.pump();
    expect(find.text('Найди: Кот'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object_zone_cat'))); // correct, last
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
}
