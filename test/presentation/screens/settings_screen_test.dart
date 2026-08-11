import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/presentation/screens/guided_access_screen.dart';
import 'package:yandee/presentation/screens/settings_screen.dart';

void main() {
  testWidgets('shows exactly one settings item, for Guided Access', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.byKey(const ValueKey('settings_guided_access_tile')), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('tapping the item navigates to the Guided Access instructions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.tap(find.byKey(const ValueKey('settings_guided_access_tile')));
    await tester.pumpAndSettle();

    expect(find.byType(GuidedAccessScreen), findsOneWidget);
  });
}
