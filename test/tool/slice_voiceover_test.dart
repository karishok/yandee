import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/slice_voiceover.dart';

void main() {
  late Directory root;
  late String toolDir;

  setUp(() {
    root = Directory.systemTemp.createTempSync('slice_voiceover_test_');
    toolDir = '${root.path}/tool';
    Directory(toolDir).createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('findBounce', () {
    test('a path that exists is used as given', () {
      final file = File('${root.path}/take.wav')..writeAsBytesSync([0]);
      expect(findBounce(file.path, toolDir: toolDir)!.path, file.path);
    });

    test('a bare file name is also looked for in the tool folder', () {
      File('$toolDir/запись.wav').writeAsBytesSync([0]);
      expect(findBounce('запись.wav', toolDir: toolDir)!.path, '$toolDir/запись.wav');
    });

    test('a path with a folder in it is not second-guessed', () {
      File('$toolDir/take.wav').writeAsBytesSync([0]);
      expect(findBounce('elsewhere/take.wav', toolDir: toolDir), isNull);
    });

    test('a file that is nowhere gives null', () {
      expect(findBounce('missing.wav', toolDir: toolDir), isNull);
    });
  });

  test('recordingsNearby lists audio files in the project and tool folders, and nothing else', () {
    File('${root.path}/a.wav').writeAsBytesSync([0]);
    File('$toolDir/запись.WAV').writeAsBytesSync([0]);
    File('$toolDir/slice_voiceover.dart').writeAsBytesSync([0]);

    expect(
      recordingsNearby(root: root.path, toolDir: toolDir),
      ['${root.path}/a.wav', '$toolDir/запись.WAV'],
    );
  });
}
