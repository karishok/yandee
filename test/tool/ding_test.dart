import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/ding.dart';

void main() {
  const sampleRate = 44100;

  double rms(Float64List samples, int start, int end) {
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      sum += samples[i] * samples[i];
    }
    return math.sqrt(sum / (end - start));
  }

  test('is roughly the length of a single short chime', () {
    final ding = buildDing(sampleRate: sampleRate);
    final seconds = ding.length / sampleRate;
    expect(seconds, greaterThan(0.3));
    expect(seconds, lessThan(0.8));
  });

  test('starts and ends at silence, so neither edge clicks', () {
    final ding = buildDing(sampleRate: sampleRate);
    // A chime that jumps straight to full amplitude pops on playback; so does
    // one cut off mid-wave. Both edges must ramp through ~zero.
    expect(ding.first.abs(), lessThan(0.01));
    expect(ding.last.abs(), lessThan(0.01));
  });

  test('decays instead of holding a flat tone', () {
    final ding = buildDing(sampleRate: sampleRate);
    final third = ding.length ~/ 3;
    final head = rms(ding, 0, third);
    final tail = rms(ding, ding.length - third, ding.length);
    // "Дзынь" is a struck bell, not a beep: the tail has to be well below
    // the strike, not merely a little quieter.
    expect(tail, lessThan(head / 4));
  });

  test('is loud enough to hear but never clips', () {
    final ding = buildDing(sampleRate: sampleRate);
    final peak = ding.fold<double>(0, (m, s) => math.max(m, s.abs()));
    expect(peak, greaterThan(0.5));
    expect(peak, lessThanOrEqualTo(1.0));
  });

  test('honours the sample rate it is given', () {
    final at22k = buildDing(sampleRate: 22050);
    final at44k = buildDing(sampleRate: 44100);
    // Same chime, twice the samples — not a chime played twice as fast.
    expect(at44k.length, closeTo(at22k.length * 2, 2));
  });
}
