import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/silence_split.dart';

const _sampleRate = 44100;

Float64List _silence(int ms) => Float64List((_sampleRate * ms / 1000).round());

Float64List _tone(int ms, {double freq = 440, double amp = 0.5}) {
  final n = (_sampleRate * ms / 1000).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = amp * math.sin(2 * math.pi * freq * i / _sampleRate);
  }
  return out;
}

Float64List _concat(List<Float64List> parts) {
  final total = parts.fold<int>(0, (sum, p) => sum + p.length);
  final out = Float64List(total);
  var offset = 0;
  for (final p in parts) {
    out.setAll(offset, p);
    offset += p.length;
  }
  return out;
}

double _sampleToSec(int sample) => sample / _sampleRate;

void main() {
  group('splitOnSilence', () {
    test('a clip of pure silence produces no segments', () {
      final samples = _silence(1000);
      expect(splitOnSilence(samples, _sampleRate), isEmpty);
    });

    test('finds exactly N segments at expected boundaries when silence exceeds minSilenceMs', () {
      final samples = _concat([
        _silence(200),
        _tone(300),
        _silence(700),
        _tone(300),
        _silence(700),
        _tone(300),
        _silence(200),
      ]);

      final segments = splitOnSilence(samples, _sampleRate);

      expect(segments, hasLength(3));
      const tolerance = 0.03; // window granularity (20ms) plus rounding
      expect(_sampleToSec(segments[0].startSample), closeTo(0.15, tolerance));
      expect(_sampleToSec(segments[0].endSample), closeTo(0.55, tolerance));
      expect(_sampleToSec(segments[1].startSample), closeTo(1.15, tolerance));
      expect(_sampleToSec(segments[1].endSample), closeTo(1.55, tolerance));
      expect(_sampleToSec(segments[2].startSample), closeTo(2.15, tolerance));
      expect(_sampleToSec(segments[2].endSample), closeTo(2.55, tolerance));
    });

    test('collapses two tones separated by silence shorter than minSilenceMs into one segment', () {
      final samples = _concat([
        _silence(300),
        _tone(300),
        _silence(200), // < default minSilenceMs (500ms)
        _tone(300),
        _silence(300),
      ]);

      final segments = splitOnSilence(samples, _sampleRate);

      expect(segments, hasLength(1));
      const tolerance = 0.03;
      expect(_sampleToSec(segments.single.startSample), closeTo(0.25, tolerance));
      expect(_sampleToSec(segments.single.endSample), closeTo(1.15, tolerance));
    });

    test('does not count a burst shorter than minWordMs as a word', () {
      final samples = _concat([
        _silence(600),
        _tone(80), // < default minWordMs (150ms)
        _silence(600),
      ]);

      expect(splitOnSilence(samples, _sampleRate), isEmpty);
    });

    test('clamps padding at the start/end of the clip for edge words', () {
      final samples = _concat([
        _tone(300), // starts at sample 0, no room to pad left
        _silence(700),
        _tone(300), // ends exactly at the clip's last sample, no room to pad right
      ]);

      final segments = splitOnSilence(samples, _sampleRate);

      expect(segments, hasLength(2));
      expect(segments.first.startSample, 0);
      expect(segments.last.endSample, samples.length);
    });
  });
}
