import 'dart:math' as math;
import 'dart:typed_data';

/// In-place iterative radix-2 Cooley-Tukey FFT (decimation-in-time).
///
/// [real]/[imag] must be the same power-of-two length — that's the whole
/// signal for a plain FFT, or one STFT analysis frame when used from
/// `denoise.dart`. Set [inverse] for the inverse transform; the result is
/// normalized (divided by N) so `fft(fft(x, inverse: true))` round-trips.
void fftInPlace(Float64List real, Float64List imag, {bool inverse = false}) {
  final n = real.length;
  assert(imag.length == n, 'real/imag must be the same length');
  assert(n > 0 && (n & (n - 1)) == 0, 'FFT size must be a power of two, got $n');

  // Bit-reversal permutation, so the butterfly stages below can work
  // in-place.
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = real[i];
      real[i] = real[j];
      real[j] = tr;
      final ti = imag[i];
      imag[i] = imag[j];
      imag[j] = ti;
    }
  }

  final sign = inverse ? 1.0 : -1.0;
  for (var len = 2; len <= n; len <<= 1) {
    final half = len >> 1;
    final theta = sign * 2 * math.pi / len;
    final wReal = math.cos(theta);
    final wImag = math.sin(theta);
    for (var start = 0; start < n; start += len) {
      var curReal = 1.0;
      var curImag = 0.0;
      for (var k = 0; k < half; k++) {
        final evenIndex = start + k;
        final oddIndex = start + k + half;
        final oddReal = real[oddIndex] * curReal - imag[oddIndex] * curImag;
        final oddImag = real[oddIndex] * curImag + imag[oddIndex] * curReal;
        real[oddIndex] = real[evenIndex] - oddReal;
        imag[oddIndex] = imag[evenIndex] - oddImag;
        real[evenIndex] += oddReal;
        imag[evenIndex] += oddImag;
        final nextReal = curReal * wReal - curImag * wImag;
        final nextImag = curReal * wImag + curImag * wReal;
        curReal = nextReal;
        curImag = nextImag;
      }
    }
  }

  if (inverse) {
    for (var i = 0; i < n; i++) {
      real[i] /= n;
      imag[i] /= n;
    }
  }
}
