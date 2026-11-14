import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/audio_player_service.dart';

/// Stands in for a native player: records what it is asked to play and
/// only "finishes" a clip when the test says so.
class FakeAudioPlayer extends Fake implements AudioPlayer {
  FakeAudioPlayer({this.starts = true, this.length = const Duration(seconds: 1)});

  /// Whether `play` ever reports that playback has started.
  final bool starts;

  /// What the player reports as the clip's length.
  final Duration? length;

  final _completions = StreamController<void>.broadcast();
  final List<Source> played = [];
  bool disposed = false;

  /// The clip plays to its end.
  void finish() => _completions.add(null);

  @override
  Stream<void> get onPlayerComplete => _completions.stream;

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) {
    played.add(source);
    return starts ? Future<void>.value() : Completer<void>().future;
  }

  @override
  Future<Duration?> getDuration() async => length;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _completions.close();
  }
}

void main() {
  // The game waits on these calls: the next name, the round-complete
  // fanfare and the return to Explore all queue up behind them. So each
  // must come back even when the player never reports what it should —
  // otherwise one lost signal leaves the scene silent and stuck for good.
  group('playFileToEnd', () {
    testWidgets('comes back when the clip has played to its end, not before', (tester) async {
      final clipPlayer = FakeAudioPlayer();
      final service = AudioPlayerService(
        player: FakeAudioPlayer(),
        explorePlayer: FakeAudioPlayer(),
        interruptiblePlayer: FakeAudioPlayer(),
        clipPlayerFactory: () => clipPlayer,
      );
      var done = false;
      unawaited(service.playFileToEnd('/cache/fox.wav').then((_) => done = true));

      await tester.pump(const Duration(milliseconds: 500));
      expect(clipPlayer.played, hasLength(1));
      expect(done, isFalse);

      clipPlayer.finish();
      await tester.pump();
      expect(done, isTrue);
      expect(clipPlayer.disposed, isTrue);
    });

    testWidgets('gives up waiting when the end of the clip is never reported', (tester) async {
      final clipPlayer = FakeAudioPlayer(length: const Duration(seconds: 1));
      final service = AudioPlayerService(
        player: FakeAudioPlayer(),
        explorePlayer: FakeAudioPlayer(),
        interruptiblePlayer: FakeAudioPlayer(),
        clipPlayerFactory: () => clipPlayer,
      );
      var done = false;
      unawaited(service.playFileToEnd('/cache/fox.wav').then((_) => done = true));

      // Still within the clip's own length: keep waiting.
      await tester.pump(const Duration(milliseconds: 900));
      expect(done, isFalse);

      // Well past it, and still no word from the player.
      await tester.pump(const Duration(seconds: 5));
      expect(done, isTrue);
      expect(clipPlayer.disposed, isTrue);
    });

    testWidgets('gives up on a clip that never starts', (tester) async {
      final clipPlayer = FakeAudioPlayer(starts: false);
      final service = AudioPlayerService(
        player: FakeAudioPlayer(),
        explorePlayer: FakeAudioPlayer(),
        interruptiblePlayer: FakeAudioPlayer(),
        clipPlayerFactory: () => clipPlayer,
      );
      var done = false;
      unawaited(service.playFileToEnd('/cache/fox.wav').then((_) => done = true));

      await tester.pump(const Duration(seconds: 10));
      expect(done, isTrue);
      expect(clipPlayer.disposed, isTrue);
    });
  });

  testWidgets('playExploreFile comes back even when the name never starts', (tester) async {
    // SceneController holds every later Explore name back until this
    // returns, so a start that hangs must not hang it too.
    final service = AudioPlayerService(
      player: FakeAudioPlayer(),
      explorePlayer: FakeAudioPlayer(starts: false),
      interruptiblePlayer: FakeAudioPlayer(),
      clipPlayerFactory: FakeAudioPlayer.new,
    );
    var done = false;
    unawaited(service.playExploreFile('/cache/fox.wav').then((_) => done = true));

    await tester.pump(const Duration(seconds: 10));
    expect(done, isTrue);
  });
}
