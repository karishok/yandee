import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:yandee/data/cached_scene.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/presentation/controllers/scene_controller.dart';
import 'package:yandee/presentation/widgets/scene_illustration.dart';

import '../../support/fake_audio_sink.dart';
import '../../support/fixture_assets.dart';

void main() {
  // Container is 800x800; a 400x300 (4:3) image inside it renders at
  // 800x600, letterboxed with 100px top/bottom margins.
  const ball = SceneObject(
    id: 'ball',
    label: 'Мяч',
    audio: 'ball.wav',
    rect: ObjectRect(x: 0.25, y: 0.5, width: 0.1, height: 0.2),
  );

  testWidgets('positions a tap zone at the object rect and dispatches taps', (tester) async {
    // `testWidgets` runs the whole test body inside a FakeAsync zone (that's
    // what makes pump()/pumpAndSettle() able to fast-forward animations).
    // Real dart:io operations — Directory.createTemp, File.writeAsBytes —
    // and FileImage's real native decode callback never complete inside
    // that zone; they need tester.runAsync() to step out to the real event
    // loop. Just as importantly, pumpWidget() itself must run *inside* the
    // same runAsync() as the setup, because the widget's initState captures
    // whatever zone is current when it calls ImageStream.addListener() —
    // if that capture happens in the fake zone (i.e. pumpWidget is called
    // outside runAsync), the completion callback is queued on FakeAsync's
    // deferred microtask queue and never flushed, no matter how long a
    // *subsequent* runAsync() waits in real time.
    late Directory tempDir;
    late CachedScene cachedScene;
    final audio = FakeAudioSink();

    // flutter_test's default window is 800x600 logical pixels, so the
    // SizedBox(800, 800) below would otherwise be clamped down to 800x600
    // by the tight constraints the test view imposes on MaterialApp's
    // home — coincidentally the same 4:3 ratio as the fixture image, which
    // would silently zero out the letterboxing this test exists to check.
    // Explicitly sizing the test surface makes the container really 800x800.
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('yandee_illustration_test_');
      await writeFixturePng(tempDir, 'background.png', width: 400, height: 300);

      cachedScene = CachedScene(
        scene: Scene(
          id: 'demo',
          version: 1,
          title: 'Демо',
          minAgeMonths: 12,
          background: 'background.png',
          objects: [ball],
        ),
        directoryPath: tempDir.path,
      );

      await tester.pumpWidget(MaterialApp(
        home: SizedBox(
          width: 800,
          height: 800,
          child: ChangeNotifierProvider(
            create: (_) => SceneController(cachedScene: cachedScene, audioSink: audio),
            child: SceneIllustration(cachedScene: cachedScene),
          ),
        ),
      ));

      // Poll with real delays + real pumps until the background image has
      // decoded and the widget has rebuilt with its tap zones.
      for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    addTearDown(() => tempDir.delete(recursive: true));

    final zoneFinder = find.byKey(const ValueKey('object_zone_ball'));
    expect(zoneFinder, findsOneWidget);

    final topLeft = tester.getTopLeft(zoneFinder);
    final size = tester.getSize(zoneFinder);
    expect(topLeft.dx, moreOrLessEquals(0.25 * 800));
    expect(topLeft.dy, moreOrLessEquals(100 + 0.5 * 600));
    expect(size.width, moreOrLessEquals(0.1 * 800));
    expect(size.height, moreOrLessEquals(0.2 * 600));

    await tester.tap(zoneFinder);
    await tester.pump();
    expect(audio.playedFiles, [cachedScene.audioPathFor(ball)]);
  });

  testWidgets('shows an error state instead of spinning forever when the background fails to decode', (
    tester,
  ) async {
    late Directory tempDir;
    late CachedScene cachedScene;
    final audio = FakeAudioSink();

    // Same zone requirement as above: the corrupt-image decode failure
    // (like the successful-decode callback) only fires the listener when
    // the whole setup + pumpWidget() runs inside a single runAsync() block.
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('yandee_illustration_error_test_');
      // Deliberately invalid PNG bytes: this must be caught by
      // ImageStreamListener's onError (which SceneIllustration now
      // provides), not left to crash the test via FlutterError.reportError.
      await File(p.join(tempDir.path, 'background.png')).writeAsBytes([1, 2, 3]);

      cachedScene = CachedScene(
        scene: Scene(
          id: 'demo',
          version: 1,
          title: 'Демо',
          minAgeMonths: 12,
          background: 'background.png',
          objects: [ball],
        ),
        directoryPath: tempDir.path,
      );

      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => SceneController(cachedScene: cachedScene, audioSink: audio),
          child: SceneIllustration(cachedScene: cachedScene),
        ),
      ));

      for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    addTearDown(() => tempDir.delete(recursive: true));

    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
