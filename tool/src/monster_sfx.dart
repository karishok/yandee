import 'dart:math' as math;
import 'dart:typed_data';

/// The sound effects of the "Монстрики" game, synthesized the same way the
/// HTML prototype makes them with Web Audio: short gliding tones and
/// filtered bursts of noise. Generated rather than committed as opaque
/// blobs — to retune one, edit its recipe here and re-run
/// `dart run tool/generate_monster_sfx.dart`.
///
/// Every builder is deterministic (the noise comes from a seeded
/// generator), so regenerating never silently changes a file.

enum _Wave { sine, triangle }

enum _Filter { bandpass, highpass }

/// A mono mixing buffer the recipes below add tones and noise bursts into.
class _Mix {
  _Mix(this.sampleRate, double seconds) : samples = Float64List((sampleRate * seconds).round());

  final int sampleRate;
  final Float64List samples;
  final math.Random _random = math.Random(20261118);

  /// A tone that glides from [from] Hz to [to] Hz over [seconds], swelling
  /// in over 20 ms and dying away to silence by the end.
  void tone(
    double from,
    double seconds, {
    double? to,
    _Wave wave = _Wave.sine,
    double volume = .18,
    double at = 0,
  }) {
    final start = (at * sampleRate).round();
    final length = (seconds * sampleRate).round();
    const floor = 0.0001, attack = 0.02;
    var phase = 0.0;
    for (var i = 0; i < length && start + i < samples.length; i++) {
      final t = i / sampleRate;
      final frequency = to == null ? from : from * math.pow(to / from, t / seconds);
      phase += 2 * math.pi * frequency / sampleRate;
      // Exponential ramps, as Web Audio's exponentialRampToValueAtTime.
      final gain = t < attack
          ? floor * math.pow(volume / floor, t / attack)
          : volume * math.pow(floor / volume, (t - attack) / (seconds - attack));
      final value = switch (wave) {
        _Wave.sine => math.sin(phase),
        _Wave.triangle => 2 / math.pi * math.asin(math.sin(phase)),
      };
      samples[start + i] += gain * value;
    }
  }

  /// A burst of white noise that dies away quickly, passed through a
  /// filter centred on [frequency]: band-passed it is a soft "munch",
  /// high-passed it is the slap of a hand clap.
  void noise(
    double seconds, {
    double at = 0,
    double volume = .25,
    double frequency = 900,
    _Filter filter = _Filter.bandpass,
  }) {
    final start = (at * sampleRate).round();
    final length = (seconds * sampleRate).round();

    // A standard two-pole filter with Q = 1, the Web Audio default.
    final w0 = 2 * math.pi * frequency / sampleRate;
    final alpha = math.sin(w0) / 2;
    final cosW0 = math.cos(w0);
    final double b0, b1, b2;
    switch (filter) {
      case _Filter.bandpass:
        b0 = alpha;
        b1 = 0;
        b2 = -alpha;
      case _Filter.highpass:
        b0 = (1 + cosW0) / 2;
        b1 = -(1 + cosW0);
        b2 = (1 + cosW0) / 2;
    }
    final a0 = 1 + alpha, a1 = -2 * cosW0, a2 = 1 - alpha;

    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    // A few extra samples let the filter ring out instead of being cut.
    final tail = (0.01 * sampleRate).round();
    for (var i = 0; i < length + tail && start + i < samples.length; i++) {
      final x = i < length ? (_random.nextDouble() * 2 - 1) * math.pow(1 - i / length, 3) : 0.0;
      final y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
      samples[start + i] += volume * y;
    }
  }

  /// The mix scaled so its loudest sample sits at [peak], with the last few
  /// milliseconds ramped to true silence so the file can't end on a click.
  Float64List finish(double peak) {
    var loudest = 0.0;
    for (final sample in samples) {
      loudest = math.max(loudest, sample.abs());
    }
    final gain = loudest == 0 ? 0.0 : peak / loudest;
    final release = math.min(samples.length, (0.01 * sampleRate).round());
    for (var i = 0; i < samples.length; i++) {
      var value = samples[i] * gain;
      final fromEnd = samples.length - 1 - i;
      if (fromEnd < release) value *= fromEnd / release;
      samples[i] = value;
    }
    return samples;
  }
}

// When the two hands meet in the clapping animation, in seconds from its
// start (the animation lasts 0.9 s).
const _clapTimes = [.2, .56];

/// A treat is picked up, or a monster is poked: a short rising "boing".
Float64List buildBoing({required int sampleRate}) =>
    (_Mix(sampleRate, .3)..tone(300, .25, to: 700)).finish(.6);

/// Three quick munches.
Float64List buildChomp({required int sampleRate}) => (_Mix(sampleRate, .42)
      ..noise(.08)
      ..noise(.08, at: .14)
      ..noise(.08, at: .28))
    .finish(.7);

/// Two hand claps, timed to the clapping animation.
Float64List buildClap({required int sampleRate}) {
  final mix = _Mix(sampleRate, .72);
  for (final at in _clapTimes) {
    mix.noise(.09, at: at, volume: .55, frequency: 1800, filter: _Filter.highpass);
  }
  return mix.finish(.75);
}

/// A disgusted, sinking "bleh".
Float64List buildYuck({required int sampleRate}) => (_Mix(sampleRate, .45)
      ..tone(220, .35, to: 110, wave: _Wave.triangle, volume: .2)
      ..tone(180, .3, to: 90, wave: _Wave.triangle, volume: .12, at: .1))
    .finish(.65);

/// A monster slides away: a falling whistle.
Float64List buildLeave({required int sampleRate}) =>
    (_Mix(sampleRate, .45)..tone(600, .4, to: 200, volume: .12)).finish(.45);

/// A newcomer pops out: a quick springy rise.
Float64List buildPop({required int sampleRate}) => (_Mix(sampleRate, .3)
      ..tone(260, .16, to: 900, volume: .18)
      ..tone(900, .12, to: 700, volume: .1, at: .14))
    .finish(.6);

/// Every colour is known: a little fanfare with four claps of applause.
Float64List buildWin({required int sampleRate}) {
  final mix = _Mix(sampleRate, 1.75);
  const notes = [523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0];
  for (var i = 0; i < notes.length; i++) {
    mix.tone(notes[i], .3, wave: _Wave.triangle, volume: .14, at: i * .13);
  }
  for (var i = 0; i < 4; i++) {
    mix.noise(.09, at: .2 + i * .36, volume: .4, frequency: 1800, filter: _Filter.highpass);
  }
  return mix.finish(.7);
}

/// Every effect by the file name (without extension) the app plays it
/// from — these match `MonsterSfx.fileName` in `lib/audio/monster_voice.dart`.
const Map<String, Float64List Function({required int sampleRate})> monsterSfxBuilders = {
  'monster_boing': buildBoing,
  'monster_chomp': buildChomp,
  'monster_clap': buildClap,
  'monster_yuck': buildYuck,
  'monster_leave': buildLeave,
  'monster_pop': buildPop,
  'monster_win': buildWin,
};
