import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';
import 'package:yandee/presentation/screens/scene_list_screen.dart';

import '../../support/fixture_assets.dart';

// The brief's `_seedScene` writes raw placeholder bytes ([1, 2, 3]) for
// thumb.png. SceneListScreen's card renders that file through a real
// Image.file (no errorBuilder), and flutter_test runs widget tests against
// the real Skia image codec — decoding invalid PNG bytes throws
// asynchronously and gets reported via FlutterError.reportError, which
// fails the test at teardown ("Multiple exceptions ... at least one was
// unexpected") even though every explicit expect() already passed. We use
// the same `writeFixturePng` helper Tasks 12/13 introduced for
// background.png so thumb.png is real, decodable PNG data instead.
Future<void> _seedScene(Directory cacheRoot, String id, String title) async {
  final dir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, id));
  await dir.create(recursive: true);
  await writeFixturePng(dir, 'thumb.png', width: 64, height: 64);
  await File(p.join(dir.path, 'scene.json')).writeAsString(jsonEncode({
    'id': id,
    'version': 1,
    'title': title,
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': <Map<String, dynamic>>[],
  }));
}

// `testWidgets` bodies run inside a FakeAsync zone. Real dart:io calls
// (Directory.createTemp, File.writeAsBytes/readAsString, directory
// listing) never complete inside that zone, so all real I/O setup plus
// pumpWidget() (whose initState chain kicks off ContentRepository's real
// loadCachedIndex()/refresh() calls) must run inside a single
// tester.runAsync() block — same pattern Tasks 12/13 established for
// FileImage decoding. We poll with real delays + real pumps until
// SceneListScreen's own loading spinner clears, then give the trailing
// background refresh()+reload a little more real time to finish before
// leaving the real zone, so no dangling real Future/Timer survives past
// runAsync() and trips the test framework's pending-timer check.
Future<void> _pumpAndSettleReal(WidgetTester tester) async {
  for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

void main() {
  testWidgets('shows cached scenes as cards', (tester) async {
    late Directory cacheRoot;

    await tester.runAsync(() async {
      cacheRoot = await Directory.systemTemp.createTemp('yandee_list_test_');
      await _seedScene(cacheRoot, 'city', 'Город');
      await _seedScene(cacheRoot, 'farm', 'Ферма');
      final repository = ContentRepository(
        httpClient: MockClient((_) async => throw const SocketException('offline')),
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await tester.pumpWidget(MaterialApp(home: SceneListScreen(contentRepository: repository)));
      await _pumpAndSettleReal(tester);
    });
    addTearDown(() => cacheRoot.delete(recursive: true));

    await tester.pump();

    expect(find.text('Город'), findsOneWidget);
    expect(find.text('Ферма'), findsOneWidget);
  });

  testWidgets('shows a retry screen when the cache is empty and offline', (tester) async {
    late Directory cacheRoot;

    await tester.runAsync(() async {
      cacheRoot = await Directory.systemTemp.createTemp('yandee_list_test_empty_');
      final repository = ContentRepository(
        httpClient: MockClient((_) async => throw const SocketException('offline')),
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await tester.pumpWidget(MaterialApp(home: SceneListScreen(contentRepository: repository)));
      await _pumpAndSettleReal(tester);
    });
    addTearDown(() => cacheRoot.delete(recursive: true));

    await tester.pump();

    expect(find.text('Нет подключения'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('tapping a card navigates to SceneScreen', (tester) async {
    late Directory cacheRoot;

    await tester.runAsync(() async {
      cacheRoot = await Directory.systemTemp.createTemp('yandee_list_test_nav_');
      await _seedScene(cacheRoot, 'city', 'Город');
      // scene_list navigates by id; SceneScreen's own background load will
      // just spin (no background.png seeded) — enough to confirm navigation.
      final repository = ContentRepository(
        httpClient: MockClient((_) async => throw const SocketException('offline')),
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await tester.pumpWidget(MaterialApp(home: SceneListScreen(contentRepository: repository)));
      await _pumpAndSettleReal(tester);
    });
    addTearDown(() => cacheRoot.delete(recursive: true));

    await tester.pump();

    // From here on we deliberately stay OUTSIDE runAsync(): SceneScreen's
    // own loadScene() future (real dart:io, no background.png seeded) is
    // meant to still be pending so we catch it mid-load. Calling
    // pumpAndSettle() after the tap would hang forever, because
    // MaterialPageRoute's push lands on a screen showing an indeterminate
    // CircularProgressIndicator, which never lets pumpAndSettle's "no more
    // scheduled frames" condition become true (same root cause Task 12
    // diagnosed for image decode, here via the push transition instead). A
    // single bounded pump is enough to let the finite push transition
    // complete.
    await tester.tap(find.byKey(const ValueKey('scene_card_city')));
    // A bare pump() first lets Navigator actually insert the pushed route
    // (tap()'s Navigator.push happens synchronously, but without a frame in
    // between, the transition's AnimationController has no ticks yet and
    // the new route's ModalScope is still marked offstage) — only then does
    // advancing by the transition duration bring SceneScreen onstage.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CircularProgressIndicator), findsOneWidget); // SceneScreen's own loading state
  });

  testWidgets('shows a placeholder instead of the default red error box for a corrupt thumbnail', (tester) async {
    late Directory cacheRoot;

    await tester.runAsync(() async {
      cacheRoot = await Directory.systemTemp.createTemp('yandee_list_test_corrupt_thumb_');
      final dir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'bad'));
      await dir.create(recursive: true);
      // Deliberately invalid PNG bytes: exercises Image.file's errorBuilder
      // instead of a successful decode.
      await File(p.join(dir.path, 'thumb.png')).writeAsBytes([1, 2, 3]);
      await File(p.join(dir.path, 'scene.json')).writeAsString(jsonEncode({
        'id': 'bad',
        'version': 1,
        'title': 'Плохая',
        'minAgeMonths': 12,
        'background': 'background.png',
        'objects': <Map<String, dynamic>>[],
      }));

      final repository = ContentRepository(
        httpClient: MockClient((_) async => throw const SocketException('offline')),
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await tester.pumpWidget(MaterialApp(home: SceneListScreen(contentRepository: repository)));
      await _pumpAndSettleReal(tester);
    });
    addTearDown(() => cacheRoot.delete(recursive: true));

    await tester.pump();

    expect(find.text('Плохая'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
  });
}
