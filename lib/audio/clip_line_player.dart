import 'dart:async';
import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../domain/voice/voice_line.dart';
import 'latest_only_queue.dart';

/// The asset files to play for [line], given every asset the app ships
/// ([bundled]): the live recordings `<recordedDir>/<id>.wav` when every clip
/// of the line has one, else the computer-voice stand-ins
/// `<synthDir>/<id>.m4a`, else nothing.
///
/// A line is said in the live voice only when *all* its clips have been
/// recorded, so one sentence never switches speaker halfway through.
List<String> voiceAssets(
  VoiceLine line,
  Set<String> bundled, {
  required String recordedDir,
  required String synthDir,
}) {
  final recorded = [for (final clip in line.clips) '$recordedDir/${clip.id}.wav'];
  if (recorded.every(bundled.contains)) return recorded;
  final synthesized = [for (final clip in line.clips) '$synthDir/${clip.id}.m4a'];
  if (synthesized.every(bundled.contains)) return synthesized;
  return const [];
}

/// Every asset the app ships, or an empty set if the list can't be read.
Future<Set<String>> listBundledAssets(AssetBundle bundle) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    return manifest.listAssets().toSet();
  } catch (error, stackTrace) {
    developer.log('Asset list unavailable', name: 'ClipLinePlayer', error: error, stackTrace: stackTrace);
    return const {};
  }
}

/// Says [VoiceLine]s through `audioplayers`, never one over another: what is
/// being said is said to its end, and of the lines asked for meanwhile only
/// the latest is said next (see [LatestOnlyQueue]). Like
/// `AudioPlayerService`, it logs and swallows playback errors: sound must
/// never stop a game.
class ClipLinePlayer {
  ClipLinePlayer({
    required this.recordedDir,
    required this.synthDir,
    required Future<Set<String>> bundled,
    AudioPlayer Function() playerFactory = AudioPlayer.new,
  })  : _bundled = bundled,
        _playerFactory = playerFactory;

  /// Folder of the live recordings, without a trailing slash.
  final String recordedDir;

  /// Folder of the computer-voice stand-ins, without a trailing slash.
  final String synthDir;

  final Future<Set<String>> _bundled;
  final AudioPlayer Function() _playerFactory;
  _Speaker? _speaker;
  bool _disposed = false;

  late final LatestOnlyQueue<VoiceLine> _lines = LatestOnlyQueue(_speak);

  /// Completes when [line] has been said to its end, or skipped or stopped.
  Future<void> say(VoiceLine line) => _disposed ? Future<void>.value() : _lines.add(line);

  Future<void> _speak(VoiceLine line) async {
    if (_disposed) return;
    // Each line gets a player of its own, so a line stopped by [stop] can
    // never be mistaken for a later one having finished.
    final speaker = _Speaker(_playerFactory());
    _speaker = speaker;
    try {
      final assets = voiceAssets(line, await _bundled, recordedDir: recordedDir, synthDir: synthDir);
      for (final asset in assets) {
        if (speaker.cancelled) break;
        await speaker.playToEnd(AssetSource(asset.substring('assets/'.length)));
      }
    } catch (error, stackTrace) {
      developer.log('Voice playback failed', name: 'ClipLinePlayer', error: error, stackTrace: stackTrace);
    } finally {
      if (identical(_speaker, speaker)) _speaker = null;
      speaker.dispose();
    }
  }

  /// Silences the line being said and forgets the one waiting, if any.
  void stop() {
    _lines.clear();
    _speaker?.cancel();
    _speaker = null;
  }

  /// Releases the native players. Call exactly once.
  void dispose() {
    stop();
    _disposed = true;
  }
}

/// Plays the short sounds in `assets/audio/system/<name>.wav`, one native
/// player per sound, on top of whatever else is sounding.
class SfxPlayer {
  SfxPlayer({AudioPlayer Function() playerFactory = AudioPlayer.new}) : _playerFactory = playerFactory;

  final AudioPlayer Function() _playerFactory;
  final Map<String, AudioPlayer> _players = {};
  bool _disposed = false;

  void play(String fileName) {
    if (_disposed) return;
    final player = _players.putIfAbsent(fileName, _playerFactory);
    unawaited(_quietly(player.play(AssetSource('audio/system/$fileName.wav'))));
  }

  void dispose() {
    _disposed = true;
    for (final player in _players.values) {
      unawaited(_quietly(player.dispose()));
    }
    _players.clear();
  }
}

Future<void> _quietly(Future<void> action) => action.catchError(
      (Object error, StackTrace stackTrace) =>
          developer.log('Audio call failed', name: 'ClipLinePlayer', error: error, stackTrace: stackTrace),
    );

/// One line being said: a player plus the means to cut it short.
class _Speaker {
  _Speaker(this._player);

  final AudioPlayer _player;
  final Completer<void> _cancelled = Completer<void>();

  // Same bounds as AudioPlayerService: a native player that never reports a
  // start or an end must not leave the game waiting forever.
  static const _startLimit = Duration(seconds: 3);
  static const _endSlack = Duration(seconds: 2);
  static const _unknownClipLength = Duration(seconds: 6);

  bool get cancelled => _cancelled.isCompleted;

  void cancel() {
    if (cancelled) return;
    _cancelled.complete();
    unawaited(_quietly(_player.stop()));
  }

  Future<void> playToEnd(Source source) async {
    final completed = _player.onPlayerComplete.first..ignore();
    await _player.play(source).timeout(_startLimit);
    if (cancelled) return;
    Duration? length;
    try {
      length = await _player.getDuration().timeout(const Duration(seconds: 1));
    } catch (_) {
      length = null;
    }
    await Future.any([completed, _cancelled.future]).timeout((length ?? _unknownClipLength) + _endSlack);
  }

  void dispose() => unawaited(_quietly(_player.dispose()));
}
