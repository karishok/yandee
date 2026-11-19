import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/presentation/screens/parental_gate_screen.dart';

/// Reads the gate's task off the screen and taps its digits, the way a
/// parent would — so tests needn't know the gate's random numbers.
Future<void> solveParentalGate(WidgetTester tester) async {
  final task = tester.widget<Text>(find.byKey(const ValueKey('parental_gate_task'))).data!;
  for (final word in task.split(', ')) {
    await tester.tap(find.byKey(ValueKey('parental_gate_digit_${digitWords.indexOf(word)}')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
