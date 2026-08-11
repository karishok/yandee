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
  AudioPlayerService({AudioPlayer? player, AudioPlayer? interruptiblePlayer})
      : _player = player ?? AudioPlayer(),
        _interruptiblePlayer = interruptiblePlayer ?? AudioPlayer();

  final AudioPlayer _player;

  // A player dedicated to `playInterruptibleSystemPhrase`, kept separate
  // from `_player` (object taps / find-target audio) so a rapid string of
  // wrong-answer hints can never cut off unrelated audio, or be cut off by
  // it. `AudioPlayer.play()` stops whatever that same player instance is
  // currently playing before starting the new source, which is exactly the
  // "latest call wins" behavior this method promises.
  final AudioPlayer _interruptiblePlayer;

  @override
  Future<void> playFile(String absolutePath) => _playSafely(DeviceFileSource(absolutePath));

  @override
  Future<void> playSystemPhrase(SystemPhrase phrase) => _playPhraseAndWait(phrase);

  @override
  Future<void> playInterruptibleSystemPhrase(SystemPhrase phrase) =>
      _playSafely(AssetSource(_systemPhraseAssets[phrase]!), player: _interruptiblePlayer);

  @override
  Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath) async {
    await _playPhraseAndWait(phrase);
    await _playSafely(DeviceFileSource(objectAudioPath));
  }

  // Plays a system phrase on a dedicated, throwaway player and waits for it
  // to actually finish (not just start). A dedicated player is required
  // because `audioplayers` only fires `onPlayerComplete` for a track that
  // finishes naturally, not one that gets interrupted. If this played on
  // the *shared* player, any other call (e.g. `playFile`/`playSystemPhrase`
  // for a following prompt) firing while this phrase is still going would
  // interrupt it without completing it, leaving `await completed` to
  // resolve off some later, unrelated clip finishing instead — scrambling
  // or dropping the phrase. A private player can't be interrupted by any
  // other call, so its completion always means its own track, which in
  // turn means callers that `await` this can rely on the phrase having
  // truly finished before doing anything that should follow it.
  Future<void> _playPhraseAndWait(SystemPhrase phrase) async {
    final phrasePlayer = AudioPlayer();
    try {
      final completed = phrasePlayer.onPlayerComplete.first;
      await phrasePlayer.play(AssetSource(_systemPhraseAssets[phrase]!));
      await completed;
    } catch (error, stackTrace) {
      developer.log('Audio playback failed', name: 'AudioPlayerService', error: error, stackTrace: stackTrace);
    } finally {
      unawaited(phrasePlayer.dispose());
    }
  }

  Future<void> _playSafely(Source source, {AudioPlayer? player}) async {
    try {
      await (player ?? _player).play(source);
    } catch (error, stackTrace) {
      developer.log('Audio playback failed', name: 'AudioPlayerService', error: error, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    unawaited(_interruptiblePlayer.dispose());
  }
}
