import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/presentation/screens/parental_gate_screen.dart';

import '../../support/parental_gate_helper.dart';

/// Opens the gate from a button and records what it returned.
Future<List<bool>> _pumpHost(WidgetTester tester, {required int seed}) async {
  final results = <bool>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        key: const ValueKey('open_gate'),
        onPressed: () async => results.add(await passParentalGate(Navigator.of(context), random: Random(seed))),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.byKey(const ValueKey('open_gate')));
  await tester.pumpAndSettle();
  return results;
}

String _taskText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('parental_gate_task'))).data!;

void main() {
  testWidgets('asks for three digits written as words', (tester) async {
    await _pumpHost(tester, seed: 7);
    final expected = Random(7);
    final words = [for (var i = 0; i < 3; i++) digitWords[expected.nextInt(10)]];
    expect(_taskText(tester), words.join(', '));
    expect(find.text('Нажмите по порядку:'), findsOneWidget);
  });

  testWidgets('the right digits let the parent through', (tester) async {
    final results = await _pumpHost(tester, seed: 3);
    await solveParentalGate(tester);
    expect(results, [true]);
    expect(find.byType(ParentalGateScreen), findsNothing);
  });

  testWidgets('a wrong digit starts over with a new task', (tester) async {
    final results = await _pumpHost(tester, seed: 11);
    final first = _taskText(tester);
    final firstDigit = digitWords.indexOf(first.split(', ').first);
    await tester.tap(find.byKey(ValueKey('parental_gate_digit_${(firstDigit + 1) % 10}')));
    await tester.pump();

    expect(find.byKey(const ValueKey('parental_gate_wrong')), findsOneWidget);
    final expected = Random(11);
    for (var i = 0; i < 3; i++) {
      expected.nextInt(10);
    }
    expect(_taskText(tester), [for (var i = 0; i < 3; i++) digitWords[expected.nextInt(10)]].join(', '));
    expect(results, isEmpty);

    await solveParentalGate(tester);
    expect(results, [true]);
  });

  testWidgets('closing the gate keeps the menu shut', (tester) async {
    final results = await _pumpHost(tester, seed: 1);
    await tester.tap(find.byKey(const ValueKey('parental_gate_close')));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('the system back button keeps the menu shut too', (tester) async {
    final results = await _pumpHost(tester, seed: 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(results, [false]);
  });
}
