import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/voiceover_queue.dart';
import '../../tool/src/voiceover_tasks.dart';

void main() {
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
    const systemTask = VoiceoverTask(text: 'Найди:', outputPath: 'assets/audio/system/find_intro.wav');

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
}
