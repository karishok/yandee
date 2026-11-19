import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/play_timer.dart';

void main() {
  testWidgets('expires exactly when the limit has run out', (tester) async {
    final timer = PlayTimer()..start(const Duration(seconds: 3));
    expect(timer.isRunning, isTrue);
    expect(timer.limit, const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    expect(timer.isExpired, isFalse);
    expect(timer.remaining, const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(timer.isExpired, isTrue);
    expect(timer.isRunning, isFalse);
    expect(timer.remaining, Duration.zero);
    timer.stop();
  });

  testWidgets('does not count while paused', (tester) async {
    final timer = PlayTimer()..start(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    timer.pause();
    await tester.pump(const Duration(seconds: 10));
    expect(timer.remaining, const Duration(seconds: 2));
    timer.resume();
    await tester.pump(const Duration(seconds: 2));
    expect(timer.isExpired, isTrue);
    timer.stop();
  });

  testWidgets('stop cancels the countdown and clears an expiry', (tester) async {
    final timer = PlayTimer()..start(const Duration(seconds: 2));
    timer.stop();
    await tester.pump(const Duration(seconds: 5));
    expect(timer.isRunning, isFalse);
    expect(timer.isExpired, isFalse);
    expect(timer.limit, isNull);

    timer.start(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(timer.isExpired, isTrue);
    timer.stop();
    expect(timer.isExpired, isFalse);
  });

  testWidgets('starting again restarts with the new limit', (tester) async {
    final timer = PlayTimer()..start(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    timer.start(const Duration(seconds: 5));
    expect(timer.remaining, const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 4));
    expect(timer.isExpired, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(timer.isExpired, isTrue);
    timer.stop();
  });

  testWidgets('tells its listeners about every change', (tester) async {
    final timer = PlayTimer();
    var notifications = 0;
    timer.addListener(() => notifications++);
    timer.start(const Duration(seconds: 2));
    expect(notifications, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(notifications, 3);
    timer.stop();
    expect(notifications, 4);
    timer.stop();
    expect(notifications, 4, reason: 'stopping a stopped timer changes nothing');
  });
}
