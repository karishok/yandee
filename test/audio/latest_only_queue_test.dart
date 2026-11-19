import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/latest_only_queue.dart';

void main() {
  late List<String> started;
  late Map<String, Completer<void>> running;
  late LatestOnlyQueue<String> queue;

  // Each item "plays" until the test finishes it by name.
  setUp(() {
    started = [];
    running = {};
    queue = LatestOnlyQueue<String>((item) {
      started.add(item);
      return (running[item] = Completer<void>()).future;
    });
  });

  Future<void> finish(String item) async {
    running[item]!.complete();
    await Future<void>.delayed(Duration.zero);
  }

  test('the first item starts at once', () {
    queue.add('a');
    expect(started, ['a']);
  });

  test('a second item does not cut the first short — it waits', () async {
    queue.add('a');
    queue.add('b');
    expect(started, ['a']);

    await finish('a');
    expect(started, ['a', 'b']);
  });

  test('of several items asked for meanwhile, only the latest is played', () async {
    queue.add('a');
    queue.add('b');
    queue.add('c');
    queue.add('d');

    await finish('a');
    expect(started, ['a', 'd']);

    await finish('d');
    expect(started, ['a', 'd'], reason: 'b and c are skipped for good');
  });

  test('a future completes when its item has finished playing', () async {
    var aDone = false, bDone = false;
    queue.add('a').then((_) => aDone = true);
    queue.add('b').then((_) => bDone = true);

    await finish('a');
    expect(aDone, isTrue);
    expect(bDone, isFalse, reason: 'b has only just started');

    await finish('b');
    expect(bDone, isTrue);
  });

  test('a skipped item\'s future completes as soon as it is replaced', () async {
    var bDone = false;
    queue.add('a');
    queue.add('b').then((_) => bDone = true);
    queue.add('c');
    await Future<void>.delayed(Duration.zero);

    expect(bDone, isTrue);
    expect(started, ['a']);
  });

  test('after everything has finished, the next item starts at once again', () async {
    queue.add('a');
    await finish('a');
    queue.add('b');
    expect(started, ['a', 'b']);
  });

  test('clear forgets the waiting item, and the next one starts at once', () async {
    var bDone = false;
    queue.add('a');
    queue.add('b').then((_) => bDone = true);

    queue.clear();
    await Future<void>.delayed(Duration.zero);
    expect(bDone, isTrue);

    queue.add('c');
    expect(started, ['a', 'c']);

    // The item that was cut loose returning late must not disturb anything.
    await finish('a');
    queue.add('d');
    expect(started, ['a', 'c'], reason: 'c is still playing, so d waits');
    await finish('c');
    expect(started, ['a', 'c', 'd']);
  });

  test('an item that fails does not jam the queue', () async {
    final failing = LatestOnlyQueue<String>((item) async {
      started.add(item);
      if (item == 'bad') throw StateError('boom');
    });

    await expectLater(failing.add('bad'), throwsStateError);
    await failing.add('good');
    expect(started, ['bad', 'good']);
  });
}
