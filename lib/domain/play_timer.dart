import 'dart:async';

import 'package:flutter/foundation.dart';

/// A play-time limit for one sitting, set by a parent in the parents menu.
///
/// Counts down in whole seconds and only while not [pause]d — the app
/// pauses it whenever it leaves the screen, so time the device spends
/// locked or in someone's pocket doesn't count. It is never stored:
/// closing the app ends it.
class PlayTimer extends ChangeNotifier {
  static const _tick = Duration(seconds: 1);

  Timer? _ticker;
  Duration? _limit;
  Duration _remaining = Duration.zero;
  bool _expired = false;
  bool _paused = false;

  /// Counting down (or paused partway); false once it has expired.
  bool get isRunning => _ticker != null;

  /// The limit ran out; stays true until [stop] or a new [start].
  bool get isExpired => _expired;

  Duration get remaining => _remaining;

  /// The limit last started with, while running or expired.
  Duration? get limit => _limit;

  void start(Duration limit) {
    assert(limit > Duration.zero);
    _ticker?.cancel();
    _limit = limit;
    _remaining = limit;
    _expired = false;
    _ticker = Timer.periodic(_tick, _onTick);
    notifyListeners();
  }

  void stop() {
    if (_ticker == null && !_expired && _limit == null) return;
    _ticker?.cancel();
    _ticker = null;
    _limit = null;
    _remaining = Duration.zero;
    _expired = false;
    notifyListeners();
  }

  void pause() => _paused = true;

  void resume() => _paused = false;

  void _onTick(Timer _) {
    if (_paused) return;
    _remaining -= _tick;
    if (_remaining <= Duration.zero) {
      _remaining = Duration.zero;
      _expired = true;
      _ticker?.cancel();
      _ticker = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
