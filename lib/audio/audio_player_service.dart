import 'dart:async' show unawaited;
import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';
import '../domain/modes/scene_mode_effects.dart';
import 'audio_sink.dart';

const Map<SystemPhrase, String> _systemPhraseAssets = {
  SystemPhrase.findIntro: 'audio/system/find_intro.wav',
  SystemPhrase.wrongHint: 'audio/system/wrong_hint.wav',
  SystemPhrase.correct: 'audio/system/correct.wav',
  SystemPhrase.roundComplete: 'audio/system/round_complete.wav',
};

/// Thin `audioplayers` wrapper. Playback errors are logged and swallowed —
/// per spec, sound must never block gameplay.
class AudioPlayerService implements AudioSink {
  AudioPlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> playFile(String absolutePath) => _playSafely(DeviceFileSource(absolutePath));

  @override
  Future<void> playSystemPhrase(SystemPhrase phrase) =>
      _playSafely(AssetSource(_systemPhraseAssets[phrase]!));

  @override
  Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath) async {
    // Uses a dedicated, throwaway player for the intro instead of the
    // shared `_player`: `audioplayers` only fires `onPlayerComplete` for a
    // track that finishes naturally, not one that gets interrupted. If a
    // wrong tap during the intro fired `playSystemPhrase`/`playFile` on the
    // *shared* player, it would interrupt this wait's track without
    // completing it, leaving `await completed` to resolve off some later,
    // unrelated clip finishing instead — scrambling or dropping the name
    // that's supposed to play next. A private player can't be interrupted
    // by any other call, so its completion always means its own track.
    final introPlayer = AudioPlayer();
    try {
      final completed = introPlayer.onPlayerComplete.first;
      await introPlayer.play(AssetSource(_systemPhraseAssets[phrase]!));
      await completed;
    } catch (error, stackTrace) {
      developer.log('Audio playback failed', name: 'AudioPlayerService', error: error, stackTrace: stackTrace);
    } finally {
      unawaited(introPlayer.dispose());
    }
    await _playSafely(DeviceFileSource(objectAudioPath));
  }

  Future<void> _playSafely(Source source) async {
    try {
      await _player.play(source);
    } catch (error, stackTrace) {
      developer.log('Audio playback failed', name: 'AudioPlayerService', error: error, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() => _player.dispose();
}
