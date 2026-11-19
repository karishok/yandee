# Меню для родителей — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Шестерёнка на главном экране открывает через родительский замок меню «Для родителей»: таймер игры на сеанс с экраном «Пора отдохнуть!», блокировка на одном приложении, «Написать нам», «Оценить Yandee», «О приложении» с авторами звуков.

**Architecture:** Модель `PlayTimer` (ChangeNotifier, тикает раз в секунду) живёт в `PlayTimerScope` над навигатором (`MaterialApp.builder`); по истечении scope пушит маршрут `RestScreen` через `navigatorKey`. Замок — отдельный маршрут, возвращающий `bool`. Внешние ссылки и версия приложения — тонкий слой в `lib/platform/external_links.dart`, экраны получают их параметрами, чтобы тесты обходились без плагинов. Авторы звуков читаются из `docs/animal-sounds-credits.json`, подключённого как ассет.

**Tech Stack:** Flutter 3.47.5, `url_launcher` (уже есть), `audioplayers` (уже есть), `flutter_svg` (уже есть), новый `package_info_plus`.

Спек: `docs/superpowers/specs/2026-11-19-parents-menu-design.md`.

## Global Constraints

- Весь интерфейс по-русски; заголовок меню — «Для родителей».
- Не трогать `lib/domain/modes/`, `lib/presentation/controllers/scene_controller.dart`, `lib/presentation/screens/scene_screen.dart`, `lib/domain/modes/scene_mode_effects.dart` (их правит сессия «Кто так говорит?»).
- Никакой синтезированной озвучки: `assets/audio/system/rest_time.wav` записывает пользователь; пока файла нет, экран отдыха молчит.
- Таймер нигде не сохраняется; считает только когда приложение `resumed`.
- Адреса: почта `babaliants@gmail.com`; App Store `https://apps.apple.com/app/yandee/id6817918076?action=write-review`; RuStore `https://www.rustore.ru/catalog/app/com.yandee.yandee`; условия `https://yandee-app.ru/terms`.
- Тест, который запускает `PlayTimer`, в конце тела зовёт `timer.stop()` (или размонтирует дерево, если таймер принадлежит `PlayTimerScope`), иначе `testWidgets` падает на висящем `Timer.periodic`.
- Все команды — из корня worktree. Коммиты заканчиваются строкой `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Файлы

| Файл | Что |
|---|---|
| `tool/src/voiceover_tasks.dart` | `parentsPhrases` с «Пора отдыхать!» |
| `tool/src/voiceover_queue.dart` | фильтр `parents` |
| `tool/slice_voiceover.dart` | `parents` в подсказке |
| `lib/domain/play_timer.dart` | модель таймера |
| `lib/presentation/screens/parental_gate_screen.dart` | замок + `passParentalGate` + `digitWords` |
| `lib/platform/external_links.dart` | адреса, `openExternalLink`, `readAppVersion` |
| `lib/domain/models/sound_credit.dart` | `SoundCredit` |
| `lib/data/sound_credits_repository.dart` | `loadSoundCredits` → `SoundCreditLine` |
| `lib/presentation/screens/about_screen.dart` | «О приложении» |
| `lib/audio/rest_phrase_player.dart` | `playRestPhrase` |
| `lib/presentation/screens/rest_screen.dart` | «Пора отдохнуть!» + `restRoute` |
| `lib/presentation/widgets/play_timer_scope.dart` | `PlayTimerProvider`, `PlayTimerScope` |
| `lib/presentation/screens/parents_screen.dart` | бывший `settings_screen.dart` |
| `lib/presentation/screens/scene_list_screen.dart` | шестерёнка через замок |
| `lib/main.dart` | `navigatorKey` + `builder` |
| `test/support/parental_gate_helper.dart` | `solveParentalGate` |

---

### Task 1: Фильтр озвучки `parents`

**Files:**
- Modify: `tool/src/voiceover_tasks.dart`
- Modify: `tool/src/voiceover_queue.dart`
- Modify: `tool/slice_voiceover.dart` (текст подсказки)
- Test: `test/tool/voiceover_tasks_test.dart`, `test/tool/voiceover_queue_test.dart`

**Interfaces:**
- Produces: `const List<VoiceoverTask> parentsPhrases`; `const parentsFilter = 'parents'`; `taskMatchesFilter(task, 'parents')`, `isValidSceneFilter('parents') == true`.

- [ ] **Step 1: Failing tests**

В `test/tool/voiceover_tasks_test.dart` добавить тест и поправить счётчик (186 → 187, комментарий «116 for the scenes, system and parents phrases»):

```dart
  test('includes the parents menu phrase, recorded into the system folder', () {
    final byPath = {for (final t in buildVoiceoverTasks()) t.outputPath: t.text};
    expect(byPath['assets/audio/system/rest_time.wav'], 'Пора отдыхать!');
  });
```

В `test/tool/voiceover_queue_test.dart` рядом с тестом `"system" filter…`:

```dart
    test('"parents" filter matches only the parents menu phrase, and "system" no longer does', () {
      const restTask = VoiceoverTask(text: 'Пора отдыхать!', outputPath: 'assets/audio/system/rest_time.wav');
      expect(taskMatchesFilter(restTask, 'parents'), isTrue);
      expect(taskMatchesFilter(systemTask, 'parents'), isFalse);
      expect(taskMatchesFilter(kitchenTask, 'parents'), isFalse);
      expect(taskMatchesFilter(restTask, 'system'), isFalse);
      expect(taskMatchesFilter(restTask, null), isTrue);
      expect(isValidSceneFilter('parents'), isTrue);
    });
