import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../domain/voice/voice_line.dart';
import 'clip_line_player.dart';
import 'shapes_voice.dart';

/// Where the live recordings of the game's phrases are, one `.wav` per clip
/// — written by `tool/slice_voiceover.dart shapes-<N>`.
const shapesRecordedVoiceDir = 'assets/audio/shapes';

// Every phrase is recorded, so there are no computer-voice stand-ins; the
// folder is only named so a missing recording is skipped, not half-said.
const _shapesSynthVoiceDir = 'assets/audio/shapes_tts';

/// The asset files to play for [line] in the "Фигурки" game.
List<String> shapesVoiceAssets(VoiceLine line, Set<String> bundled) =>
    voiceAssets(line, bundled, recordedDir: shapesRecordedVoiceDir, synthDir: _shapesSynthVoiceDir);

/// Plays the "Фигурки" phrases and sound effects.
class ShapesVoicePlayer implements ShapesVoice {
  ShapesVoicePlayer({AssetBundle? bundle, AudioPlayer Function() playerFactory = AudioPlayer.new})
      : _lines = ClipLinePlayer(
          recordedDir: shapesRecordedVoiceDir,
          synthDir: _shapesSynthVoiceDir,
          bundled: listBundledAssets(bundle ?? rootBundle),
          playerFactory: playerFactory,
        ),
        _sfx = SfxPlayer(playerFactory: playerFactory);

  final ClipLinePlayer _lines;
  final SfxPlayer _sfx;

  @override
  Future<void> say(VoiceLine line) => _lines.say(line);

  @override
  void playSfx(ShapesSfx sfx) => _sfx.play(sfx.fileName);

  @override
  void stop() => _lines.stop();

  @override
  void dispose() {
    _lines.dispose();
    _sfx.dispose();
  }
}
