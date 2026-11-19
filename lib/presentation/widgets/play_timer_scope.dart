import 'package:flutter/material.dart';

import '../../audio/rest_phrase_player.dart';
import '../../domain/play_timer.dart';
import '../screens/rest_screen.dart';

/// Hands the app's [PlayTimer] down to every screen.
class PlayTimerProvider extends InheritedNotifier<PlayTimer> {
  const PlayTimerProvider({super.key, required PlayTimer timer, required super.child}) : super(notifier: timer);

  /// The timer, rebuilding the caller whenever it ticks.
  static PlayTimer of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayTimerProvider>()!.notifier!;

  /// The timer, without subscribing — for button handlers.
  static PlayTimer read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PlayTimerProvider>()!.notifier!;
}

/// Sits above the app's navigator (`MaterialApp.builder`): owns the play
/// timer, stops it counting while the app is off screen, and when time is
/// up puts the rest screen over whatever is open.
class PlayTimerScope extends StatefulWidget {
  const PlayTimerScope({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.timer,
    this.playRestPhrase,
  });

  /// The app's navigator — this widget sits above it, so it can't look it up.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// Tests pass their own; the scope then leaves disposing it to them.
  final PlayTimer? timer;
  final Future<void> Function()? playRestPhrase;

  @override
  State<PlayTimerScope> createState() => _PlayTimerScopeState();
}

class _PlayTimerScopeState extends State<PlayTimerScope> {
  late final PlayTimer _timer = widget.timer ?? PlayTimer();
  late final AppLifecycleListener _lifecycle;
  bool _restShown = false;

  @override
  void initState() {
    super.initState();
    _timer.addListener(_onTimerChanged);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => state == AppLifecycleState.resumed ? _timer.resume() : _timer.pause(),
    );
  }

  void _onTimerChanged() {
    if (!_timer.isExpired || _restShown) return;
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    _restShown = true;
    navigator
        .push(restRoute(playPhrase: widget.playRestPhrase ?? playRestPhrase))
        .whenComplete(() => _restShown = false);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer.removeListener(_onTimerChanged);
    if (widget.timer == null) _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlayTimerProvider(timer: _timer, child: widget.child);
}