```

- [ ] **Step 2: Run** `flutter test test/tool/voiceover_tasks_test.dart test/tool/voiceover_queue_test.dart` — FAIL.

- [ ] **Step 3: Implement**

`tool/src/voiceover_tasks.dart`, после `_systemPhrases`:

```dart
/// The parents menu's play-timer phrase. It lives in the system folder (the
/// app already bundles that one) but is recorded on its own —
/// `slice_voiceover.dart parents` — so adding it never means re-recording
/// the Find mode's phrases.
const parentsPhrases = [
  VoiceoverTask(text: 'Пора отдыхать!', outputPath: 'assets/audio/system/rest_time.wav'),
];
```

и в `buildVoiceoverTasks()`: `final tasks = <VoiceoverTask>[..._systemPhrases, ...parentsPhrases];`.

`tool/src/voiceover_queue.dart`:

```dart
/// The filter value that selects the parents menu's phrases.
const parentsFilter = 'parents';

bool _isParentsTask(VoiceoverTask task) => parentsPhrases.any((p) => p.outputPath == task.outputPath);
```

в `taskMatchesFilter`:

```dart
  if (sceneFilter == 'system') {
    return task.outputPath.startsWith('assets/audio/system/') && !_isParentsTask(task);
  }
  if (sceneFilter == parentsFilter) return _isParentsTask(task);
