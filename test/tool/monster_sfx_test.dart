import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/monster_voice.dart';

import '../../tool/src/monster_sfx.dart';
import '../../tool/src/wav_io.dart';

void main() {
  const sampleRate = 44100;

  double peak(Float64List samples, [int start = 0, int? end]) {
    var loudest = 0.0;
    for (var i = start; i < (end ?? samples.length); i++) {
      loudest = math.max(loudest, samples[i].abs());
    }
    return loudest;
  }

  test('there is a recipe for exactly the effects the game plays', () {
    expect(monsterSfxBuilders.keys.toSet(), MonsterSfx.values.map((sfx) => sfx.fileName).toSet());
  });

  test('every effect is short, audible and never clips', () {
    monsterSfxBuilders.forEach((name, build) {
      final samples = build(sampleRate: sampleRate);
      final seconds = samples.length / sampleRate;
      expect(seconds, greaterThan(0.2), reason: name);
      expect(seconds, lessThan(2.0), reason: name);
      expect(peak(samples), greaterThan(0.3), reason: name);
      expect(peak(samples), lessThan(0.9), reason: name);
    });
  });

  test('every effect ends in silence, so it cannot click', () {
    monsterSfxBuilders.forEach((name, build) {
      expect(build(sampleRate: sampleRate).last.abs(), lessThan(0.001), reason: name);
    });
  });

  test('regenerating gives the very same sound', () {
    monsterSfxBuilders.forEach((name, build) {
      expect(build(sampleRate: sampleRate), build(sampleRate: sampleRate), reason: name);
    });
  });

  test('the two claps land where the hands meet in the animation', () {
    final clap = buildClap(sampleRate: sampleRate);
    int at(double seconds) => (seconds * sampleRate).round();
    // Quiet before the first clap and between the two...
    expect(peak(clap, 0, at(.19)), lessThan(0.02));
    expect(peak(clap, at(.40), at(.55)), lessThan(0.02));
    // ...and a slap at 0.2 s and at 0.56 s.
    expect(peak(clap, at(.20), at(.26)), greaterThan(0.3));
    expect(peak(clap, at(.56), at(.62)), greaterThan(0.3));
  });

  test('the generated files in assets/ are up to date with the recipes', () {
    monsterSfxBuilders.forEach((name, build) {
      final file = File('assets/audio/system/$name.wav');
      expect(file.existsSync(), isTrue, reason: 'run: dart run tool/generate_monster_sfx.dart');
      final onDisk = readMonoWav16(file);
      final fresh = build(sampleRate: sampleRate);
      expect(onDisk.sampleRate, sampleRate, reason: name);
      expect(onDisk.samples.length, fresh.length, reason: name);
      for (var i = 0; i < fresh.length; i += 97) {
        expect(onDisk.samples[i], closeTo(fresh[i], 1 / 16000), reason: '$name, sample $i');
      }
    });
  });
}
