import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/fft.dart';

void main() {
  group('fftInPlace', () {
    test('a unit impulse transforms to a flat, all-real spectrum', () {
      const n = 16;
      final real = Float64List(n)..[0] = 1.0;
      final imag = Float64List(n);

      fftInPlace(real, imag);

      for (var k = 0; k < n; k++) {
        expect(real[k], closeTo(1.0, 1e-9));
        expect(imag[k], closeTo(0.0, 1e-9));
      }
    });

    test('a DC signal transforms to all energy in bin 0', () {
      const n = 8;
      final real = Float64List(n)..fillRange(0, n, 1.0);
      final imag = Float64List(n);

      fftInPlace(real, imag);

      expect(real[0], closeTo(n.toDouble(), 1e-9));
      expect(imag[0], closeTo(0.0, 1e-9));
      for (var k = 1; k < n; k++) {
        expect(real[k], closeTo(0.0, 1e-9));
        expect(imag[k], closeTo(0.0, 1e-9));
      }
    });

    test('forward then inverse round-trips an arbitrary signal', () {
      const n = 256;
      final random = math.Random(7);
      final original = Float64List(n);
      for (var i = 0; i < n; i++) {
        original[i] = random.nextDouble() * 2 - 1;
      }

      final real = Float64List.fromList(original);
      final imag = Float64List(n);
      fftInPlace(real, imag);
      fftInPlace(real, imag, inverse: true);

      for (var i = 0; i < n; i++) {
        expect(real[i], closeTo(original[i], 1e-9));
        expect(imag[i], closeTo(0.0, 1e-9));
      }
    });
  });
}
