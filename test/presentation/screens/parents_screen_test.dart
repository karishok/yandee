import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/play_timer.dart';
import 'package:yandee/platform/external_links.dart';
import 'package:yandee/presentation/screens/about_screen.dart';
import 'package:yandee/presentation/screens/guided_access_screen.dart';
import 'package:yandee/presentation/screens/parents_screen.dart';
import 'package:yandee/presentation/widgets/play_timer_scope.dart';

class _Harness {
  final timer = PlayTimer();
  final opened = <Uri>[];
  var opens = true;

  Widget build({TargetPlatform platform = TargetPlatform.iOS}) => PlayTimerProvider(
        timer: timer,
        child: MaterialApp(
          home: ParentsScreen(
            openLink: (uri) async {
              opened.add(uri);
              return opens;
            },
            readVersion: () async => '1.2.0 (5)',
            platform: platform,
          ),
        ),
      );
}

void main() {
  testWidgets('has the timer, app lock, feedback, rating and about entries', (tester) async {
    await tester.pumpWidget(_Harness().build());
    expect(find.text('Для родителей'), findsOneWidget);
    expect(find.text('Таймер игры'), findsOneWidget);
    for (final key in ['settings_guided_access_tile', 'parents_feedback_tile', 'parents_rate_tile', 'parents_about_tile']) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('choosing 15 minutes starts the timer and shows what is left; «Выкл» stops it', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    expect(find.byKey(const ValueKey('play_timer_remaining')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('play_timer_15')));
    await tester.pump();
    expect(h.timer.isRunning, isTrue);
    expect(h.timer.limit, const Duration(minutes: 15));
    expect(find.text('Осталось 15 мин'), findsOneWidget);

    await tester.pump(const Duration(seconds: 61));
    expect(find.text('Осталось 14 мин'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play_timer_0')));
    await tester.pump();
    expect(h.timer.isRunning, isFalse);
    expect(find.byKey(const ValueKey('play_timer_remaining')), findsNothing);
  });

  testWidgets('the app-lock entry still leads to the Guided Access instructions', (tester) async {
    await tester.pumpWidget(_Harness().build());
    await tester.tap(find.byKey(const ValueKey('settings_guided_access_tile')));
    await tester.pumpAndSettle();
    expect(find.byType(GuidedAccessScreen), findsOneWidget);
  });

  testWidgets('«Написать нам» writes a letter with the version in its subject', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.tap(find.byKey(const ValueKey('parents_feedback_tile')));
    await tester.pumpAndSettle();
    expect(h.opened, [feedbackMailUri('1.2.0 (5)')]);
  });

  testWidgets('without a mail app the address is shown instead', (tester) async {
    final h = _Harness()..opens = false;
    await tester.pumpWidget(h.build());
    await tester.tap(find.byKey(const ValueKey('parents_feedback_tile')));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось открыть почту. Напишите на $feedbackEmail'), findsOneWidget);
  });

  testWidgets('«Оценить» opens the store of the platform', (tester) async {
    final ios = _Harness();
    await tester.pumpWidget(ios.build());
    await tester.tap(find.byKey(const ValueKey('parents_rate_tile')));
    await tester.pumpAndSettle();
    expect(ios.opened, [appStoreReviewUri]);

    final android = _Harness();
    await tester.pumpWidget(android.build(platform: TargetPlatform.android));
    await tester.tap(find.byKey(const ValueKey('parents_rate_tile')));
    await tester.pumpAndSettle();
    expect(android.opened, [ruStoreUri]);
  });

  testWidgets('«О приложении» opens the About screen', (tester) async {
    await tester.pumpWidget(_Harness().build());
    await tester.scrollUntilVisible(find.byKey(const ValueKey('parents_about_tile')), 100);
    await tester.tap(find.byKey(const ValueKey('parents_about_tile')));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
  });
}
