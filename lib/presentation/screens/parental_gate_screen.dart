import 'dart:math';

import 'package:flutter/material.dart';

/// The digits as the gate writes them: a toddler can't read them, a parent
/// reads them at a glance.
const digitWords = [
  'ноль',
  'один',
  'два',
  'три',
  'четыре',
  'пять',
  'шесть',
  'семь',
  'восемь',
  'девять'
];

/// Shows the parental gate and says whether it was passed. Closing it (the
/// ✕, the system back button) counts as not passed.
Future<bool> passParentalGate(NavigatorState navigator,
    {Random? random}) async {
  final passed = await navigator.push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ParentalGateScreen(random: random),
  ));
  return passed ?? false;
}

/// "Нажмите по порядку: семь, два, четыре" over a 0–9 keypad. Three fresh
/// random digits each time; a wrong digit starts over with new ones.
class ParentalGateScreen extends StatefulWidget {
  const ParentalGateScreen({super.key, this.random});

  /// Where the digits come from; tests pass a seeded one.
  final Random? random;

  @override
  State<ParentalGateScreen> createState() => _ParentalGateScreenState();
}

class _ParentalGateScreenState extends State<ParentalGateScreen> {
  static const _length = 3;

  late final Random _random = widget.random ?? Random();
  late List<int> _code = _newCode();
  final List<int> _entered = [];
  bool _wrong = false;

  List<int> _newCode() =>
      [for (var i = 0; i < _length; i++) _random.nextInt(10)];

  void _press(int digit) {
    if (_entered.length >= _length) return;
    if (digit != _code[_entered.length]) {
      setState(() {
        _code = _newCode();
        _entered.clear();
        _wrong = true;
      });
      return;
    }
    setState(() {
      _entered.add(digit);
      _wrong = false;
    });
    if (_entered.length == _length) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Для родителей'),
        leading: IconButton(
          key: const ValueKey('parental_gate_close'),
          icon: const Icon(Icons.close),
          tooltip: 'Закрыть',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Text('Нажмите по порядку:', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _code.map((d) => digitWords[d]).join(', '),
                key: const ValueKey('parental_gate_task'),
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _length; i++)
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _entered.length
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: 32,
                child: _wrong
                    ? Center(
                        child: Text(
                          'Неверно, попробуйте ещё раз',
                          key: const ValueKey('parental_gate_wrong'),
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.error),
                        ),
                      )
                    : null,
              ),
              Expanded(
                // Scales the keypad down when the screen (or the text size) is
                // too small for it, rather than overflowing.
                child: FittedBox(
                  child: SizedBox(
                    width: 320,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final row in const [
                          [1, 2, 3],
                          [4, 5, 6],
                          [7, 8, 9],
                          [null, 0, null],
                        ])
                          Row(
                            children: [
                              for (final digit in row)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: digit == null
                                        ? const SizedBox(height: 64)
                                        : SizedBox(
                                            height: 64,
                                            child: OutlinedButton(
                                              key: ValueKey(
                                                  'parental_gate_digit_$digit'),
                                              onPressed: () => _press(digit),
                                              child: Text('$digit',
                                                  style:
                                                      textTheme.headlineSmall),
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
