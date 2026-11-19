import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/play_timer.dart';
import 'package:yandee/presentation/screens/parental_gate_screen.dart';
import 'package:yandee/presentation/screens/rest_screen.dart';
import 'package:yandee/presentation/widgets/play_timer_scope.dart';

import '../../support/parental_gate_helper.dart';

class _Harness {
  final timer = PlayTimer();
  final navigatorKey = GlobalKey<NavigatorState>();
  var phrasesPlayed = 0;

  Widget build() => MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => PlayTimerScope(
          navigatorKey: navigatorKey,
          timer: timer,
          playRestPhrase: () async => phrasesPlayed++,
          child: child!,
        ),
        home: const Scaffold(body: Text('сцена')),
      );
}

void main() {
  testWidgets('when time is up the rest screen covers whatever is open, and says so once', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    h.timer.start(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RestScreen), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Пора отдохнуть!'), findsOneWidget);
    expect(find.text('сцена'), findsNothing, reason: 'the scene underneath is covered');
    expect(h.phrasesPlayed, 1);
    h.timer.stop();
  });

  testWidgets('the back button does not close the rest screen', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    h.timer.start(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RestScreen), findsOneWidget);
    h.timer.stop();
  });

  testWidgets('a parent passes the gate: the timer is off and the child is back where they were', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    h.timer.start(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rest_parents_button')));
    await tester.pumpAndSettle();
    expect(find.byType(ParentalGateScreen), findsOneWidget);
    await solveParentalGate(tester);

    expect(find.byType(RestScreen), findsNothing);
    expect(find.text('сцена'), findsOneWidget);
    expect(h.timer.isExpired, isFalse);
    expect(h.timer.isRunning, isFalse);
  });

  testWidgets('closing the gate leads back to the rest screen', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    h.timer.start(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rest_parents_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parental_gate_close')));
    await tester.pumpAndSettle();
    expect(find.byType(RestScreen), findsOneWidget);
    expect(h.timer.isExpired, isTrue);
    h.timer.stop();
  });

  testWidgets('time away from the screen does not count', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    h.timer.start(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 10));
    expect(h.timer.remaining, const Duration(seconds: 2));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(RestScreen), findsOneWidget);
    h.timer.stop();
  });
}
