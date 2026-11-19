import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/monster_voice_player.dart';
import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/domain/monsters/monster_food.dart';
import 'package:yandee/domain/monsters/monster_phrases.dart';

void main() {
  const blueberry = MonsterFood(FoodKind.blueberry, MonsterColor.blue);
  final line = MonsterPhrases.refused(blueberry); // «Фу!» + «Синяя черника» + «— синему!»

  const synthesized = {
    'assets/audio/monsters_tts/yuck.m4a',
    'assets/audio/monsters_tts/food_blue_blueberry.m4a',
    'assets/audio/monsters_tts/for_blue.m4a',
  };
  const recorded = {
    'assets/audio/monsters/yuck.wav',
    'assets/audio/monsters/food_blue_blueberry.wav',
    'assets/audio/monsters/for_blue.wav',
  };

  group('monsterVoiceAssets', () {
    test('with nothing recorded yet, the whole line is in the computer voice', () {
      expect(monsterVoiceAssets(line, synthesized), [
        'assets/audio/monsters_tts/yuck.m4a',
        'assets/audio/monsters_tts/food_blue_blueberry.m4a',
        'assets/audio/monsters_tts/for_blue.m4a',
      ]);
    });

    test('once every clip of the line is recorded, the live voice is used', () {
      expect(monsterVoiceAssets(line, {...synthesized, ...recorded}), [
        'assets/audio/monsters/yuck.wav',
        'assets/audio/monsters/food_blue_blueberry.wav',
        'assets/audio/monsters/for_blue.wav',
      ]);
    });

    test('a half-recorded line stays in the computer voice — no change of speaker mid-sentence', () {
      final bundled = {...synthesized, 'assets/audio/monsters/yuck.wav'};
      expect(monsterVoiceAssets(line, bundled), everyElement(startsWith('assets/audio/monsters_tts/')));
    });

    test('a line with no audio at all is skipped rather than half-said', () {
      expect(monsterVoiceAssets(line, const {'assets/audio/monsters_tts/yuck.m4a'}), isEmpty);
    });
  });

  test('every phrase of the game has its stand-in computer-voice file in assets/', () {
    for (final clip in MonsterPhrases.allClips) {
      final file = File('$monsterSynthVoiceDir/${clip.id}.m4a');
      expect(file.existsSync(), isTrue, reason: '${clip.text}: run dart run tool/generate_monster_tts.dart');
      expect(file.lengthSync(), greaterThan(500), reason: clip.text);
    }
  });

  test('the asset folders the player reads from are declared in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- $monsterRecordedVoiceDir/'));
    expect(pubspec, contains('- $monsterSynthVoiceDir/'));
  });
}
