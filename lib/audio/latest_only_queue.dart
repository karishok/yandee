import 'dart:async';

/// Runs one thing at a time, never cutting it short; while it runs, only
/// the most recent request waits its turn — anything asked for in between
/// is skipped.
///
/// This is how the app answers a child who taps faster than a voice can
/// speak: what is being said is said to its end, and then comes the answer
/// to the *last* thing they did, not a backlog of everything in between.
/// Scene taps follow the same rule.
class LatestOnlyQueue<T> {
  LatestOnlyQueue(this._run);

  final Future<void> Function(T item) _run;

  bool _running = false;
  bool _hasWaiting = false;
  T? _waiting;
  Completer<void>? _waitingDone;

  // Bumped by [clear]: a run that was in flight then must not touch the
  // queue's state when it finally returns.
  int _generation = 0;

  /// Runs [item] now if nothing is running; otherwise makes it the one
  /// that runs next, replacing whichever was waiting. The future completes
  /// when [item] has finished running — or straight away once it has been
  /// replaced or cleared without ever running.
  Future<void> add(T item) {
    final done = Completer<void>();
    if (!_running) {
      unawaited(_drain(item, done));
      return done.future;
    }
    _waitingDone?.complete();
    _waiting = item;
    _hasWaiting = true;
    _waitingDone = done;
    return done.future;
  }

  /// Forgets the waiting item and lets go of the running one: the next
  /// [add] runs at once. Stopping whatever the running item is doing is
  /// the caller's business.
  void clear() {
    _generation++;
    _running = false;
    _hasWaiting = false;
    _waiting = null;
    _waitingDone?.complete();
    _waitingDone = null;
  }

  // Runs [first], then whatever is waiting when it ends, and so on until
  // nothing is. Each item's own future ([firstDone], then the waiting
  // item's) completes the moment that item finishes — with its error, if
  // it failed, which never stops the items after it.
  Future<void> _drain(T first, Completer<void> firstDone) async {
    _running = true;
    final generation = _generation;
    var item = first;
    var done = firstDone;
    while (true) {
      try {
        await _run(item);
        if (!done.isCompleted) done.complete();
      } catch (error, stackTrace) {
        if (!done.isCompleted) done.completeError(error, stackTrace);
      }
      if (generation != _generation) return;
      if (!_hasWaiting) break;
      item = _waiting as T;
      done = _waitingDone!;
      _hasWaiting = false;
      _waiting = null;
      _waitingDone = null;
    }
    _running = false;
  }
}
