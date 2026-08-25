import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/presentation/screens/guided_access_screen.dart';

void main() {
  // debugDefaultTargetPlatformOverride must be back to null before the test
  // framework's own end-of-test invariant check runs, which happens before
  // addTearDown()/tearDown() callbacks fire — so it's reset in a finally
  // inside the test body itself, not via addTearDown.
  testWidgets('shows iOS-specific steps on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(const MaterialApp(home: GuidedAccessScreen()));

      expect(find.textContaining('Направленный доступ'), findsWidgets);
      expect(find.textContaining('Закрепление приложения'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shows Android-specific steps on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(const MaterialApp(home: GuidedAccessScreen()));

      expect(find.textContaining('Закрепление приложения'), findsWidgets);
      expect(find.textContaining('Направленный доступ'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // The "Открыть настройки" shortcut only exists on Android — on iOS the
  // only public deep link lands on this app's own Settings page, never
  // Accessibility, so the button is left out there entirely (see the
  // class doc on GuidedAccessScreen) rather than promising a jump it
  // can't deliver.
  testWidgets('no "Открыть настройки" button on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(const MaterialApp(home: GuidedAccessScreen()));

      expect(find.byKey(const ValueKey('open_system_settings_button')), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tapping "Открыть настройки" calls the injected opener, no snackbar on success', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var calls = 0;

    try {
      await tester.pumpWidget(MaterialApp(
        home: GuidedAccessScreen(
          openSettings: () async {
            calls++;
            return true;
          },
        ),
      ));

      // The instructions list is taller than the default 800x600 test
      // surface, so the button starts below the fold — grow the surface
      // instead of scrolling, so tap() hits real content rather than a
      // stale pre-scroll offset.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();

      final button = find.byKey(const ValueKey('open_system_settings_button'));
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.byType(SnackBar), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shows a snackbar telling the user to open settings manually when the opener fails', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(MaterialApp(
        home: GuidedAccessScreen(openSettings: () async => false),
      ));

      // The instructions list is taller than the default 800x600 test
      // surface, so the button starts below the fold — grow the surface
      // instead of scrolling, so tap() hits real content rather than a
      // stale pre-scroll offset.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();

      final button = find.byKey(const ValueKey('open_system_settings_button'));
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
