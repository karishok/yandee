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
  AudioPlayerService({
    AudioPlayer? player,
    AudioPlayer? interruptiblePlayer,
    AudioPlayer Function() clipPlayerFactory = AudioPlayer.new,
  })  : _player = player ?? AudioPlayer(),
        _interruptiblePlayer = interruptiblePlayer ?? AudioPlayer(),
        _clipPlayerFactory = clipPlayerFactory;

  // Makes the throwaway player each clip that is waited on to its end gets
  // (see _playToEnd). Tests swap in a fake.
  final AudioPlayer Function() _clipPlayerFactory;

  final AudioPlayer _player;

  // The game queues things up behind these calls — the next name, the
  // round-complete fanfare, the return to Explore — so none of them may
  // wait on the native player without a limit. A player that never says a
  // clip started or ended (the app went to the background mid-phrase, the
  // audio route changed, a phone call cut in, a new clip was requested the
  // instant the last one finished) would otherwise leave the scene silent
  // and stuck until it is reopened. Local clips start within a fraction of
  // a second, so these limits are far from normal play.
  static const _startLimit = Duration(seconds: 3);

  // How long past its own length a clip may run before its end is assumed.
  static const _endSlack = Duration(seconds: 2);

  // Stands in for the length of a clip the player can't tell the length of;
  // longer than any phrase or name the app has.
  static const _unknownClipLength = Duration(seconds: 6);

  // A player dedicated to `playInterruptibleSystemPhrase`, kept separate
  // from `_player` (Find-mode target audio) so a rapid string of
  // wrong-answer hints can never cut off unrelated audio, or be cut off by
  // it. `AudioPlayer.play()` stops whatever that same player instance is
  // currently playing before starting the new source, which is exactly the
  // "latest call wins" behavior this method promises.
  final AudioPlayer _interruptiblePlayer;

  @override
  Future<void> playFile(String absolutePath) => _playSafely(DeviceFileSource(absolutePath));

  @override
  Future<void> playFileToEnd(String absolutePath) => _playToEnd(DeviceFileSource(absolutePath));

  @override
  Future<void> playSystemPhrase(SystemPhrase phrase) => _playToEnd(_phraseSource(phrase));

  @override
  Future<void> playInterruptibleSystemPhrase(SystemPhrase phrase) =>
      _playInterruptiblePhraseAndWait(phrase);

  @override
  void stopInterruptible() {
    // Errors are swallowed the same way playback errors are: stopping a
    // player that isn't playing is a no-op worth no noise, and a failure
    // here must never take gameplay down with it.
    unawaited(_interruptiblePlayer.stop().catchError(
          (Object error, StackTrace stackTrace) => developer.log(
            'Audio stop failed',
            name: 'AudioPlayerService',
            error: error,
            stackTrace: stackTrace,
          ),
        ));
  }

  @override
  Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath) async {
    await _playToEnd(_phraseSource(phrase));
    await _playSafely(DeviceFileSource(objectAudioPath));
  }

  Source _phraseSource(SystemPhrase phrase) => AssetSource(_systemPhraseAssets[phrase]!);

  // Plays a clip (a system phrase, or an object's name that must be heard
  // in full) on a dedicated, throwaway player and waits for it to actually
  // finish (not just start). A dedicated player is required
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
  //
  // Both waits are bounded (see _startLimit): the clip not being heard to
  // the end is a glitch, the game freezing behind it is not acceptable.
  Future<void> _playToEnd(Source source) async {
    final phrasePlayer = _clipPlayerFactory();
    try {
      // If the wait below is abandoned, this later fails with "stream
      // closed" when the player is disposed; that is not an error.
      final completed = phrasePlayer.onPlayerComplete.first..ignore();
      await phrasePlayer.play(source).timeout(_startLimit);
      final length = await _lengthOf(phrasePlayer) ?? _unknownClipLength;
      await completed.timeout(length + _endSlack);
    } catch (error, stackTrace) {
      developer.log('Audio playback failed', name: 'AudioPlayerService', error: error, stackTrace: stackTrace);
    } finally {
      unawaited(phrasePlayer.dispose());
    }
  }

  Future<void> _playInterruptiblePhraseAndWait(SystemPhrase phrase) async {
    try {
      final completed = _interruptiblePlayer.onPlayerComplete.first;
      await _interruptiblePlayer.play(_phraseSource(phrase));
      await completed;
    } catch (error, stackTrace) {
      developer.log('Audio playback failed', name: 'AudioPlayerService', error: error, stackTrace: stackTrace);
    }
  }

  Future<Duration?> _lengthOf(AudioPlayer player) async {
    try {
      return await player.getDuration().timeout(const Duration(seconds: 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _playSafely(Source source) async {
    try {
      await _player.play(source).timeout(_startLimit);
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
