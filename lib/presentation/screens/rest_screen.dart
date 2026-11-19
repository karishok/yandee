import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/monsters/monster_color.dart';
import '../monsters/monster_art.dart';
import '../widgets/play_timer_scope.dart';
import 'parental_gate_screen.dart';

/// The rest screen as a route: fades in, covers everything, and has no
/// swipe-back gesture.
Route<void> restRoute({required Future<void> Function() playPhrase}) => PageRouteBuilder<void>(
      fullscreenDialog: true,
      pageBuilder: (context, animation, secondaryAnimation) => RestScreen(playPhrase: playPhrase),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );

/// «Пора отдохнуть!» — shown when the parent's play timer runs out. Only a
/// parent gets past it, through the parental gate; that also turns the
/// timer off.
class RestScreen extends StatefulWidget {
  const RestScreen({super.key, required this.playPhrase});

  final Future<void> Function() playPhrase;

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  static const _night = Color(0xFF26315E);

  /// True while the gate is open, so a second tap can't stack a second one.
  bool _gateOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.playPhrase());
  }

  Future<void> _letParentIn() async {
    if (_gateOpen) return;
    _gateOpen = true;
    final navigator = Navigator.of(context);
    final timer = PlayTimerProvider.read(context);
    final bool passed;
    try {
      passed = await passParentalGate(navigator);
    } finally {
      // Whatever happens to the gate, the button must work again: this
      // screen has no other way out.
      _gateOpen = false;
    }
    if (!passed) return;
    timer.stop();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final monster = MonsterLayers.of(MonsterColor.blue);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _night,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const Text('Z z z', style: TextStyle(color: Color(0xFFBFD0FF), fontSize: 36, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SvgPicture.string(monster.body),
                    SvgPicture.string(monster.squint),
                    SvgPicture.string(monster.mouthIdle),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Пора отдохнуть!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                key: const ValueKey('rest_parents_button'),
                onPressed: _letParentIn,
                child: const Text('Для родителей', style: TextStyle(color: Color(0xFFBFD0FF))),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