```

в `isValidSceneFilter`: `if (filter == null || filter == 'system' || filter == parentsFilter || isMonstersFilter(filter)) return true;`. Обновить doc-комментарии (`'parents'` — фраза меню для родителей). В `tool/slice_voiceover.dart` и везде, где печатается список допустимых значений или usage (`<scene-id|system|monsters…>`), добавить `parents` (`grep -n "system|monsters\|'system'" tool/*.dart`).

- [ ] **Step 4: Run** те же тесты + `flutter test test/tool` — PASS.

- [ ] **Step 5: Commit** `feat(tool): a "parents" voiceover filter for the rest-time phrase`

---

### Task 2: Модель `PlayTimer`

**Files:**
- Create: `lib/domain/play_timer.dart`
- Test: `test/domain/play_timer_test.dart`

**Interfaces:**
- Produces: `class PlayTimer extends ChangeNotifier` с `void start(Duration limit)`, `void stop()`, `void pause()`, `void resume()`, `bool get isRunning`, `bool get isExpired`, `Duration get remaining`, `Duration? get limit` (выбранный лимит, пока таймер идёт или истёк; `null` после `stop`).

- [ ] **Step 1: Failing test** (`testWidgets` — внутри FakeAsync, `tester.pump(d)` двигает таймеры):

```dart
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
```

- [ ] **Step 2: Run** `flutter test test/domain/play_timer_test.dart` — FAIL (нет файла).

- [ ] **Step 3: Implement** `lib/domain/play_timer.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

/// A play-time limit for one sitting, set by a parent in the parents menu.
///
/// Counts down in whole seconds and only while not [pause]d — the app
/// pauses it whenever it leaves the screen, so time the device spends
/// locked or in someone's pocket doesn't count. It is never stored:
/// closing the app ends it.
class PlayTimer extends ChangeNotifier {
  static const _tick = Duration(seconds: 1);

  Timer? _ticker;
  Duration? _limit;
  Duration _remaining = Duration.zero;
  bool _expired = false;
  bool _paused = false;

  /// Counting down (or paused partway); false once it has expired.
  bool get isRunning => _ticker != null;

  /// The limit ran out; stays true until [stop] or a new [start].
  bool get isExpired => _expired;

  Duration get remaining => _remaining;

  /// The limit last started with, while running or expired.
  Duration? get limit => _limit;

  void start(Duration limit) {
    assert(limit > Duration.zero);
    _ticker?.cancel();
    _limit = limit;
    _remaining = limit;
    _expired = false;
    _ticker = Timer.periodic(_tick, _onTick);
    notifyListeners();
  }

  void stop() {
    if (_ticker == null && !_expired && _limit == null) return;
    _ticker?.cancel();
    _ticker = null;
    _limit = null;
    _remaining = Duration.zero;
    _expired = false;
    notifyListeners();
  }

  void pause() => _paused = true;

  void resume() => _paused = false;

  void _onTick(Timer _) {
    if (_paused) return;
    _remaining -= _tick;
    if (_remaining <= Duration.zero) {
      _remaining = Duration.zero;
      _expired = true;
      _ticker?.cancel();
      _ticker = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run** — PASS.

- [ ] **Step 5: Commit** `feat: a play timer for one sitting that counts only while the app is on screen`

---

### Task 3: Родительский замок

**Files:**
- Create: `lib/presentation/screens/parental_gate_screen.dart`
- Create: `test/support/parental_gate_helper.dart`
- Test: `test/presentation/screens/parental_gate_screen_test.dart`

**Interfaces:**
- Produces: `const List<String> digitWords` (`'ноль'…'девять'`); `Future<bool> passParentalGate(NavigatorState navigator, {Random? random})`; `ParentalGateScreen({Key? key, Random? random})`; ключи `parental_gate_task` (Text с цифрами словами через `', '`), `parental_gate_digit_<0-9>`, `parental_gate_close`, `parental_gate_wrong`; тестовый хелпер `Future<void> solveParentalGate(WidgetTester tester)`.

- [ ] **Step 1: Failing test** `test/presentation/screens/parental_gate_screen_test.dart`:

```dart
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
```

`test/support/parental_gate_helper.dart`:

```dart
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
```

- [ ] **Step 2: Run** `flutter test test/presentation/screens/parental_gate_screen_test.dart` — FAIL.

- [ ] **Step 3: Implement** `lib/presentation/screens/parental_gate_screen.dart`:

```dart
import 'dart:math';

import 'package:flutter/material.dart';

/// The digits as the gate writes them: a toddler can't read them, a parent
/// reads them at a glance.
const digitWords = ['ноль', 'один', 'два', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь', 'девять'];

/// Shows the parental gate and says whether it was passed. Closing it (the
/// ✕, the system back button) counts as not passed.
Future<bool> passParentalGate(NavigatorState navigator, {Random? random}) async {
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

  List<int> _newCode() => [for (var i = 0; i < _length; i++) _random.nextInt(10)];

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
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
                        color: i < _entered.length ? colorScheme.primary : colorScheme.outlineVariant,
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
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
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
                                              key: ValueKey('parental_gate_digit_$digit'),
                                              onPressed: () => _press(digit),
                                              child: Text('$digit', style: textTheme.headlineSmall),
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
```

- [ ] **Step 4: Run** — PASS.

- [ ] **Step 5: Commit** `feat: a parental gate — tap three digits written as words`

---

### Task 4: Внешние ссылки и версия приложения

**Files:**
- Modify: `pubspec.yaml` (через `flutter pub add package_info_plus`)
- Create: `lib/platform/external_links.dart`
- Test: `test/platform/external_links_test.dart`

**Interfaces:**
- Produces: `const feedbackEmail`; `final Uri termsUri, appStoreReviewUri, ruStoreUri`; `Uri feedbackMailUri(String appVersion)`; `Uri storeReviewUri(TargetPlatform platform)`; `typedef LinkOpener = Future<bool> Function(Uri uri)`; `typedef AppVersionReader = Future<String> Function()`; `Future<bool> openExternalLink(Uri uri)`; `Future<String> readAppVersion()` (формат `'1.2.0 (5)'`).

- [ ] **Step 1: Failing test**:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/platform/external_links.dart';

void main() {
  test('the feedback letter goes to the address on the site, with the version in its subject', () {
    final uri = feedbackMailUri('1.2.0 (5)');
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'babaliants@gmail.com');
    expect(uri.queryParameters['subject'], 'Yandee 1.2.0 (5)');
    expect(uri.toString(), isNot(contains('+')), reason: 'mail apps show a "+" literally');
  });

  test('rating opens the App Store on Apple devices and RuStore elsewhere', () {
    expect(storeReviewUri(TargetPlatform.iOS).toString(),
        'https://apps.apple.com/app/yandee/id6817918076?action=write-review');
    expect(storeReviewUri(TargetPlatform.macOS), storeReviewUri(TargetPlatform.iOS));
    expect(storeReviewUri(TargetPlatform.android).toString(), 'https://www.rustore.ru/catalog/app/com.yandee.yandee');
  });

  test('the terms page is the one on the site', () {
    expect(termsUri.toString(), 'https://yandee-app.ru/terms');
  });
}
```

- [ ] **Step 2: Run** `flutter test test/platform/external_links_test.dart` — FAIL.

- [ ] **Step 3: Implement**. `flutter pub add package_info_plus`, затем `lib/platform/external_links.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the parents menu sends people outside the app. The addresses are
/// the ones on the public site (website/README.md).
const feedbackEmail = 'babaliants@gmail.com';
final termsUri = Uri.parse('https://yandee-app.ru/terms');
final appStoreReviewUri = Uri.parse('https://apps.apple.com/app/yandee/id6817918076?action=write-review');
final ruStoreUri = Uri.parse('https://www.rustore.ru/catalog/app/com.yandee.yandee');

/// A letter to [feedbackEmail] whose subject says which version wrote it.
/// Spaces are encoded as %20: mail apps show a `+` literally.
Uri feedbackMailUri(String appVersion) => Uri(
      scheme: 'mailto',
      path: feedbackEmail,
      query: 'subject=${Uri.encodeComponent('Yandee $appVersion')}',
    );

/// The store page to rate the app on: the App Store on Apple devices,
/// RuStore (where the Android build is published) everywhere else.
Uri storeReviewUri(TargetPlatform platform) => switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => appStoreReviewUri,
      _ => ruStoreUri,
    };

typedef LinkOpener = Future<bool> Function(Uri uri);
typedef AppVersionReader = Future<String> Function();

/// Opens [uri] in the app that handles it (browser, mail, store). Returns
/// false instead of throwing when nothing could open it.
Future<bool> openExternalLink(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// The app's version as people see it in the store, with the build: `1.2.0 (5)`.
Future<String> readAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
```

- [ ] **Step 4: Run** — PASS. Также `flutter analyze lib/platform` — без замечаний.

- [ ] **Step 5: Commit** `feat: links for feedback, rating and terms, and the app version`

---

### Task 5: Авторы звуков — данные

**Files:**
- Modify: `pubspec.yaml` (ассет `docs/animal-sounds-credits.json`)
- Create: `lib/domain/models/sound_credit.dart`
- Create: `lib/data/sound_credits_repository.dart`
- Test: `test/data/sound_credits_repository_test.dart`

**Interfaces:**
- Produces: `class SoundCredit { String id, scene, artist, license; Uri page; static List<SoundCredit> listFromJson(Map<String, dynamic>) }`; `const soundCreditsAsset = 'docs/animal-sounds-credits.json'`; `class SoundCreditLine { String label; SoundCredit credit; }`; `Future<List<SoundCreditLine>> loadSoundCredits(AssetBundle bundle)`.

- [ ] **Step 1: Failing test**:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yandee/data/sound_credits_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every bundled credit is named after its object, in the order of the credits file', () async {
    final lines = await loadSoundCredits(rootBundle);
    final json = jsonDecode(File(soundCreditsAsset).readAsStringSync()) as Map<String, dynamic>;
    expect(lines.map((l) => l.credit.id), json.keys);

    final cow = lines.firstWhere((l) => l.credit.id == 'cow');
    expect(cow.label, 'Корова');
    expect(cow.credit.artist, 'Secretlondon');
    expect(cow.credit.license, 'CC BY-SA 3.0');
    expect(cow.credit.page.toString(), 'https://commons.wikimedia.org/wiki/File:Mudchute_cow_1.ogg');
    for (final line in lines) {
      expect(line.label, isNot(line.credit.id), reason: '${line.credit.id} has no object in its scene');
    }
  });

  test('a sound with no object in its scene falls back to its id', () async {
    final bundle = _MapBundle({
      soundCreditsAsset: jsonEncode({
        'yeti': {'scene': 'farm', 'artist': 'A', 'license': 'CC0', 'page': 'https://example.com/yeti'},
      }),
      'assets/demo_content/farm/scene.json': jsonEncode({'objects': <Object>[]}),
    });
    final lines = await loadSoundCredits(bundle);
    expect(lines.single.label, 'yeti');
  });

  test('every object sound in assets/demo_content has a credit, and every credit a sound', () {
    final soundFiles = {
      for (final file in Directory('assets/demo_content').listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('_sound.wav'))
          '${p.basename(file.parent.path)}/${p.basename(file.path).replaceAll('_sound.wav', '')}',
    };
    final json = jsonDecode(File(soundCreditsAsset).readAsStringSync()) as Map<String, dynamic>;
    final credited = {
      for (final entry in json.entries) '${(entry.value as Map<String, dynamic>)['scene']}/${entry.key}',
    };
    expect(credited, soundFiles);
  });
}

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('missing $key');
    return ByteData.sublistView(utf8.encode(text));
  }
}
```

- [ ] **Step 2: Run** `flutter test test/data/sound_credits_repository_test.dart` — FAIL.

- [ ] **Step 3: Implement**.

`pubspec.yaml`, в `flutter: assets:` после `assets/audio/monsters_tts/`:

```yaml
    # Who recorded the animal and vehicle sounds — shown on the About screen.
    - docs/animal-sounds-credits.json
```

`lib/domain/models/sound_credit.dart`:

```dart
/// Who recorded one object's sound (`<scene>/<id>_sound.wav`) and under
/// which license — one entry of docs/animal-sounds-credits.json.
class SoundCredit {
  const SoundCredit({
    required this.id,
    required this.scene,
    required this.artist,
    required this.license,
    required this.page,
  });

  final String id;
  final String scene;
  final String artist;
  final String license;
  final Uri page;

  /// The credits file is one object keyed by sound id, in the order the
  /// sounds were added.
  static List<SoundCredit> listFromJson(Map<String, dynamic> json) => [
        for (final entry in json.entries)
          SoundCredit(
            id: entry.key,
            scene: (entry.value as Map<String, dynamic>)['scene'] as String,
            artist: (entry.value as Map<String, dynamic>)['artist'] as String,
            license: (entry.value as Map<String, dynamic>)['license'] as String,
            page: Uri.parse((entry.value as Map<String, dynamic>)['page'] as String),
          ),
      ];
}
```

`lib/data/sound_credits_repository.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/models/sound_credit.dart';

/// Kept where tool/fetch_animal_sounds.py writes it, and bundled from there,
/// so the About screen can never disagree with the credits document.
const soundCreditsAsset = 'docs/animal-sounds-credits.json';

/// One row of the About screen's sound credits: the object's name as the
/// child hears it, and who recorded its sound.
class SoundCreditLine {
  const SoundCreditLine({required this.label, required this.credit});

  final String label;
  final SoundCredit credit;
}

/// The bundled sound credits, each named after the object whose `sound` it
/// is in its scene's bundled scene.json (or by its id, if none is).
Future<List<SoundCreditLine>> loadSoundCredits(AssetBundle bundle) async {
  final credits = SoundCredit.listFromJson(
    jsonDecode(await bundle.loadString(soundCreditsAsset)) as Map<String, dynamic>,
  );
  final labelsByScene = <String, Map<String, String>>{};
  final lines = <SoundCreditLine>[];
  for (final credit in credits) {
    final labels = labelsByScene[credit.scene] ??= await _soundLabels(bundle, credit.scene);
    lines.add(SoundCreditLine(label: labels['${credit.id}_sound.wav'] ?? credit.id, credit: credit));
  }
  return lines;
}

/// sound file name -> object label, for one bundled scene.
Future<Map<String, String>> _soundLabels(AssetBundle bundle, String sceneId) async {
  try {
    final json = jsonDecode(await bundle.loadString('assets/demo_content/$sceneId/scene.json')) as Map<String, dynamic>;
    return {
      for (final object in (json['objects'] as List<dynamic>).cast<Map<String, dynamic>>())
        if (object['sound'] != null) object['sound'] as String: object['label'] as String,
    };
  } catch (_) {
    return const {};
  }
}
```

- [ ] **Step 4: Run** — PASS.

- [ ] **Step 5: Commit** `feat: load the sound credits, named after their objects, from the credits file`

---

### Task 6: Экран «О приложении»

**Files:**
- Create: `lib/presentation/screens/about_screen.dart`
- Test: `test/presentation/screens/about_screen_test.dart`

**Interfaces:**
- Consumes: `LinkOpener`, `AppVersionReader`, `openExternalLink`, `readAppVersion`, `termsUri` (Task 4); `SoundCreditLine`, `loadSoundCredits` (Task 5).
- Produces: `AboutScreen({Key? key, LinkOpener? openLink, AppVersionReader? readVersion, Future<List<SoundCreditLine>> Function()? loadCredits})`; ключи `about_version`, `about_terms`, `about_credit_<id>`.

- [ ] **Step 1: Failing test**:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/data/sound_credits_repository.dart';
import 'package:yandee/domain/models/sound_credit.dart';
import 'package:yandee/platform/external_links.dart';
import 'package:yandee/presentation/screens/about_screen.dart';

final _cow = SoundCreditLine(
  label: 'Корова',
  credit: SoundCredit(
    id: 'cow',
    scene: 'farm',
    artist: 'Secretlondon',
    license: 'CC BY-SA 3.0',
    page: Uri.parse('https://commons.wikimedia.org/wiki/File:Mudchute_cow_1.ogg'),
  ),
);

Future<List<Uri>> _pump(WidgetTester tester, {bool opens = true}) async {
  final opened = <Uri>[];
  await tester.pumpWidget(MaterialApp(
    home: AboutScreen(
      openLink: (uri) async {
        opened.add(uri);
        return opens;
      },
      readVersion: () async => '1.2.0 (5)',
      loadCredits: () async => [_cow],
    ),
  ));
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('shows the version and who recorded each sound', (tester) async {
    await _pump(tester);
    expect(find.text('Версия 1.2.0 (5)'), findsOneWidget);
    expect(find.text('Авторы звуков'), findsOneWidget);
    expect(find.text('Корова'), findsOneWidget);
    expect(find.text('Secretlondon · CC BY-SA 3.0'), findsOneWidget);
  });

  testWidgets('opens the terms page and a sound\'s own page', (tester) async {
    final opened = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('about_terms')));
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('about_credit_cow')), 100);
    await tester.tap(find.byKey(const ValueKey('about_credit_cow')));
    await tester.pump();
    expect(opened, [termsUri, _cow.credit.page]);
  });

  testWidgets('says so when a link could not be opened', (tester) async {
    await _pump(tester, opens: false);
    await tester.tap(find.byKey(const ValueKey('about_terms')));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось открыть ссылку'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/presentation/screens/about_screen_test.dart` — FAIL.

- [ ] **Step 3: Implement** `lib/presentation/screens/about_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../data/sound_credits_repository.dart';
import '../../platform/external_links.dart';

/// Version, terms and privacy, and who recorded the animal and vehicle
/// sounds — CC BY / CC BY-SA ask for their authors to be credited.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.openLink, this.readVersion, this.loadCredits});

  final LinkOpener? openLink;
  final AppVersionReader? readVersion;
  final Future<List<SoundCreditLine>> Function()? loadCredits;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<String> _version = (widget.readVersion ?? readAppVersion)();
  late final Future<List<SoundCreditLine>> _credits =
      (widget.loadCredits ?? () => loadSoundCredits(rootBundle))();

  Future<void> _open(Uri uri) async {
    final opened = await (widget.openLink ?? openExternalLink)(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть ссылку')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Yandee'),
            subtitle: FutureBuilder<String>(
              future: _version,
              builder: (context, snapshot) => Text(
                snapshot.hasData ? 'Версия ${snapshot.data}' : '',
                key: const ValueKey('about_version'),
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('about_terms'),
            leading: const Icon(Icons.description_outlined),
            title: const Text('Условия и конфиденциальность'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _open(termsUri),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Авторы звуков', style: textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Голоса животных и звуки техники — настоящие записи с Freesound и Wikimedia Commons. Спасибо их авторам!',
              style: textTheme.bodySmall,
            ),
          ),
          FutureBuilder<List<SoundCreditLine>>(
            future: _credits,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const ListTile(title: Text('Список не загрузился'));
              }
              final lines = snapshot.data;
              if (lines == null) return const SizedBox.shrink();
              return Column(
                children: [
                  for (final line in lines)
                    ListTile(
                      key: ValueKey('about_credit_${line.credit.id}'),
                      dense: true,
                      title: Text(line.label),
                      subtitle: Text('${line.credit.artist} · ${line.credit.license}'),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _open(line.credit.page),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run** — PASS.

- [ ] **Step 5: Commit** `feat: the About screen — version, terms, and who recorded the sounds`

---

### Task 7: Экран отдыха и `PlayTimerScope`

**Files:**
- Create: `lib/audio/rest_phrase_player.dart`
- Create: `lib/presentation/screens/rest_screen.dart`
- Create: `lib/presentation/widgets/play_timer_scope.dart`
- Modify: `lib/main.dart`
- Test: `test/presentation/widgets/play_timer_scope_test.dart`

**Interfaces:**
- Consumes: `PlayTimer` (Task 2); `passParentalGate`, `solveParentalGate` (Task 3); `MonsterLayers.of(MonsterColor.blue)` (`body`, `squint`, `mouthIdle`) из `lib/presentation/monsters/monster_art.dart`.
- Produces: `Future<void> playRestPhrase()`; `const restPhraseAsset = 'audio/system/rest_time.wav'`; `RestScreen({Key? key, required Future<void> Function() playPhrase})`; `Route<void> restRoute({required Future<void> Function() playPhrase})`; `PlayTimerProvider({Key? key, required PlayTimer timer, required Widget child})` с `static PlayTimer of(BuildContext)` (подписывается) и `static PlayTimer read(BuildContext)` (без подписки); `PlayTimerScope({Key? key, required GlobalKey<NavigatorState> navigatorKey, required Widget child, PlayTimer? timer, Future<void> Function()? playRestPhrase})`; ключ кнопки `rest_parents_button`.

- [ ] **Step 1: Failing test** `test/presentation/widgets/play_timer_scope_test.dart`:

```dart
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
```

- [ ] **Step 2: Run** `flutter test test/presentation/widgets/play_timer_scope_test.dart` — FAIL.

- [ ] **Step 3: Implement**.

`lib/audio/rest_phrase_player.dart`:

```dart
import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';

/// «Пора отдыхать!», recorded by a person (never synthesised) with
/// `dart run tool/slice_voiceover.dart parents <take>`.
const restPhraseAsset = 'audio/system/rest_time.wav';

/// Says the rest-time phrase once, on a player of its own. Until the phrase
/// is recorded the file isn't there; that, like any playback failure, is
/// logged and swallowed — the rest screen then simply stays quiet.
Future<void> playRestPhrase() async {
  final player = AudioPlayer();
  try {
    final done = player.onPlayerComplete.first;
    await player.play(AssetSource(restPhraseAsset));
    await done.timeout(const Duration(seconds: 6));
  } catch (error, stackTrace) {
    developer.log('Rest phrase did not play', name: 'RestPhrase', error: error, stackTrace: stackTrace);
  } finally {
    try {
      await player.dispose();
    } catch (_) {}
  }
}
```

`lib/presentation/widgets/play_timer_scope.dart`:

```dart
import 'package:flutter/material.dart';

import '../../audio/rest_phrase_player.dart';
import '../../domain/play_timer.dart';
import '../screens/rest_screen.dart';

/// Hands the app's [PlayTimer] down to every screen.
class PlayTimerProvider extends InheritedNotifier<PlayTimer> {
  const PlayTimerProvider({super.key, required PlayTimer timer, required super.child}) : super(notifier: timer);

  /// The timer, rebuilding the caller whenever it ticks.
  static PlayTimer of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayTimerProvider>()!.notifier!;

  /// The timer, without subscribing — for button handlers.
  static PlayTimer read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PlayTimerProvider>()!.notifier!;
}

/// Sits above the app's navigator (`MaterialApp.builder`): owns the play
/// timer, stops it counting while the app is off screen, and when time is
/// up puts the rest screen over whatever is open.
class PlayTimerScope extends StatefulWidget {
  const PlayTimerScope({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.timer,
    this.playRestPhrase,
  });

  /// The app's navigator — this widget sits above it, so it can't look it up.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// Tests pass their own; the scope then leaves disposing it to them.
  final PlayTimer? timer;
  final Future<void> Function()? playRestPhrase;

  @override
  State<PlayTimerScope> createState() => _PlayTimerScopeState();
}

class _PlayTimerScopeState extends State<PlayTimerScope> {
  late final PlayTimer _timer = widget.timer ?? PlayTimer();
  late final AppLifecycleListener _lifecycle;
  bool _restShown = false;

  @override
  void initState() {
    super.initState();
    _timer.addListener(_onTimerChanged);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => state == AppLifecycleState.resumed ? _timer.resume() : _timer.pause(),
    );
  }

  void _onTimerChanged() {
    if (!_timer.isExpired || _restShown) return;
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    _restShown = true;
    navigator
        .push(restRoute(playPhrase: widget.playRestPhrase ?? playRestPhrase))
        .whenComplete(() => _restShown = false);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer.removeListener(_onTimerChanged);
    if (widget.timer == null) _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlayTimerProvider(timer: _timer, child: widget.child);
}
```

`lib/presentation/screens/rest_screen.dart`:

```dart
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

  @override
  void initState() {
    super.initState();
    unawaited(widget.playPhrase());
  }

  Future<void> _letParentIn() async {
    final navigator = Navigator.of(context);
    final timer = PlayTimerProvider.read(context);
    if (!await passParentalGate(navigator)) return;
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
```

`lib/main.dart`: добавить импорт `presentation/widgets/play_timer_scope.dart`, верхнеуровневый ключ и подключение:

```dart
/// The app's navigator, so the play timer — which sits above it — can put
/// the rest screen on top of whatever is open.
final _navigatorKey = GlobalKey<NavigatorState>();
```

```dart
    return MaterialApp(
      title: 'Yandee',
      theme: _buildTheme(),
      navigatorKey: _navigatorKey,
      builder: (context, child) => PlayTimerScope(navigatorKey: _navigatorKey, child: child!),
      home: _StartupScreen(contentRepository: contentRepository),
    );
```

- [ ] **Step 4: Run** `flutter test test/presentation/widgets/play_timer_scope_test.dart` — PASS.

- [ ] **Step 5: Commit** `feat: when the play timer runs out, «Пора отдохнуть!» covers the app until a parent passes the gate`

---

### Task 8: Экран «Для родителей» и шестерёнка через замок

**Files:**
- Rename: `lib/presentation/screens/settings_screen.dart` → `lib/presentation/screens/parents_screen.dart` (`git mv`)
- Rename: `test/presentation/screens/settings_screen_test.dart` → `test/presentation/screens/parents_screen_test.dart`
- Modify: `lib/presentation/screens/scene_list_screen.dart`
- Modify: `test/presentation/screens/scene_list_screen_test.dart`

**Interfaces:**
- Consumes: `PlayTimer` (Task 2), `PlayTimerProvider` (Task 7), `passParentalGate`/`solveParentalGate` (Task 3), `feedbackMailUri`, `storeReviewUri`, `feedbackEmail`, `LinkOpener`, `AppVersionReader`, `openExternalLink`, `readAppVersion` (Task 4), `AboutScreen` (Task 6), `GuidedAccessScreen` (есть).
- Produces: `ParentsScreen({Key? key, LinkOpener? openLink, AppVersionReader? readVersion, TargetPlatform? platform})`; ключи `settings_guided_access_tile` (прежний), `parents_feedback_tile`, `parents_rate_tile`, `parents_about_tile`, `play_timer_<0|10|15|20|30>`, `play_timer_remaining`.

- [ ] **Step 1: Failing tests**. `git mv` оба файла, затем заменить содержимое `test/presentation/screens/parents_screen_test.dart`:

```dart
import 'package:flutter/foundation.dart';
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
```

(Тест «О приложении» откроет `AboutScreen` с настоящими `loadSoundCredits(rootBundle)` — это нормально, ассеты доступны в тестах; `openLink`/`readVersion` передаются из `ParentsScreen`.)

В `test/presentation/screens/scene_list_screen_test.dart`: импорт `settings_screen.dart` заменить на `parents_screen.dart`, добавить импорты `package:yandee/domain/play_timer.dart`, `package:yandee/presentation/screens/parental_gate_screen.dart`, `package:yandee/presentation/widgets/play_timer_scope.dart`, `../../support/parental_gate_helper.dart`, а тест `'the settings button opens the settings screen'` заменить на:

```dart
  testWidgets('the settings button asks for the parental gate before the parents menu', (tester) async {
    late Directory cacheRoot;

    await tester.runAsync(() async {
      cacheRoot = await Directory.systemTemp.createTemp('yandee_list_test_settings_');
      await _seedScene(cacheRoot, 'city', 'Город');
      final repository = ContentRepository(
        httpClient: MockClient((_) async => throw const SocketException('offline')),
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await tester.pumpWidget(PlayTimerProvider(
        timer: PlayTimer(),
        child: MaterialApp(home: SceneListScreen(contentRepository: repository)),
      ));
      await _pumpAndSettleReal(tester);
    });
    addTearDown(() => cacheRoot.delete(recursive: true));

    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings_button')));
    await tester.pumpAndSettle();
    expect(find.byType(ParentalGateScreen), findsOneWidget);
    expect(find.byType(ParentsScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('parental_gate_close')));
    await tester.pumpAndSettle();
    expect(find.byType(ParentsScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings_button')));
    await tester.pumpAndSettle();
    await solveParentalGate(tester);
    expect(find.byType(ParentsScreen), findsOneWidget);
  });
```

- [ ] **Step 2: Run** `flutter test test/presentation/screens/parents_screen_test.dart test/presentation/screens/scene_list_screen_test.dart` — FAIL.

- [ ] **Step 3: Implement** `lib/presentation/screens/parents_screen.dart` (полная замена):

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../platform/external_links.dart';
import '../widgets/play_timer_scope.dart';
import 'about_screen.dart';
import 'guided_access_screen.dart';

/// The parents menu, behind the parental gate: the play timer, locking the
/// device into Yandee, writing to us, rating the app, and About.
class ParentsScreen extends StatelessWidget {
  const ParentsScreen({super.key, this.openLink, this.readVersion, this.platform});

  final LinkOpener? openLink;
  final AppVersionReader? readVersion;

  /// Which store «Оценить» opens; defaults to the device's platform.
  final TargetPlatform? platform;

  LinkOpener get _openLink => openLink ?? openExternalLink;

  Future<void> _writeToUs(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    String version;
    try {
      version = await (readVersion ?? readAppVersion)();
    } catch (_) {
      version = '';
    }
    final opened = await _openLink(feedbackMailUri(version));
    if (!opened) {
      messenger.showSnackBar(const SnackBar(content: Text('Не удалось открыть почту. Напишите на $feedbackEmail')));
    }
  }

  Future<void> _rate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await _openLink(storeReviewUri(platform ?? defaultTargetPlatform));
    if (!opened) {
      messenger.showSnackBar(const SnackBar(content: Text('Не удалось открыть магазин')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Для родителей')),
      body: ListView(
        children: [
          const _PlayTimerSection(),
          const Divider(),
          ListTile(
            key: const ValueKey('settings_guided_access_tile'),
            leading: const Icon(Icons.lock_outline),
            title: const Text('Блокировка на одном приложении'),
            subtitle: const Text('Чтобы ребёнок не мог случайно выйти из Yandee'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GuidedAccessScreen()),
            ),
          ),
          ListTile(
            key: const ValueKey('parents_feedback_tile'),
            leading: const Icon(Icons.mail_outline),
            title: const Text('Написать нам'),
            subtitle: const Text('Вопросы, идеи и пожелания'),
            onTap: () => _writeToUs(context),
          ),
          ListTile(
            key: const ValueKey('parents_rate_tile'),
            leading: const Icon(Icons.star_outline),
            title: const Text('Оценить Yandee'),
            subtitle: const Text('Отзыв в магазине очень нам поможет'),
            onTap: () => _rate(context),
          ),
          ListTile(
            key: const ValueKey('parents_about_tile'),
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AboutScreen(openLink: openLink, readVersion: readVersion)),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Таймер игры»: off, or 10/15/20/30 minutes from now, and what's left.
class _PlayTimerSection extends StatelessWidget {
  const _PlayTimerSection();

  static const _minutes = [0, 10, 15, 20, 30];

  @override
  Widget build(BuildContext context) {
    final timer = PlayTimerProvider.of(context);
    final selected = timer.isRunning ? timer.limit!.inMinutes : 0;
    final minutesLeft = (timer.remaining.inSeconds + 59) ~/ 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          leading: Icon(Icons.timer_outlined),
          title: Text('Таймер игры'),
          subtitle: Text('Когда время выйдет, игра мягко остановится'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _minutes)
                ChoiceChip(
                  key: ValueKey('play_timer_$m'),
                  label: Text(m == 0 ? 'Выкл' : '$m мин'),
                  selected: selected == m,
                  onSelected: (_) => m == 0 ? timer.stop() : timer.start(Duration(minutes: m)),
                ),
            ],
          ),
        ),
        if (timer.isRunning)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Осталось $minutesLeft мин', key: const ValueKey('play_timer_remaining')),
          ),
      ],
    );
  }
}
```

(Если `GuidedAccessScreen` имеет `const`-конструктор — оставить `const GuidedAccessScreen()`, как было.)

`lib/presentation/screens/scene_list_screen.dart`: импорт `settings_screen.dart` → `parents_screen.dart`, добавить импорт `parental_gate_screen.dart`, а `_settingsButton` заменить на:

```dart
  Widget _settingsButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        key: const ValueKey('settings_button'),
        icon: const Icon(Icons.settings),
        tooltip: 'Для родителей',
        onPressed: () async {
          final navigator = Navigator.of(context);
          if (!await passParentalGate(navigator)) return;
          await navigator.push(MaterialPageRoute(builder: (_) => const ParentsScreen()));
        },
      ),
    );
  }
```

`grep -rn "settings_screen\|SettingsScreen" lib test` — других ссылок остаться не должно.

- [ ] **Step 4: Run** те же тесты — PASS.

- [ ] **Step 5: Commit** `feat: the parents menu behind the gate — timer, app lock, feedback, rating, about`

---

### Task 9: Финальная проверка

- [ ] **Step 1:** `flutter test` — все тесты зелёные (новые и старые, включая `test/data/bundled_scenes_test.dart` и `demo_content_seeder_test.dart`).
- [ ] **Step 2:** `flutter analyze` — `No issues found!`.
- [ ] **Step 3:** В `docs/animal-sounds-credits.md` после первого абзаца добавить: «Приложение показывает этот список на экране «Для родителей → О приложении»; он читается прямо из `docs/animal-sounds-credits.json`, так что новый звук попадает туда сам.»
- [ ] **Step 4:** Commit `docs: the credits list is shown in the app`.
- [ ] **Step 5:** Сообщить пользователю, что нужно от него: записать «Пора отдыхать!» и нарезать `dart run tool/slice_voiceover.dart parents <запись>`; проверить на устройстве ссылки (почта, App Store, RuStore) и экран отдыха.
