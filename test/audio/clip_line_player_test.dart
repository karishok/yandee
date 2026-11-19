import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/clip_line_player.dart';
import 'package:yandee/domain/voice/voice_line.dart';

void main() {
  const line = VoiceLine([VoiceClip('new_shape', 'Новая фигурка!'), VoiceClip('shape_star', 'Звезда!')]);
  List<String> assets(Set<String> bundled) =>
      voiceAssets(line, bundled, recordedDir: 'assets/audio/shapes', synthDir: 'assets/audio/shapes_tts');

  test('a fully recorded line plays the live recordings from the given folder', () {
    expect(assets({'assets/audio/shapes/new_shape.wav', 'assets/audio/shapes/shape_star.wav'}), [
      'assets/audio/shapes/new_shape.wav',
      'assets/audio/shapes/shape_star.wav',
    ]);
  });

  test('a half-recorded line with no stand-ins is skipped rather than half-said', () {
    expect(assets({'assets/audio/shapes/new_shape.wav'}), isEmpty);
  });

  test('stand-ins from the synth folder fill in when the live voice is missing', () {
    expect(assets({'assets/audio/shapes_tts/new_shape.m4a', 'assets/audio/shapes_tts/shape_star.m4a'}),
        ['assets/audio/shapes_tts/new_shape.m4a', 'assets/audio/shapes_tts/shape_star.m4a']);
  });

  test('a line reads as its clips one after another', () {
    expect(line.text, 'Новая фигурка! Звезда!');
  });
}
