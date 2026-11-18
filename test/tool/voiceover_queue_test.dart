import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/placeholder_wav.dart';
import '../../tool/src/voiceover_queue.dart';
import '../../tool/src/voiceover_tasks.dart';

void main() {
  test('placeholderWavSizeBytes matches the actual placeholder WAV builder', () {
    expect(buildSilentWav().length, placeholderWavSizeBytes);
  });

  group('isUnrecorded', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('voiceover_queue_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('true for a missing file', () {
      final file = File('${tempDir.path}/missing.wav');
      expect(isUnrecorded(file), isTrue);
    });

    test('true for a file at exactly the placeholder size', () {
      final file = File('${tempDir.path}/placeholder.wav')
        ..writeAsBytesSync(List.filled(placeholderWavSizeBytes, 0));
      expect(isUnrecorded(file), isTrue);
    });

    test('false for a file at any other size', () {
      final file = File('${tempDir.path}/recorded.wav')
        ..writeAsBytesSync(List.filled(placeholderWavSizeBytes + 500, 0));
      expect(isUnrecorded(file), isFalse);
    });
  });

  group('taskMatchesFilter', () {
    const kitchenTask = VoiceoverTask(text: 'Яблоко', outputPath: 'assets/demo_content/kitchen/apple.wav');
    const farmTask = VoiceoverTask(text: 'Корова', outputPath: 'assets/demo_content/farm/cow.wav');
    const systemTask = VoiceoverTask(text: 'Где', outputPath: 'assets/audio/system/find_intro.wav');

    test('null filter matches everything', () {
      expect(taskMatchesFilter(kitchenTask, null), isTrue);
      expect(taskMatchesFilter(systemTask, null), isTrue);
    });

    test('scene filter matches only that scene\'s objects', () {
      expect(taskMatchesFilter(kitchenTask, 'kitchen'), isTrue);
      expect(taskMatchesFilter(farmTask, 'kitchen'), isFalse);
      expect(taskMatchesFilter(systemTask, 'kitchen'), isFalse);
    });

    test('"system" filter matches only system phrases', () {
      expect(taskMatchesFilter(systemTask, 'system'), isTrue);
      expect(taskMatchesFilter(kitchenTask, 'system'), isFalse);
    });

    test('"monsters" filter matches only the colour game\'s phrases', () {
      const monstersTask = VoiceoverTask(text: 'Ням!', outputPath: 'assets/audio/monsters/yum.wav');
      expect(taskMatchesFilter(monstersTask, 'monsters'), isTrue);
      expect(taskMatchesFilter(monstersTask, 'system'), isFalse);
      expect(taskMatchesFilter(monstersTask, 'kitchen'), isFalse);
      expect(taskMatchesFilter(systemTask, 'monsters'), isFalse);
      expect(taskMatchesFilter(kitchenTask, 'monsters'), isFalse);
      expect(isValidSceneFilter('monsters'), isTrue);
    });

    test('the "Монстрики" phrases come in 10 parts of 5–10 that together cover all 70, once each', () {
      final all = buildMonstersVoiceoverTasks();
      List<String> part(int number) =>
          [for (final t in all) if (taskMatchesFilter(t, 'monsters-$number')) t.text];

      expect(part(1), [
        'Покорми монстриков! Красный ест красное, синий — синее.',
        'Ням!',
        'Фу!',
        'Спасибо! Пока-пока!',
        'Привет!',
        'Привет! Я новенький!',
        'Ура! Ты знаешь все цвета!',
      ]);
      expect(part(2), ['Я красный!', 'Я синий!', 'Я жёлтый!', 'Я зелёный!', 'Я оранжевый!', 'Я фиолетовый!']);
      expect(part(4).first, '— красному!');
      expect(part(6), [
        'Красная клубника',
        'Красный помидор',
        'Красное яблоко',
        'Красная вишня',
        'Синяя черника',
        'Синяя слива',
        'Синяя конфета',
        'Фиолетовый виноград',
        'Фиолетовый баклажан',
        'Фиолетовый леденец',
      ]);

      final parts = [for (var number = 1; number <= 10; number++) part(number)];
      for (final phrases in parts) {
        expect(phrases.length, inInclusiveRange(5, 10));
      }
      final together = parts.expand((phrases) => phrases).toList();
      expect(together, hasLength(70));
      expect(together.toSet(), hasLength(70));
      expect(together, [for (final t in all) t.text], reason: 'the parts, in order, are the whole list in order');
      expect(part(11), isEmpty);
    });

    test('every "Монстрики" part is a valid filter, and none leaks into scenes or system', () {
      const kitchen = VoiceoverTask(text: 'Яблоко', outputPath: 'assets/demo_content/kitchen/apple.wav');
      const system = VoiceoverTask(text: 'Где', outputPath: 'assets/audio/system/find_intro.wav');
      expect(monstersFilters, ['monsters', for (var number = 1; number <= 10; number++) 'monsters-$number']);
      for (final filter in monstersFilters) {
        expect(isValidSceneFilter(filter), isTrue, reason: filter);
        expect(taskMatchesFilter(kitchen, filter), isFalse, reason: filter);
        expect(taskMatchesFilter(system, filter), isFalse, reason: filter);
      }
      expect(isValidSceneFilter('monsters-11'), isFalse);
      expect(isValidSceneFilter('monsters-0'), isFalse);
    });
  });

  group('buildRecordingQueue', () {
    test('combines scene filter and unrecorded-check', () {
      const tasks = [
        VoiceoverTask(text: 'Яблоко', outputPath: 'assets/demo_content/kitchen/apple.wav'),
        VoiceoverTask(text: 'Хлеб', outputPath: 'assets/demo_content/kitchen/bread.wav'),
        VoiceoverTask(text: 'Корова', outputPath: 'assets/demo_content/farm/cow.wav'),
      ];

      final queue = buildRecordingQueue(
        tasks,
        sceneFilter: 'kitchen',
        isUnrecordedAt: (path) => path == 'assets/demo_content/kitchen/bread.wav',
      );

      expect(queue.map((t) => t.outputPath), ['assets/demo_content/kitchen/bread.wav']);
    });

    test('with no filter and everything unrecorded, returns all tasks', () {
      const tasks = [
        VoiceoverTask(text: 'Яблоко', outputPath: 'assets/demo_content/kitchen/apple.wav'),
        VoiceoverTask(text: 'Корова', outputPath: 'assets/demo_content/farm/cow.wav'),
      ];

      final queue = buildRecordingQueue(tasks, isUnrecordedAt: (_) => true);

      expect(queue.length, 2);
    });
  });

  group('isValidSceneFilter', () {
    test('null is valid', () {
      expect(isValidSceneFilter(null), isTrue);
    });

    test('"system" is valid', () {
      expect(isValidSceneFilter('system'), isTrue);
    });

    test('a real scene id is valid', () {
      expect(isValidSceneFilter('kitchen'), isTrue);
    });

    test('a typo\'d or unknown id is invalid', () {
      expect(isValidSceneFilter('kitchn'), isFalse);
    });

    test('wrong case is invalid', () {
      expect(isValidSceneFilter('Kitchen'), isFalse);
    });
  });
}
