# «Фигурки» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A second mini-game card, «Фигурки»: the child drags wooden shape pieces one at a time onto dashed outlines until a picture is built and comes alive, learning 10 shape names over a chain of 12 pictures.

**Architecture:** Same split as «Монстрики»: rules without Flutter in `lib/domain/shapes/`, SVG-string art and a hand-laid-out screen in `lib/presentation/`, speech through the shared latest-only line player. The phrase player of «Монстрики» is generalised first so both games use one implementation. Recording tools learn the `shapes-1…3` parts; the user's three Logic takes are sliced into `assets/audio/shapes/`.

**Tech Stack:** Flutter 3.47 / Dart 3, `flutter_svg` 2.4 (vector_graphics_compiler 1.3.4: gradients, gradientTransform, clipPath, stroke-dasharray supported; no filters/masks), `audioplayers` 6.8, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-20-shapes-game-design.md`. Prototype with the exact art: `docs/prototypes/shapes.html`.

## Global Constraints

- All user-facing text is Russian; code, identifiers and comments are English.
- Card units: the picture card is 300 × 300; every slot box, effect and detail is in these units.
- Every slot's smaller side ≥ 50 card units; drop margin is 24 logical pixels around a slot.
- Colours: page `#fff8f0`, card `#fff0e1`, mat `#ffe6cd`, stitch `#e3c39c`, ink `#2b211a`, shadow `rgba(84,52,16,.14)` (`Color(0x24543410)`), hint `#ffb21a`.
- Phrase ids/texts exactly as spec §6.1; recorded voice lives in `assets/audio/shapes/<id>.wav`. No computer-voice stand-ins for this game (all 27 phrases are already recorded).
- SFX reuse existing files: placed `monster_pop`, wrong `monster_boing`, picture done `monster_clap`, whole chain `monster_win`.
- No progress persistence; every entry starts at «Мороженое».
- `flutter test` and `flutter analyze` must pass after every task. Commit after every task, message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Never edit the main checkout; the user's takes are read from `/Users/karina/flutter/yandee/tool/Untitled 1_1#04.wav`, `#05`, `#06`.

## File Map

| File | Responsibility |
|---|---|
| `lib/domain/voice/voice_line.dart` (new) | `VoiceClip`, `VoiceLine` — shared by both games |
| `lib/domain/monsters/monster_phrases.dart` | loses the two classes, re-exports them; `MonsterLine` → `VoiceLine` everywhere |
| `lib/audio/clip_line_player.dart` (new) | `voiceAssets`, `listBundledAssets`, `ClipLinePlayer`, `SfxPlayer` |
| `lib/audio/monster_voice_player.dart` | thin wrapper over the shared player |
| `lib/domain/shapes/shape_kind.dart` (new) | the 10 shapes in teaching order |
| `lib/domain/shapes/shape_picture.dart` (new) | `CardBox`, `ShapeSlot`, `PictureMotion`, `ShapePicture`, `shapePictures` |
| `lib/domain/shapes/shapes_game.dart` (new) | `ShapesGame`, `PieceShown`, `DropResult` |
| `lib/domain/shapes/shape_phrases.dart` (new) | all 27 clips and the lines built from them |
| `lib/audio/shapes_voice.dart`, `shapes_voice_player.dart` (new) | the screen's sound seam and its real implementation |
| `tool/src/shapes_parts.dart`, `tool/write_shapes_phrases_doc.dart` (new); `tool/src/voiceover_queue.dart`, `voiceover_tasks.dart`, `tool/record_voiceover.dart`, `tool/slice_voiceover.dart` | recording support, `docs/shapes_phrases.md` |
| `lib/presentation/shapes/shape_geometry.dart` (new) | outline path of each shape, slot transform |
| `lib/presentation/shapes/shape_art.dart` (new) | colours, wooden pieces, outlines, details, stand-in backgrounds, effects data, icons |
| `lib/presentation/shapes/shape_motion.dart` (new) | how a finished picture moves (pure maths) |
| `lib/presentation/shapes/shape_effects.dart` (new) | `CustomPainter` for smoke, bubbles, lights… |
| `lib/presentation/shapes/shape_picture_view.dart` (new) | the card: background, pieces, motion, effects, hints |
| `lib/presentation/screens/shapes_screen.dart` (new) | the game screen |
| `lib/presentation/screens/scene_list_screen.dart` | the «Фигурки» card |

---

### Task 1: Shared voice line and phrase player

**Files:**
- Create: `lib/domain/voice/voice_line.dart`, `lib/audio/clip_line_player.dart`, `test/audio/clip_line_player_test.dart`
- Modify: `lib/domain/monsters/monster_phrases.dart`, `lib/audio/monster_voice_player.dart`, every file containing `MonsterLine` (`lib/audio/monster_voice.dart`, `lib/presentation/screens/monsters_screen.dart`, `test/support/fake_monster_voice.dart`, tests)

**Interfaces:**
- Produces: `class VoiceClip(String id, String text)`, `class VoiceLine(List<VoiceClip> clips)` with `String get text`; `List<String> voiceAssets(VoiceLine line, Set<String> bundled, {required String recordedDir, required String synthDir})`; `Future<Set<String>> listBundledAssets(AssetBundle bundle)`; `class ClipLinePlayer({required String recordedDir, required String synthDir, required Future<Set<String>> bundled, AudioPlayer Function() playerFactory})` with `Future<void> say(VoiceLine)`, `void stop()`, `void dispose()`; `class SfxPlayer({AudioPlayer Function() playerFactory})` with `void play(String fileName)`, `void dispose()`.

- [ ] **Step 1: Write the failing test** — `test/audio/clip_line_player_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/clip_line_player.dart';
import 'package:yandee/domain/voice/voice_line.dart';

void main() {
  const line = VoiceLine([VoiceClip('new_shape', 'Новая фигурка!'), VoiceClip('shape_star', 'Звезда!')]);
  List<String> assets(Set<String> bundled) =>
      voiceAssets(line, bundled, recordedDir: 'assets/audio/shapes', synthDir: 'assets/audio/shapes_tts');

  test('a fully recorded line plays the live recordings from the given folder', () {
    expect(assets({'assets/audio/shapes/new_shape.wav', 'assets/audio/shapes/shape_star.wav'}), [
      'assets/audio/shapes/new_shape.wav',
      'assets/audio/shapes/shape_star.wav',
    ]);
  });

  test('a half-recorded line with no stand-ins is skipped rather than half-said', () {
    expect(assets({'assets/audio/shapes/new_shape.wav'}), isEmpty);
  });

  test('stand-ins from the synth folder fill in when the live voice is missing', () {
    expect(assets({'assets/audio/shapes_tts/new_shape.m4a', 'assets/audio/shapes_tts/shape_star.m4a'}),
        everyElement(startsWith('assets/audio/shapes_tts/')));
  });

  test('a line reads as its clips one after another', () {
    expect(line.text, 'Новая фигурка! Звезда!');
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/audio/clip_line_player_test.dart`
Expected: FAIL — `clip_line_player.dart` / `voice_line.dart` not found.

- [ ] **Step 3: Create `lib/domain/voice/voice_line.dart`**

```dart
/// One recorded piece of speech: a whole short sentence, stored as its own
/// audio file. Shared by the games that speak in a recorded voice.
class VoiceClip {
  const VoiceClip(this.id, this.text);

  /// File name without the extension, e.g. `food_red_strawberry`.
  final String id;

  /// What to say when recording it.
  final String text;

  @override
  bool operator ==(Object other) => other is VoiceClip && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VoiceClip($id: $text)';
}

/// Something a game says: one or more [clips] played back to back.
class VoiceLine {
  const VoiceLine(this.clips);

  final List<VoiceClip> clips;

  String get text => clips.map((clip) => clip.text).join(' ');

  @override
  String toString() => 'VoiceLine($text)';
}
```

- [ ] **Step 4: Move the classes out of `monster_phrases.dart`**

Delete the `VoiceClip` and `MonsterLine` class declarations (and their doc comments) from `lib/domain/monsters/monster_phrases.dart`. Add at the top, after the existing imports:

```dart
import '../voice/voice_line.dart';

export '../voice/voice_line.dart';
```

Then rename the type everywhere:

Run: `grep -rl MonsterLine lib test tool | xargs sed -i '' 's/MonsterLine/VoiceLine/g'`

- [ ] **Step 5: Create `lib/audio/clip_line_player.dart`** (moved from `monster_voice_player.dart`, parameterised by folders)

```dart
import 'dart:async';
import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../domain/voice/voice_line.dart';
import 'latest_only_queue.dart';

/// The asset files to play for [line], given every asset the app ships
/// ([bundled]): the live recordings `<recordedDir>/<id>.wav` when every clip
/// of the line has one, else the computer-voice stand-ins
/// `<synthDir>/<id>.m4a`, else nothing.
///
/// A line is said in the live voice only when *all* its clips have been
/// recorded, so one sentence never switches speaker halfway through.
List<String> voiceAssets(
  VoiceLine line,
  Set<String> bundled, {
  required String recordedDir,
  required String synthDir,
}) {
  final recorded = [for (final clip in line.clips) '$recordedDir/${clip.id}.wav'];
  if (recorded.every(bundled.contains)) return recorded;
  final synthesized = [for (final clip in line.clips) '$synthDir/${clip.id}.m4a'];
  if (synthesized.every(bundled.contains)) return synthesized;
  return const [];
}

/// Every asset the app ships, or an empty set if the list can't be read.
Future<Set<String>> listBundledAssets(AssetBundle bundle) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    return manifest.listAssets().toSet();
  } catch (error, stackTrace) {
    developer.log('Asset list unavailable', name: 'ClipLinePlayer', error: error, stackTrace: stackTrace);
    return const {};
  }
}

/// Says [VoiceLine]s through `audioplayers`, never one over another: what is
/// being said is said to its end, and of the lines asked for meanwhile only
/// the latest is said next (see [LatestOnlyQueue]). Like
/// `AudioPlayerService`, it logs and swallows playback errors: sound must
/// never stop a game.
class ClipLinePlayer {
  ClipLinePlayer({
    required this.recordedDir,
    required this.synthDir,
    required Future<Set<String>> bundled,
    AudioPlayer Function() playerFactory = AudioPlayer.new,
  })  : _bundled = bundled,
        _playerFactory = playerFactory;

  /// Folder of the live recordings, without a trailing slash.
  final String recordedDir;

  /// Folder of the computer-voice stand-ins, without a trailing slash.
  final String synthDir;

  final Future<Set<String>> _bundled;
  final AudioPlayer Function() _playerFactory;
  _Speaker? _speaker;
  bool _disposed = false;

  late final LatestOnlyQueue<VoiceLine> _lines = LatestOnlyQueue(_speak);

  /// Completes when [line] has been said to its end, or skipped or stopped.
  Future<void> say(VoiceLine line) => _disposed ? Future<void>.value() : _lines.add(line);

  Future<void> _speak(VoiceLine line) async {
    if (_disposed) return;
    // Each line gets a player of its own, so a line stopped by [stop] can
    // never be mistaken for a later one having finished.
    final speaker = _Speaker(_playerFactory());
    _speaker = speaker;
    try {
      final assets = voiceAssets(line, await _bundled, recordedDir: recordedDir, synthDir: synthDir);
      for (final asset in assets) {
        if (speaker.cancelled) break;
        await speaker.playToEnd(AssetSource(asset.substring('assets/'.length)));
      }
    } catch (error, stackTrace) {
      developer.log('Voice playback failed', name: 'ClipLinePlayer', error: error, stackTrace: stackTrace);
    } finally {
      if (identical(_speaker, speaker)) _speaker = null;
      speaker.dispose();
    }
  }

  /// Silences the line being said and forgets the one waiting, if any.
  void stop() {
    _lines.clear();
    _speaker?.cancel();
    _speaker = null;
  }

  /// Releases the native players. Call exactly once.
  void dispose() {
    stop();
    _disposed = true;
  }
}

/// Plays the short sounds in `assets/audio/system/<name>.wav`, one native
/// player per sound, on top of whatever else is sounding.
class SfxPlayer {
  SfxPlayer({AudioPlayer Function() playerFactory = AudioPlayer.new}) : _playerFactory = playerFactory;

  final AudioPlayer Function() _playerFactory;
  final Map<String, AudioPlayer> _players = {};
  bool _disposed = false;

  void play(String fileName) {
    if (_disposed) return;
    final player = _players.putIfAbsent(fileName, _playerFactory);
    unawaited(_quietly(player.play(AssetSource('audio/system/$fileName.wav'))));
  }

  void dispose() {
    _disposed = true;
    for (final player in _players.values) {
      unawaited(_quietly(player.dispose()));
    }
    _players.clear();
  }
}

Future<void> _quietly(Future<void> action) => action.catchError(
      (Object error, StackTrace stackTrace) =>
          developer.log('Audio call failed', name: 'ClipLinePlayer', error: error, stackTrace: stackTrace),
    );

/// One line being said: a player plus the means to cut it short.
class _Speaker {
  _Speaker(this._player);

  final AudioPlayer _player;
  final Completer<void> _cancelled = Completer<void>();

  // Same bounds as AudioPlayerService: a native player that never reports a
  // start or an end must not leave the game waiting forever.
  static const _startLimit = Duration(seconds: 3);
  static const _endSlack = Duration(seconds: 2);
  static const _unknownClipLength = Duration(seconds: 6);

  bool get cancelled => _cancelled.isCompleted;

  void cancel() {
    if (cancelled) return;
    _cancelled.complete();
    unawaited(_quietly(_player.stop()));
  }

  Future<void> playToEnd(Source source) async {
    final completed = _player.onPlayerComplete.first..ignore();
    await _player.play(source).timeout(_startLimit);
    if (cancelled) return;
    Duration? length;
    try {
      length = await _player.getDuration().timeout(const Duration(seconds: 1));
    } catch (_) {
      length = null;
    }
    await Future.any([completed, _cancelled.future]).timeout((length ?? _unknownClipLength) + _endSlack);
  }

  void dispose() => unawaited(_quietly(_player.dispose()));
}
```

- [ ] **Step 6: Replace `lib/audio/monster_voice_player.dart` with the thin wrapper**

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../domain/monsters/monster_phrases.dart';
import 'clip_line_player.dart';
import 'monster_voice.dart';

/// Where the live recordings of the game's phrases go, one `.wav` per
/// [VoiceClip] — written by `tool/slice_voiceover.dart monsters-<N>`.
const monsterRecordedVoiceDir = 'assets/audio/monsters';

/// Stand-in computer-voice versions of the same phrases, generated by
/// `tool/generate_monster_tts.dart`. Used until a phrase has a live recording.
const monsterSynthVoiceDir = 'assets/audio/monsters_tts';

/// The asset files to play for [line] in the "Монстрики" game.
List<String> monsterVoiceAssets(VoiceLine line, Set<String> bundled) =>
    voiceAssets(line, bundled, recordedDir: monsterRecordedVoiceDir, synthDir: monsterSynthVoiceDir);

/// Plays the "Монстрики" phrases and sound effects.
class MonsterVoicePlayer implements MonsterVoice {
  MonsterVoicePlayer({AssetBundle? bundle, AudioPlayer Function() playerFactory = AudioPlayer.new})
      : _lines = ClipLinePlayer(
          recordedDir: monsterRecordedVoiceDir,
          synthDir: monsterSynthVoiceDir,
          bundled: listBundledAssets(bundle ?? rootBundle),
          playerFactory: playerFactory,
        ),
        _sfx = SfxPlayer(playerFactory: playerFactory);

  final ClipLinePlayer _lines;
  final SfxPlayer _sfx;

  @override
  Future<void> say(VoiceLine line) => _lines.say(line);

  @override
  void playSfx(MonsterSfx sfx) => _sfx.play(sfx.fileName);

  @override
  void stop() => _lines.stop();

  @override
  void dispose() {
    _lines.dispose();
    _sfx.dispose();
  }
}
```

- [ ] **Step 7: Run the whole suite**

Run: `flutter test && flutter analyze`
Expected: all tests pass (340 + 4 new), no analyzer issues. If an import of `VoiceClip`/`VoiceLine` is reported unused somewhere, remove it.

- [ ] **Step 8: Commit**

```bash
git add -A lib test
git commit -m "refactor: one phrase player for every game; MonsterLine becomes VoiceLine

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Shapes and the picture chain (data)

**Files:**
- Create: `lib/domain/shapes/shape_kind.dart`, `lib/domain/shapes/shape_picture.dart`, `test/domain/shapes/shape_picture_test.dart`

**Interfaces:**
- Produces: `enum ShapeKind { circle, triangle, square, rectangle, oval, star, heart, semicircle, rhombus, crescent }` with `String word`; `const double cardSize = 300`; `class CardBox(x, y, width, height)` with `right`, `bottom`, `area`, `center` (`({double x, double y})`), `bool contains(double px, double py, {double margin = 0})`; `class ShapeSlot(ShapeKind kind, CardBox box, {int quarterTurns = 0, bool stays = false, bool pulses = false})` with `({double width, double height}) get upright`; `enum PictureMotion { wiggle, hop, chug, drive, launch, swim, rock, sway, pulse }`; `class ShapePicture({id, word, motion, slots, pivot})`; `const List<ShapePicture> shapePictures`.

- [ ] **Step 1: Write the failing test** — `test/domain/shapes/shape_picture_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';

void main() {
  test('twelve pictures in the order of the spec', () {
    expect(shapePictures.map((p) => p.id), [
      'ice_cream', 'house', 'car', 'tree', 'train', 'fish',
      'rocket', 'bear', 'boat', 'kite', 'night_sky', 'clown',
    ]);
    expect(shapePictures.first.word, 'Мороженое');
  });

  test('each picture brings at most one new shape (the first brings two), in teaching order', () {
    final met = <ShapeKind>{};
    for (final (index, picture) in shapePictures.indexed) {
      final before = met.length;
      met.addAll(picture.slots.map((slot) => slot.kind));
      expect(met.length - before, lessThanOrEqualTo(index == 0 ? 2 : 1), reason: picture.id);
      expect(met, ShapeKind.values.take(met.length).toSet(), reason: 'shapes are met in teaching order (${picture.id})');
    }
    expect(met, ShapeKind.values.toSet());
  });

  test('every piece is big enough for a small finger and lies on the card', () {
    for (final picture in shapePictures) {
      expect(picture.slots.length, inInclusiveRange(2, 5), reason: picture.id);
      for (final slot in picture.slots) {
        final box = slot.box;
        expect(box.width, greaterThanOrEqualTo(50), reason: '${picture.id} ${slot.kind}');
        expect(box.height, greaterThanOrEqualTo(50), reason: '${picture.id} ${slot.kind}');
        expect(box.x >= 0 && box.y >= 0 && box.right <= cardSize && box.bottom <= cardSize, isTrue,
            reason: '${picture.id} ${slot.kind}');
      }
    }
  });

  test('circles and squares are round and square; rectangles and ovals are not', () {
    for (final picture in shapePictures) {
      for (final slot in picture.slots) {
        final up = slot.upright;
        switch (slot.kind) {
          case ShapeKind.circle || ShapeKind.square:
            expect(up.width, up.height, reason: '${picture.id} ${slot.kind}');
          case ShapeKind.rectangle || ShapeKind.oval:
            expect(up.width, isNot(up.height), reason: '${picture.id} ${slot.kind}');
          default:
            break;
        }
      }
    }
  });

  test('a turned slot swaps width and height for its upright shape', () {
    const slot = ShapeSlot(ShapeKind.triangle, CardBox(22, 90, 84, 106), quarterTurns: 1);
    expect(slot.upright, (width: 106.0, height: 84.0));
  });

  test('a box contains points inside it and, with a margin, near it', () {
    const box = CardBox(10, 20, 30, 40);
    expect(box.contains(25, 30), isTrue);
    expect(box.contains(45, 30), isFalse);
    expect(box.contains(45, 30, margin: 6), isTrue);
    expect(box.area, 1200);
    expect(box.center, (x: 25.0, y: 40.0));
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/domain/shapes/shape_picture_test.dart`
Expected: FAIL — files not found.

- [ ] **Step 3: Create `lib/domain/shapes/shape_kind.dart`**

```dart
/// The shapes of the "Фигурки" game, in the order a child meets them.
/// `name` doubles as the file id: `shape_circle.wav`.
enum ShapeKind {
  circle('Круг'),
  triangle('Треугольник'),
  square('Квадрат'),
  rectangle('Прямоугольник'),
  oval('Овал'),
  star('Звезда'),
  heart('Сердечко'),
  semicircle('Полукруг'),
  rhombus('Ромб'),
  crescent('Месяц');

  const ShapeKind(this.word);

  /// The shape's name as the voice says it: «Круг».
  final String word;
}
```

- [ ] **Step 4: Create `lib/domain/shapes/shape_picture.dart`**

```dart
import 'shape_kind.dart';

/// The side of a picture card, in the units its pieces are laid out in.
const double cardSize = 300;

/// A rectangle on the picture card, in card units (0…[cardSize]).
class CardBox {
  const CardBox(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;
  double get area => width * height;
  ({double x, double y}) get center => (x: x + width / 2, y: y + height / 2);

  /// True if the point lies inside the box grown by [margin] on every side.
  bool contains(double px, double py, {double margin = 0}) =>
      px >= x - margin && px <= right + margin && py >= y - margin && py <= bottom + margin;
}

/// One piece of a picture: its shape, the box it fills and how it is turned.
class ShapeSlot {
  const ShapeSlot(this.kind, this.box, {this.quarterTurns = 0, this.stays = false, this.pulses = false});

  final ShapeKind kind;

  /// The box the piece fills once turned.
  final CardBox box;

  /// Quarter turns clockwise from the upright shape: a triangle points up, a
  /// semicircle has its flat side down, a crescent opens to the right.
  final int quarterTurns;

  /// Stays put when the finished picture moves (the star beside the rocket).
  final bool stays;

  /// Pulses on its own when the finished picture comes alive (night stars).
  final bool pulses;

  /// The size of the upright shape, before it is turned into [box].
  ({double width, double height}) get upright =>
      quarterTurns.isOdd ? (width: box.height, height: box.width) : (width: box.width, height: box.height);
}

/// How a finished picture comes alive.
enum PictureMotion { wiggle, hop, chug, drive, launch, swim, rock, sway, pulse }

/// A picture the child builds out of shapes.
class ShapePicture {
  const ShapePicture({
    required this.id,
    required this.word,
    required this.motion,
    required this.slots,
    this.pivot = (x: 150.0, y: 150.0),
  });

  /// Used in file names: `picture_house.wav`, `backgrounds/house.jpg`.
  final String id;

  /// What the voice calls it: «Домик».
  final String word;

  final PictureMotion motion;

  /// Later slots lie on top of earlier ones (the window over the wall).
  final List<ShapeSlot> slots;

  /// The point of the card the picture turns around when it moves.
  final ({double x, double y}) pivot;
}

/// The chain of pictures, in the order a child meets them: each brings at
/// most one new shape (the first brings two). Boxes are carried over from
/// the prototype (`docs/prototypes/shapes.html`).
const List<ShapePicture> shapePictures = [
  ShapePicture(id: 'ice_cream', word: 'Мороженое', motion: PictureMotion.wiggle, pivot: (x: 150, y: 280), slots: [
    ShapeSlot(ShapeKind.triangle, CardBox(105, 140, 90, 136), quarterTurns: 2),
    ShapeSlot(ShapeKind.circle, CardBox(88, 50, 124, 124)),
  ]),
  ShapePicture(id: 'house', word: 'Домик', motion: PictureMotion.hop, pivot: (x: 150, y: 290), slots: [
    ShapeSlot(ShapeKind.square, CardBox(75, 135, 150, 150)),
    ShapeSlot(ShapeKind.triangle, CardBox(48, 38, 204, 108)),
    ShapeSlot(ShapeKind.circle, CardBox(94, 162, 64, 64)),
  ]),
  ShapePicture(id: 'car', word: 'Машинка', motion: PictureMotion.drive, slots: [
    ShapeSlot(ShapeKind.square, CardBox(82, 62, 140, 140)),
    ShapeSlot(ShapeKind.circle, CardBox(66, 176, 74, 74)),
    ShapeSlot(ShapeKind.circle, CardBox(166, 176, 74, 74)),
  ]),
  ShapePicture(id: 'tree', word: 'Ёлочка', motion: PictureMotion.wiggle, pivot: (x: 150, y: 280), slots: [
    ShapeSlot(ShapeKind.square, CardBox(122, 220, 56, 56)),
    ShapeSlot(ShapeKind.triangle, CardBox(52, 95, 196, 140)),
    ShapeSlot(ShapeKind.triangle, CardBox(84, 22, 132, 108)),
  ]),
  ShapePicture(id: 'train', word: 'Паровозик', motion: PictureMotion.chug, slots: [
    ShapeSlot(ShapeKind.rectangle, CardBox(26, 138, 156, 74)),
    ShapeSlot(ShapeKind.square, CardBox(170, 92, 118, 118)),
    ShapeSlot(ShapeKind.circle, CardBox(44, 182, 70, 70)),
    ShapeSlot(ShapeKind.circle, CardBox(194, 182, 70, 70)),
  ]),
  ShapePicture(id: 'fish', word: 'Рыбка', motion: PictureMotion.swim, slots: [
    ShapeSlot(ShapeKind.triangle, CardBox(22, 90, 84, 106), quarterTurns: 1),
    ShapeSlot(ShapeKind.oval, CardBox(70, 82, 168, 118)),
    ShapeSlot(ShapeKind.circle, CardBox(166, 98, 54, 54)),
  ]),
  ShapePicture(id: 'rocket', word: 'Ракета', motion: PictureMotion.launch, slots: [
    ShapeSlot(ShapeKind.rectangle, CardBox(105, 92, 90, 165)),
    ShapeSlot(ShapeKind.triangle, CardBox(105, 26, 90, 74)),
    ShapeSlot(ShapeKind.circle, CardBox(123, 124, 54, 54)),
    ShapeSlot(ShapeKind.star, CardBox(204, 34, 78, 74), stays: true),
  ]),
  ShapePicture(id: 'bear', word: 'Мишка', motion: PictureMotion.rock, pivot: (x: 150, y: 290), slots: [
    ShapeSlot(ShapeKind.oval, CardBox(88, 148, 124, 138)),
    ShapeSlot(ShapeKind.circle, CardBox(94, 46, 112, 112)),
    ShapeSlot(ShapeKind.heart, CardBox(120, 196, 60, 54)),
  ]),
  ShapePicture(id: 'boat', word: 'Кораблик', motion: PictureMotion.rock, pivot: (x: 150, y: 236), slots: [
    ShapeSlot(ShapeKind.triangle, CardBox(62, 52, 80, 120)),
    ShapeSlot(ShapeKind.triangle, CardBox(160, 72, 74, 100)),
    ShapeSlot(ShapeKind.semicircle, CardBox(48, 176, 204, 94), quarterTurns: 2),
  ]),
  ShapePicture(id: 'kite', word: 'Воздушный змей', motion: PictureMotion.sway, pivot: (x: 40, y: 275), slots: [
    ShapeSlot(ShapeKind.rhombus, CardBox(80, 22, 140, 182)),
    ShapeSlot(ShapeKind.triangle, CardBox(113, 199, 54, 54), quarterTurns: 1),
    ShapeSlot(ShapeKind.triangle, CardBox(60, 230, 54, 54), quarterTurns: 3),
  ]),
  ShapePicture(id: 'night_sky', word: 'Ночное небо', motion: PictureMotion.pulse, slots: [
    ShapeSlot(ShapeKind.crescent, CardBox(40, 32, 144, 144)),
    ShapeSlot(ShapeKind.star, CardBox(196, 40, 80, 76), pulses: true),
    ShapeSlot(ShapeKind.star, CardBox(170, 150, 66, 63), pulses: true),
  ]),
  ShapePicture(id: 'clown', word: 'Клоун', motion: PictureMotion.hop, pivot: (x: 150, y: 290), slots: [
    ShapeSlot(ShapeKind.circle, CardBox(72, 96, 156, 156)),
    ShapeSlot(ShapeKind.triangle, CardBox(98, 6, 104, 100)),
    ShapeSlot(ShapeKind.circle, CardBox(123, 156, 54, 54)),
    ShapeSlot(ShapeKind.heart, CardBox(80, 176, 54, 50)),
    ShapeSlot(ShapeKind.heart, CardBox(166, 176, 54, 50)),
  ]),
];
```

- [ ] **Step 5: Run the test**

Run: `flutter test test/domain/shapes/shape_picture_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/shapes test/domain/shapes
git commit -m "feat: the ten shapes and the chain of twelve pictures for «Фигурки»

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Game rules — `ShapesGame`

**Files:**
- Create: `lib/domain/shapes/shapes_game.dart`, `test/domain/shapes/shapes_game_test.dart`

**Interfaces:**
- Consumes: Task 2 types.
- Produces: `class PieceShown({int slot, ShapeKind kind, bool firstMeeting})`; `class DropResult({bool accepted, int slot, bool pictureComplete, bool chainComplete})`; `class ShapesGame({Random? random, List<ShapePicture> pictures = shapePictures})` with `pictures`, `pictureIndex`, `picture`, `filled` (`Set<int>`), `pieceSlot` (`int?`), `pieceKind` (`ShapeKind?`), `metKinds`, `chainDone`, `pictureComplete`, `PieceShown nextPiece()`, `DropResult drop(int slot)`, `void nextPicture()`, `int? slotAt(double x, double y, {double margin = 0})`.

- [ ] **Step 1: Write the failing test** — `test/domain/shapes/shapes_game_test.dart`:

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';
import 'package:yandee/domain/shapes/shapes_game.dart';

// A wall with a window on it under a roof; two wheels; a star and a ball.
const _house = ShapePicture(id: 'a', word: 'А', motion: PictureMotion.hop, slots: [
  ShapeSlot(ShapeKind.square, CardBox(50, 100, 200, 180)),
  ShapeSlot(ShapeKind.circle, CardBox(80, 140, 60, 60)),
  ShapeSlot(ShapeKind.triangle, CardBox(40, 10, 220, 90)),
]);
const _wheels = ShapePicture(id: 'b', word: 'Б', motion: PictureMotion.drive, slots: [
  ShapeSlot(ShapeKind.circle, CardBox(20, 200, 70, 70)),
  ShapeSlot(ShapeKind.circle, CardBox(200, 200, 70, 70)),
]);
const _sky = ShapePicture(id: 'c', word: 'В', motion: PictureMotion.pulse, slots: [
  ShapeSlot(ShapeKind.star, CardBox(100, 100, 80, 76)),
  ShapeSlot(ShapeKind.circle, CardBox(10, 10, 60, 60)),
]);

ShapesGame _game([int seed = 1]) => ShapesGame(random: Random(seed), pictures: const [_house, _wheels, _sky]);

/// A fresh game whose first piece is of [kind].
ShapesGame _gameWithPiece(ShapeKind kind) {
  for (var seed = 0; seed < 200; seed++) {
    final game = _game(seed);
    if (game.nextPiece().kind == kind) return game;
  }
  throw StateError('no seed gives a $kind first');
}

/// Places every piece of the current picture; returns the last drop.
DropResult _finish(ShapesGame game) {
  late DropResult last;
  while (!game.pictureComplete) {
    final slot = game.pieceSlot ?? game.nextPiece().slot;
    last = game.drop(slot);
  }
  return last;
}

void main() {
  test('starts on the first picture with nothing placed and no piece on the mat', () {
    final game = _game();
    expect(game.pictureIndex, 0);
    expect(game.filled, isEmpty);
    expect(game.pieceSlot, isNull);
    expect(game.metKinds, isEmpty);
  });

  test('pieces come one at a time, each slot once, in a shuffled order', () {
    final firsts = <int>{};
    for (var seed = 0; seed < 20; seed++) {
      final game = _game(seed);
      final seen = <int>[];
      while (!game.pictureComplete) {
        final piece = game.nextPiece();
        seen.add(piece.slot);
        game.drop(piece.slot);
      }
      expect(seen.toSet(), {0, 1, 2});
      firsts.add(seen.first);
    }
    expect(firsts.length, greaterThan(1));
  });

  test('a shape is new only the first time it comes up', () {
    final game = _game();
    while (!game.pictureComplete) {
      final piece = game.nextPiece();
      expect(piece.firstMeeting, isTrue);
      game.drop(piece.slot);
    }
    game.nextPicture();
    final wheel = game.nextPiece();
    expect(wheel.kind, ShapeKind.circle);
    expect(wheel.firstMeeting, isFalse);
    expect(game.metKinds, {ShapeKind.square, ShapeKind.circle, ShapeKind.triangle});
  });

  test('a wrong shape changes nothing and the piece stays on the mat', () {
    final game = _gameWithPiece(ShapeKind.circle);
    final result = game.drop(0); // the wall is a square
    expect(result.accepted, isFalse);
    expect(game.filled, isEmpty);
    expect(game.pieceKind, ShapeKind.circle);
  });

  test('a piece may fill any free slot of its shape; the other is offered later', () {
    final game = _game();
    _finish(game);
    game.nextPicture();
    final first = game.nextPiece().slot;
    final other = 1 - first;
    expect(game.drop(other).accepted, isTrue);
    expect(game.filled, {other});
    expect(game.nextPiece().slot, first);
  });

  test('misuse is refused loudly', () {
    final game = _game();
    expect(() => game.drop(0), throwsStateError);
    final piece = game.nextPiece();
    expect(game.nextPiece, throwsStateError);
    game.drop(piece.slot);
    game.nextPiece();
    expect(() => game.drop(piece.slot), throwsStateError);
    expect(game.nextPicture, throwsStateError);
  });

  test('the chain goes in order, ends once, then pictures come in any order but never twice running', () {
    final game = _game();
    expect(_finish(game).pictureComplete, isTrue);
    game.nextPicture();
    expect(game.pictureIndex, 1);
    expect(_finish(game).chainComplete, isFalse);
    game.nextPicture();
    expect(game.pictureIndex, 2);
    final last = _finish(game);
    expect(last.chainComplete, isTrue);
    expect(game.chainDone, isTrue);

    var previous = game.pictureIndex;
    for (var i = 0; i < 30; i++) {
      game.nextPicture();
      expect(game.pictureIndex, isNot(previous));
      previous = game.pictureIndex;
      expect(_finish(game).chainComplete, isFalse);
    }
  });

  group('slotAt', () {
    test('nothing is found without a piece on the mat, or far from every slot', () {
      final game = _game();
      expect(game.slotAt(150, 200), isNull);
      game.nextPiece();
      expect(game.slotAt(295, 295), isNull);
    });

    test('the smallest slot under the finger wins when none has the right shape', () {
      final game = _gameWithPiece(ShapeKind.triangle);
      expect(game.slotAt(100, 160), 1); // the window, on top of the wall
      expect(game.slotAt(200, 250), 0); // the wall away from the window
    });

    test('a slot of the right shape wins, even within the margin only', () {
      final circle = _gameWithPiece(ShapeKind.circle);
      expect(circle.slotAt(160, 160, margin: 24), 1); // 20 past the window's edge
      expect(circle.slotAt(160, 160), 0);
      final square = _gameWithPiece(ShapeKind.square);
      expect(square.slotAt(100, 160), 0); // over the window, but the wall is the square
    });

    test('filled slots are not found', () {
      final game = _gameWithPiece(ShapeKind.circle);
      game.drop(1);
      game.nextPiece();
      expect(game.slotAt(100, 160), 0);
    });
  });

  test('the real chain starts with the ice cream', () {
    final game = ShapesGame(random: Random(3));
    expect(game.picture.id, 'ice_cream');
    expect(game.nextPiece().firstMeeting, isTrue);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/domain/shapes/shapes_game_test.dart`
Expected: FAIL — `shapes_game.dart` not found.

- [ ] **Step 3: Create `lib/domain/shapes/shapes_game.dart`**

```dart
import 'dart:math';

import 'shape_kind.dart';
import 'shape_picture.dart';

/// A piece has been put on the mat.
class PieceShown {
  const PieceShown({required this.slot, required this.kind, required this.firstMeeting});

  /// The slot of the current picture the piece was cut for.
  final int slot;
  final ShapeKind kind;

  /// The child meets this shape for the first time in this game:
  /// «Новая фигурка! …».
  final bool firstMeeting;
}

/// What happened when the piece was let go over a slot.
class DropResult {
  const DropResult({
    required this.accepted,
    required this.slot,
    required this.pictureComplete,
    required this.chainComplete,
  });

  /// The shapes matched and the slot is filled now. Otherwise nothing
  /// changed: the piece goes back to the mat.
  final bool accepted;

  /// The slot it was let go over.
  final int slot;

  /// That was the last piece of the picture.
  final bool pictureComplete;

  /// That finished the last picture of the chain for the first time.
  final bool chainComplete;
}

/// The rules of the "Фигурки" game, with no drawing, sound or timing in
/// them: which picture is being built, which slots are filled, which piece
/// lies on the mat and which shapes the child has met.
///
/// The screen drives it: [nextPiece], then [drop] until the picture is
/// complete, then [nextPicture]. Pictures follow the chain in order; once
/// the last one is done they come in random order, never the same twice in
/// a row. Nothing is remembered between games.
class ShapesGame {
  ShapesGame({Random? random, List<ShapePicture> pictures = shapePictures})
      : _random = random ?? Random(),
        pictures = List.unmodifiable(pictures) {
    if (pictures.length < 2) throw ArgumentError.value(pictures, 'pictures', 'needs at least two');
    _startPicture(0);
  }

  final Random _random;
  final List<ShapePicture> pictures;

  int _index = 0;
  final Set<int> _filled = {};
  List<int> _order = const [];
  int? _pieceSlot;
  final Set<ShapeKind> _met = {};
  bool _chainDone = false;

  int get pictureIndex => _index;
  ShapePicture get picture => pictures[_index];

  /// Slots of the current picture that hold their piece.
  Set<int> get filled => Set.unmodifiable(_filled);

  /// The slot the piece on the mat was cut for; null when the mat is empty.
  int? get pieceSlot => _pieceSlot;

  ShapeKind? get pieceKind {
    final slot = _pieceSlot;
    return slot == null ? null : picture.slots[slot].kind;
  }

  Set<ShapeKind> get metKinds => Set.unmodifiable(_met);

  /// The whole chain has been built once.
  bool get chainDone => _chainDone;

  bool get pictureComplete => _filled.length == picture.slots.length;

  void _startPicture(int index) {
    _index = index;
    _filled.clear();
    _pieceSlot = null;
    _order = [for (var slot = 0; slot < picture.slots.length; slot++) slot]..shuffle(_random);
  }

  /// Puts the next piece of the picture on the mat.
  PieceShown nextPiece() {
    if (_pieceSlot != null) throw StateError('A piece is already on the mat');
    if (pictureComplete) throw StateError('The picture is complete');
    final slot = _order.firstWhere((slot) => !_filled.contains(slot));
    _pieceSlot = slot;
    final kind = picture.slots[slot].kind;
    return PieceShown(slot: slot, kind: kind, firstMeeting: _met.add(kind));
  }

  /// Lets the piece go over [slot]. Any free slot of the piece's shape takes
  /// it; any other leaves everything as it was.
  DropResult drop(int slot) {
    final kind = pieceKind;
    if (kind == null) throw StateError('No piece on the mat');
    if (_filled.contains(slot)) throw StateError('Slot $slot is already filled');
    if (picture.slots[slot].kind != kind) {
      return DropResult(accepted: false, slot: slot, pictureComplete: false, chainComplete: false);
    }
    _filled.add(slot);
    _pieceSlot = null;
    final complete = pictureComplete;
    final chainComplete = complete && !_chainDone && _index == pictures.length - 1;
    if (chainComplete) _chainDone = true;
    return DropResult(accepted: true, slot: slot, pictureComplete: complete, chainComplete: chainComplete);
  }

  /// Moves on from a finished picture.
  void nextPicture() {
    if (!pictureComplete) throw StateError('The picture is not finished');
    if (!_chainDone) {
      _startPicture(_index + 1);
      return;
    }
    final others = [for (var i = 0; i < pictures.length; i++) if (i != _index) i];
    _startPicture(others[_random.nextInt(others.length)]);
  }

  /// The free slot a finger at ([x], [y]) (card units) points at, or null.
  ///
  /// Slots within [margin] of the point count; among them a slot of the
  /// piece's shape wins, then a slot the point is really inside, and of
  /// what is left the smallest (a window over a wall).
  int? slotAt(double x, double y, {double margin = 0}) {
    final kind = pieceKind;
    if (kind == null) return null;
    final slots = picture.slots;
    final near = [
      for (var i = 0; i < slots.length; i++)
        if (!_filled.contains(i) && slots[i].box.contains(x, y, margin: margin)) i,
    ];
    if (near.isEmpty) return null;
    final sameShape = near.where((i) => slots[i].kind == kind).toList();
    final inside = near.where((i) => slots[i].box.contains(x, y)).toList();
    final pool = sameShape.isNotEmpty ? sameShape : (inside.isNotEmpty ? inside : near);
    pool.sort((a, b) => slots[a].box.area.compareTo(slots[b].box.area));
    return pool.first;
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/domain/shapes/shapes_game_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/shapes/shapes_game.dart test/domain/shapes/shapes_game_test.dart
git commit -m "feat: the rules of «Фигурки» — one piece at a time, no losing, the chain then any order

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Phrases and the game's voice seam

**Files:**
- Create: `lib/domain/shapes/shape_phrases.dart`, `lib/audio/shapes_voice.dart`, `lib/audio/shapes_voice_player.dart`, `test/support/fake_shapes_voice.dart`, `test/domain/shapes/shape_phrases_test.dart`, `test/audio/shapes_voice_player_test.dart`

**Interfaces:**
- Consumes: `VoiceClip`, `VoiceLine`, `ClipLinePlayer`, `SfxPlayer`, `listBundledAssets`, `voiceAssets` (Task 1); `ShapeKind`, `ShapePicture`, `shapePictures` (Task 2).
- Produces: `abstract final class ShapePhrases` with clips `intro`, `newShape`, `notHere`, `hooray`, `win`; `static VoiceClip shape(ShapeKind)`, `static VoiceClip picture(ShapePicture)`; lines `introLine`, `notHereLine`, `winLine`, `static VoiceLine name(ShapeKind)`, `static VoiceLine meet(ShapeKind)`, `static VoiceLine done(ShapePicture)`; `static List<VoiceClip> get allClips`. `enum ShapesSfx { placed, wrong, pictureDone, allDone }` with `fileName`; `abstract class ShapesVoice { Future<void> say(VoiceLine); void playSfx(ShapesSfx); void stop(); void dispose(); }`; `const shapesRecordedVoiceDir = 'assets/audio/shapes'`; `class ShapesVoicePlayer implements ShapesVoice`; test fake `FakeShapesVoice` with `said` (`List<String>`), `sfx`, `stopCalls`, `disposeCalled`, `holdSpeech()`, `finishSpeaking()`.

- [ ] **Step 1: Write the failing tests**

`test/domain/shapes/shape_phrases_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_phrases.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';

void main() {
  test('27 clips with unique, file-safe ids', () {
    final clips = ShapePhrases.allClips;
    expect(clips, hasLength(27));
    expect(clips.map((c) => c.id).toSet(), hasLength(27));
    for (final clip in clips) {
      expect(clip.id, matches(RegExp(r'^[a-z_]+$')), reason: clip.text);
    }
  });

  test('shapes and pictures say their names', () {
    expect(ShapePhrases.shape(ShapeKind.circle).id, 'shape_circle');
    expect(ShapePhrases.shape(ShapeKind.circle).text, 'Круг!');
    expect(ShapePhrases.picture(shapePictures.first).id, 'picture_ice_cream');
    expect(ShapePhrases.picture(shapePictures.first).text, 'Мороженое!');
  });

  test('longer lines are put together from whole phrases', () {
    expect(ShapePhrases.introLine.text, 'Собери картинку из фигурок!');
    expect(ShapePhrases.name(ShapeKind.star).text, 'Звезда!');
    expect(ShapePhrases.meet(ShapeKind.star).text, 'Новая фигурка! Звезда!');
    expect(ShapePhrases.notHereLine.text, 'Не сюда!');
    expect(ShapePhrases.done(shapePictures[1]).text, 'Домик! Ура!');
    expect(ShapePhrases.winLine.text, 'Ура! Ты знаешь все фигурки!');
  });

  test('the clip list runs shapes, pictures, then the general phrases — the recording order', () {
    final texts = ShapePhrases.allClips.map((c) => c.text).toList();
    expect(texts.take(10), [for (final kind in ShapeKind.values) '${kind.word}!']);
    expect(texts.skip(10).take(12), [for (final p in shapePictures) '${p.word}!']);
    expect(texts.skip(22), [
      'Собери картинку из фигурок!',
      'Новая фигурка!',
      'Не сюда!',
      'Ура!',
      'Ура! Ты знаешь все фигурки!',
    ]);
  });
}
```

`test/audio/shapes_voice_player_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/shapes_voice.dart';
import 'package:yandee/audio/shapes_voice_player.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_phrases.dart';

void main() {
  test('a line plays the live recordings of the game', () {
    expect(shapesVoiceAssets(ShapePhrases.meet(ShapeKind.star), {
      'assets/audio/shapes/new_shape.wav',
      'assets/audio/shapes/shape_star.wav',
    }), ['assets/audio/shapes/new_shape.wav', 'assets/audio/shapes/shape_star.wav']);
  });

  test('every sound effect the game plays is in assets/audio/system/', () {
    for (final sfx in ShapesSfx.values) {
      expect(File('assets/audio/system/${sfx.fileName}.wav').existsSync(), isTrue, reason: sfx.name);
    }
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/domain/shapes/shape_phrases_test.dart test/audio/shapes_voice_player_test.dart`
Expected: FAIL — files not found.

- [ ] **Step 3: Create `lib/domain/shapes/shape_phrases.dart`**

```dart
import '../voice/voice_line.dart';
import 'shape_kind.dart';
import 'shape_picture.dart';

export '../voice/voice_line.dart';

/// Every phrase of the "Фигурки" game. Longer lines are whole phrases said
/// one after another: «Новая фигурка!» + «Звезда!», «Домик!» + «Ура!» — so
/// each word is recorded once.
abstract final class ShapePhrases {
  static const intro = VoiceClip('intro', 'Собери картинку из фигурок!');
  static const newShape = VoiceClip('new_shape', 'Новая фигурка!');
  static const notHere = VoiceClip('not_here', 'Не сюда!');
  static const hooray = VoiceClip('hooray', 'Ура!');
  static const win = VoiceClip('win', 'Ура! Ты знаешь все фигурки!');

  /// «Круг!»
  static VoiceClip shape(ShapeKind kind) => VoiceClip('shape_${kind.name}', '${kind.word}!');

  /// «Домик!»
  static VoiceClip picture(ShapePicture picture) => VoiceClip('picture_${picture.id}', '${picture.word}!');

  static const introLine = VoiceLine([intro]);
  static const notHereLine = VoiceLine([notHere]);
  static const winLine = VoiceLine([win]);

  /// A piece names its shape: «Звезда!».
  static VoiceLine name(ShapeKind kind) => VoiceLine([shape(kind)]);

  /// A shape met for the first time: «Новая фигурка! Звезда!».
  static VoiceLine meet(ShapeKind kind) => VoiceLine([newShape, shape(kind)]);

  /// A finished picture: «Домик! Ура!».
  static VoiceLine done(ShapePicture picture) => VoiceLine([ShapePhrases.picture(picture), hooray]);

  /// Every clip, in the order they are recorded: the shapes, the pictures,
  /// then the general phrases.
  static List<VoiceClip> get allClips => [
        for (final kind in ShapeKind.values) shape(kind),
        for (final picture in shapePictures) ShapePhrases.picture(picture),
        intro,
        newShape,
        notHere,
        hooray,
        win,
      ];
}
```

- [ ] **Step 4: Create `lib/audio/shapes_voice.dart`**

```dart
import '../domain/voice/voice_line.dart';

/// The short non-speech sounds of the "Фигурки" game — existing files in
/// `assets/audio/system/`, shared with «Монстрики».
enum ShapesSfx {
  /// A piece clicked into its place.
  placed('monster_pop'),

  /// A piece let go over a slot of another shape.
  wrong('monster_boing'),

  /// A picture is finished.
  pictureDone('monster_clap'),

  /// The whole chain is finished.
  allDone('monster_win');

  const ShapesSfx(this.fileName);

  /// File name in `assets/audio/system/`, without the extension.
  final String fileName;
}

/// Everything the "Фигурки" screen needs to make a sound — the seam that
/// lets tests run the game with no audio plugin behind it.
abstract class ShapesVoice {
  /// Says [line] — never over another line (the latest-only rule).
  /// Completes when it has been said, skipped or stopped.
  Future<void> say(VoiceLine line);

  /// Plays a sound effect on top of whatever else is sounding.
  void playSfx(ShapesSfx sfx);

  /// Silences the line being said and forgets the one waiting, if any.
  void stop();

  /// Releases the native players. Call exactly once.
  void dispose();
}
```

- [ ] **Step 5: Create `lib/audio/shapes_voice_player.dart`**

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../domain/voice/voice_line.dart';
import 'clip_line_player.dart';
import 'shapes_voice.dart';

/// Where the live recordings of the game's phrases are, one `.wav` per clip
/// — written by `tool/slice_voiceover.dart shapes-<N>`.
const shapesRecordedVoiceDir = 'assets/audio/shapes';

// Every phrase is recorded, so there are no computer-voice stand-ins; the
// folder is only named so a missing recording is skipped, not half-said.
const _shapesSynthVoiceDir = 'assets/audio/shapes_tts';

/// The asset files to play for [line] in the "Фигурки" game.
List<String> shapesVoiceAssets(VoiceLine line, Set<String> bundled) =>
    voiceAssets(line, bundled, recordedDir: shapesRecordedVoiceDir, synthDir: _shapesSynthVoiceDir);

/// Plays the "Фигурки" phrases and sound effects.
class ShapesVoicePlayer implements ShapesVoice {
  ShapesVoicePlayer({AssetBundle? bundle, AudioPlayer Function() playerFactory = AudioPlayer.new})
      : _lines = ClipLinePlayer(
          recordedDir: shapesRecordedVoiceDir,
          synthDir: _shapesSynthVoiceDir,
          bundled: listBundledAssets(bundle ?? rootBundle),
          playerFactory: playerFactory,
        ),
        _sfx = SfxPlayer(playerFactory: playerFactory);

  final ClipLinePlayer _lines;
  final SfxPlayer _sfx;

  @override
  Future<void> say(VoiceLine line) => _lines.say(line);

  @override
  void playSfx(ShapesSfx sfx) => _sfx.play(sfx.fileName);

  @override
  void stop() => _lines.stop();

  @override
  void dispose() {
    _lines.dispose();
    _sfx.dispose();
  }
}
```

- [ ] **Step 6: Create `test/support/fake_shapes_voice.dart`**

```dart
import 'dart:async';

import 'package:yandee/audio/shapes_voice.dart';
import 'package:yandee/domain/voice/voice_line.dart';

/// Records what the "Фигурки" screen asked to hear, playing nothing.
class FakeShapesVoice implements ShapesVoice {
  /// The text of every line said, in order.
  final List<String> said = [];
  final List<ShapesSfx> sfx = [];
  int stopCalls = 0;
  bool disposeCalled = false;

  Completer<void>? _held;

  /// Makes the next [say] not finish until [finishSpeaking] is called.
  void holdSpeech() => _held = Completer<void>();

  void finishSpeaking() {
    _held?.complete();
    _held = null;
  }

  @override
  Future<void> say(VoiceLine line) async {
    said.add(line.text);
    final held = _held;
    if (held != null) await held.future;
  }

  @override
  void playSfx(ShapesSfx sfx) => this.sfx.add(sfx);

  @override
  void stop() => stopCalls++;

  @override
  void dispose() => disposeCalled = true;
}
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/domain/shapes test/audio && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 8: Commit**

```bash
git add lib/domain/shapes/shape_phrases.dart lib/audio/shapes_voice.dart lib/audio/shapes_voice_player.dart test/support/fake_shapes_voice.dart test/domain/shapes/shape_phrases_test.dart test/audio/shapes_voice_player_test.dart
git commit -m "feat: the 27 phrases of «Фигурки» and the game's voice

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Recording tools and the recorded voice

**Files:**
- Create: `tool/src/shapes_parts.dart`, `tool/write_shapes_phrases_doc.dart`, `docs/shapes_phrases.md` (generated), `test/tool/shapes_parts_test.dart`, `test/tool/shapes_phrases_doc_test.dart`, `assets/audio/shapes/*.wav` (sliced)
- Modify: `tool/src/voiceover_queue.dart`, `tool/src/voiceover_tasks.dart`, `tool/record_voiceover.dart`, `tool/slice_voiceover.dart`, `test/tool/voiceover_tasks_test.dart` (count 186 → 213), `test/audio/shapes_voice_player_test.dart`, `pubspec.yaml`, `docs/superpowers/specs/2026-11-20-shapes-game-design.md` (§6.2: no stand-ins needed)

**Interfaces:**
- Consumes: `ShapePhrases.allClips`, `ShapePhrases.shape/picture`, `shapePictures`, `ShapeKind`.
- Produces: `class ShapesPart(int number, String title, List<VoiceClip> clips)` with `String get filter` (`shapes-<n>`); `List<ShapesPart> buildShapesParts()`; in `voiceover_queue.dart`: `const shapesFilter = 'shapes'`, `List<String> shapesFilters`, `bool isShapesFilter(String?)`, `bool isGamePhrasesFilter(String?)`, `double gamePhraseGapMsFor(String filter)`; in `voiceover_tasks.dart`: `const shapesVoiceoverDir = 'assets/audio/shapes/'`, `List<VoiceoverTask> buildShapesVoiceoverTasks()`; `String buildShapesPhrasesDoc()`.

- [ ] **Step 1: Write the failing tests**

`test/tool/shapes_parts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_phrases.dart';

import '../../tool/src/shapes_parts.dart';
import '../../tool/src/voiceover_queue.dart';
import '../../tool/src/voiceover_tasks.dart';

void main() {
  test('three parts of at most ten phrases cover every phrase once, in order', () {
    final parts = buildShapesParts();
    expect(parts.map((p) => p.filter), ['shapes-1', 'shapes-2', 'shapes-3']);
    expect(parts.map((p) => p.clips.length), [10, 10, 7]);
    expect([for (final p in parts) ...p.clips], ShapePhrases.allClips);
  });

  test('the "shapes" filters select only the shapes phrases', () {
    final all = buildVoiceoverTasks();
    List<String> texts(String filter) => [for (final t in all) if (taskMatchesFilter(t, filter)) t.text];
    expect(texts('shapes'), hasLength(27));
    expect(texts('shapes-1').first, 'Круг!');
    expect(texts('shapes-3').last, 'Ура! Ты знаешь все фигурки!');
    expect(texts('monsters'), isNot(contains('Круг!')));
    for (final filter in shapesFilters) {
      expect(isValidSceneFilter(filter), isTrue, reason: filter);
      expect(isGamePhrasesFilter(filter), isTrue, reason: filter);
    }
    expect(buildShapesVoiceoverTasks().first.outputPath, '${shapesVoiceoverDir}shape_circle.wav');
  });

  test('only the part with a two-sentence phrase needs the long gap', () {
    expect(gamePhraseGapMsFor('shapes-1'), monstersShortPhraseGapMs);
    expect(gamePhraseGapMsFor('shapes-2'), monstersShortPhraseGapMs);
    expect(gamePhraseGapMsFor('shapes-3'), monstersPhraseGapMs);
    expect(gamePhraseGapMsFor('monsters-1'), monstersPhraseGapMs);
  });
}
```

`test/tool/shapes_phrases_doc_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_phrases.dart';

import '../../tool/write_shapes_phrases_doc.dart';

void main() {
  test('docs/shapes_phrases.md matches the game\'s phrase list', () {
    expect(File('docs/shapes_phrases.md').readAsStringSync(), buildShapesPhrasesDoc(),
        reason: 'run: dart run tool/write_shapes_phrases_doc.dart');
  });

  test('the document lists every phrase with its file name and the slicing commands', () {
    final doc = buildShapesPhrasesDoc();
    for (final clip in ShapePhrases.allClips) {
      expect(doc, contains('| ${clip.text} | `${clip.id}.wav` |'));
    }
    for (var part = 1; part <= 3; part++) {
      expect(doc, contains('dart run tool/slice_voiceover.dart shapes-$part запись.wav'));
    }
  });
}
```

Append to `test/audio/shapes_voice_player_test.dart` (inside `main`):

```dart
  test('every phrase of the game is recorded', () {
    for (final clip in ShapePhrases.allClips) {
      final file = File('$shapesRecordedVoiceDir/${clip.id}.wav');
      expect(file.existsSync(), isTrue, reason: '${clip.text}: slice it with tool/slice_voiceover.dart');
      expect(file.lengthSync(), greaterThan(2000), reason: clip.text);
    }
  });

  test('the recordings folder is declared in pubspec.yaml', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('- $shapesRecordedVoiceDir/'));
  });
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/tool/shapes_parts_test.dart test/tool/shapes_phrases_doc_test.dart test/audio/shapes_voice_player_test.dart`
Expected: FAIL — `shapes_parts.dart` not found.

- [ ] **Step 3: Create `tool/src/shapes_parts.dart`**

```dart
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_phrases.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';

/// One sitting's worth of "Фигурки" phrases (at most ten), read in this
/// order into one recording and cut apart by
/// `tool/slice_voiceover.dart shapes-<number>`.
class ShapesPart {
  const ShapesPart(this.number, this.title, this.clips);

  final int number;
  final String title;
  final List<VoiceClip> clips;

  String get filter => 'shapes-$number';
}

List<ShapesPart> buildShapesParts() => [
      ShapesPart(1, 'Формы', [for (final kind in ShapeKind.values) ShapePhrases.shape(kind)]),
      ShapesPart(2, 'Картинки 1–10', [for (final picture in shapePictures.take(10)) ShapePhrases.picture(picture)]),
      ShapesPart(3, 'Последние картинки и общие фразы', [
        for (final picture in shapePictures.skip(10)) ShapePhrases.picture(picture),
        ShapePhrases.intro,
        ShapePhrases.newShape,
        ShapePhrases.notHere,
        ShapePhrases.hooray,
        ShapePhrases.win,
      ]),
    ];
```

- [ ] **Step 4: Extend `tool/src/voiceover_tasks.dart`**

Add `import 'shapes_parts.dart';` next to the monsters import. After `buildMonstersVoiceoverTasks` add:

```dart
/// Where the phrases of the "Фигурки" game are recorded to — the folder
/// `ShapesVoicePlayer` plays from.
const shapesVoiceoverDir = 'assets/audio/shapes/';

/// One task per phrase of the "Фигурки" game, in recording order.
List<VoiceoverTask> buildShapesVoiceoverTasks() => [
      for (final part in buildShapesParts())
        for (final clip in part.clips)
          VoiceoverTask(text: clip.text, outputPath: '$shapesVoiceoverDir${clip.id}.wav'),
    ];
```

In `buildVoiceoverTasks()` change `tasks.addAll(buildMonstersVoiceoverTasks());` to:

```dart
  tasks
    ..addAll(buildMonstersVoiceoverTasks())
    ..addAll(buildShapesVoiceoverTasks());
```

and update its doc comment's last line to «…then the phrases of the "Монстрики" and "Фигурки" games.» In `test/tool/voiceover_tasks_test.dart` change both `186` to `213`.

- [ ] **Step 5: Extend `tool/src/voiceover_queue.dart`**

Add `import 'shapes_parts.dart';`. After `isMonstersFilter` add:

```dart
/// The filter value that selects every phrase of the "Фигурки" game.
const shapesFilter = 'shapes';

final List<ShapesPart> _shapesParts = buildShapesParts();

/// Every filter value that selects "Фигурки" phrases: the whole set, then
/// each part (`shapes-1` … `shapes-3`).
final List<String> shapesFilters = [shapesFilter, for (final part in _shapesParts) part.filter];

/// True if [filter] is about the "Фигурки" game at all.
bool isShapesFilter(String? filter) => filter != null && shapesFilters.contains(filter);

/// True if [filter] selects the phrases of one of the games rather than a
/// scene's words — they are levelled and split like sentences.
bool isGamePhrasesFilter(String? filter) => isMonstersFilter(filter) || isShapesFilter(filter);

/// The silence that separates two phrases in a recording of the game part
/// [filter] selects (see [monstersPhraseGapMsFor]).
double gamePhraseGapMsFor(String filter) {
  if (isMonstersFilter(filter)) return monstersPhraseGapMsFor(filter);
  final clips = filter == shapesFilter
      ? _shapesParts.expand((part) => part.clips)
      : _shapesParts.firstWhere((part) => part.filter == filter).clips;
  return clips.any((clip) => _hasInnerPause(clip.text)) ? monstersPhraseGapMs : monstersShortPhraseGapMs;
}

bool _matchesShapesFilter(VoiceoverTask task, String filter) {
  if (!task.outputPath.startsWith(shapesVoiceoverDir)) return false;
  if (filter == shapesFilter) return true;
  final part = _shapesParts.firstWhere((part) => part.filter == filter);
  return part.clips.any((clip) => task.outputPath == '$shapesVoiceoverDir${clip.id}.wav');
}
```

In `taskMatchesFilter` add after the monsters line:

```dart
  if (isShapesFilter(sceneFilter)) return _matchesShapesFilter(task, sceneFilter);
```

In `isValidSceneFilter` change the condition to `filter == null || filter == 'system' || isGamePhrasesFilter(filter)`.

- [ ] **Step 6: Teach the two tools the new filters**

`tool/record_voiceover.dart`: in `validValues` use `[...scenes.map((s) => s.id), 'system', ...monstersFilters, ...shapesFilters]`; change the levelling condition to:

```dart
      if (task.outputPath.startsWith(monstersVoiceoverDir) || task.outputPath.startsWith(shapesVoiceoverDir)) {
```

`tool/slice_voiceover.dart`: same `validValues`; usage strings `<scene-id|system|monsters…|shapes…>`; in the doc comment mention «or one part of the "Фигурки" phrases (`shapes-1` … `shapes-3`, see docs/shapes_phrases.md)»; replace the two `isMonstersFilter(sceneFilter)` uses with `isGamePhrasesFilter(sceneFilter)` and `monstersPhraseGapMsFor(sceneFilter)` with `gamePhraseGapMsFor(sceneFilter)`.

- [ ] **Step 7: Create `tool/write_shapes_phrases_doc.dart`**

```dart
import 'dart:io';

import 'src/shapes_parts.dart';

/// Writes `docs/shapes_phrases.md` — every phrase of the "Фигурки" game to
/// record, part by part, with its file name — from the game's own phrase
/// list, so the document can't drift from the code.
///
/// Usage: `dart run tool/write_shapes_phrases_doc.dart`
void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запусти из корня репозитория.');
    exitCode = 1;
    return;
  }
  File('docs/shapes_phrases.md').writeAsStringSync(buildShapesPhrasesDoc());
  stdout.writeln('docs/shapes_phrases.md');
}

String buildShapesPhrasesDoc() {
  final parts = buildShapesParts();
  final total = parts.fold<int>(0, (sum, part) => sum + part.clips.length);
  final out = StringBuffer()
    ..writeln('# Игра «Фигурки» — фразы для записи')
    ..writeln()
    ..writeln('<!-- Этот файл создан командой `dart run tool/write_shapes_phrases_doc.dart`. '
        'Не правь его руками — правки пропадут при следующем запуске. -->')
    ..writeln()
    ..writeln('Всего **$total фраз** в **${parts.length} частях**. Одна часть — одна запись в Logic '
        'и одна команда. Записывают так же, как фразы «Монстриков» (`docs/monsters_phrases.md`): '
        'фразы подряд сверху вниз, между ними молчать около 2 секунд, Bounce в WAV, файл — в папку '
        '`tool`, затем команда части.')
    ..writeln()
    ..writeln('Длинные реплики игра собирает из целых фраз: «Новая фигурка!» + «Звезда!», '
        '«Домик!» + «Ура!». Поэтому каждое слово записывается один раз.')
    ..writeln()
    ..writeln('## Советы по интонации')
    ..writeln()
    ..writeln('- Названия форм — радостно и ясно, как будто показываешь игрушку: запись звучит и '
        'сама по себе, и после «Новая фигурка!».')
    ..writeln('- Названия картинок — с удивлением и восторгом: «смотри, что получилось!»; после '
        'них игра скажет «Ура!».')
    ..writeln('- «Не сюда!» — мягко, без упрёка: это подсказка, а не ошибка.')
    ..writeln();
  for (final part in parts) {
    out
      ..writeln('## Часть ${part.number}. ${part.title}')
      ..writeln()
      ..writeln('${part.clips.length} фраз. Команда после записи:')
      ..writeln()
      ..writeln('```bash')
      ..writeln('dart run tool/slice_voiceover.dart ${part.filter} запись.wav')
      ..writeln('```')
      ..writeln()
      ..writeln('| № | Что сказать | Файл |')
      ..writeln('|---|---|---|');
    for (var i = 0; i < part.clips.length; i++) {
      final clip = part.clips[i];
      out.writeln('| ${i + 1} | ${clip.text} | `${clip.id}.wav` |');
    }
    out.writeln();
  }
  return out.toString();
}
```

Run: `dart run tool/write_shapes_phrases_doc.dart`
Expected: prints `docs/shapes_phrases.md`.

- [ ] **Step 8: Slice the user's three takes**

```bash
dart run tool/slice_voiceover.dart shapes-1 "/Users/karina/flutter/yandee/tool/Untitled 1_1#04.wav"
dart run tool/slice_voiceover.dart shapes-2 "/Users/karina/flutter/yandee/tool/Untitled 1_1#05.wav"
dart run tool/slice_voiceover.dart shapes-3 "/Users/karina/flutter/yandee/tool/Untitled 1_1#06.wav"
```

Expected: each prints «Готово! Записано N слов» and lists 10, 10 and 7 files in `assets/audio/shapes/`. If a count mismatches, stop and report the chunk list to the user (do not edit the takes).

- [ ] **Step 9: Declare the assets and amend the spec**

In `pubspec.yaml` under `assets:` after `- assets/audio/monsters_tts/` add `- assets/audio/shapes/`. In the spec §6.2 replace the sentence about `assets/audio/shapes_tts/` with: «Все 27 фраз записаны сразу (три дубля из Logic), поэтому временного компьютерного голоса у «Фигурок» нет.»

- [ ] **Step 10: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 11: Commit**

```bash
git add tool test docs pubspec.yaml assets/audio/shapes
git commit -m "feat: the recording tools know «Фигурки»; all 27 phrases recorded in a live voice

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Geometry, art and motion (pure)

**Files:**
- Create: `lib/presentation/shapes/shape_geometry.dart`, `lib/presentation/shapes/shape_art.dart`, `lib/presentation/shapes/shape_motion.dart`, `test/presentation/shapes/shape_art_test.dart`, `test/presentation/shapes/shape_motion_test.dart`

**Interfaces:**
- Consumes: Task 2 types.
- Produces:
  - `String svgNumber(double)`; `String shapePathData(ShapeKind kind, double width, double height)`; `String slotTransform(ShapeSlot slot)`.
  - `const shapesInk = '#2b211a'`; `String mixHex(String a, String b, double t)`; `class Shades {fill, light, side, line}`, `Shades shadesOf(String fill)`; `enum EffectKind { puff, bubble, twinkle, glow, flame, risingHeart, zz, cherry, sparkle, speedLines }`; `class PictureEffect(EffectKind kind, double x, double y, {String color = '#fff7b0', double delay = 0, double size = 1})`; `class SlotArt(String color, {String details = ''})`; `class PictureArt({required List<SlotArt> slots, required String background, String backdrop = '', bool dark = false, List<PictureEffect> effects = const []})`; `PictureArt artOf(ShapePicture picture)`; `CardBox pieceFrame(ShapeSlot slot)`; `String slotLayerSvg(ShapePicture picture, int index, {required bool filled, bool highlighted = false})`; `String pieceSvg(ShapePicture picture, int index)`; `String backgroundSvg(ShapePicture picture)`; `String backdropSvg(ShapePicture picture)` (empty string when none); `String kindIconSvg(ShapeKind kind, {required bool met})`; `String backgroundAssetOf(ShapePicture picture)` → `'assets/shapes/backgrounds/<id>.jpg'`.
  - `Duration motionDuration(PictureMotion motion)`; `Matrix4 pictureMotion(PictureMotion motion, double t, ({double x, double y}) pivot)` (card units); `double pulseScale(double t)`.

- [ ] **Step 1: Write the failing tests**

`test/presentation/shapes/shape_art_test.dart`:

```dart
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';
import 'package:yandee/presentation/shapes/shape_art.dart';
import 'package:yandee/presentation/shapes/shape_geometry.dart';

Future<void> _parses(WidgetTester tester, String svg, String what) async {
  final info = await tester.runAsync(() => vg.loadPicture(SvgStringLoader(svg), null));
  expect(info, isNotNull, reason: what);
  info!.picture.dispose();
}

void main() {
  test('numbers in SVG are short', () {
    expect(svgNumber(2), '2');
    expect(svgNumber(10.5), '10.5');
    expect(svgNumber(-3.04), '-3');
  });

  test('every shape has a closed outline with no gaps in the numbers', () {
    for (final kind in ShapeKind.values) {
      final d = shapePathData(kind, 120, 90);
      expect(d, startsWith('M'), reason: kind.name);
      expect(d, endsWith('Z'), reason: kind.name);
      expect(d, isNot(contains('NaN')), reason: kind.name);
      expect(d, isNot(contains('Infinity')), reason: kind.name);
    }
  });

  test('every picture has art for each of its slots', () {
    for (final picture in shapePictures) {
      expect(artOf(picture).slots, hasLength(picture.slots.length), reason: picture.id);
    }
  });

  test('a piece on the mat is framed with room for its wooden edge', () {
    const slot = ShapeSlot(ShapeKind.square, CardBox(10, 20, 100, 100));
    final frame = pieceFrame(slot);
    expect((frame.x, frame.y, frame.width, frame.height), (2.0, 12.0, 116.0, 122.0));
  });

  test('colours mix', () {
    expect(mixHex('#000000', '#ffffff', .5), '#808080');
    expect(shadesOf('#e2553f').fill, '#e2553f');
  });

  testWidgets('every layer of every picture is SVG flutter_svg can draw', (tester) async {
    for (final picture in shapePictures) {
      await _parses(tester, backgroundSvg(picture), '${picture.id} background');
      final backdrop = backdropSvg(picture);
      if (backdrop.isNotEmpty) await _parses(tester, backdrop, '${picture.id} backdrop');
      for (var i = 0; i < picture.slots.length; i++) {
        await _parses(tester, slotLayerSvg(picture, i, filled: false), '${picture.id} outline $i');
        await _parses(tester, slotLayerSvg(picture, i, filled: false, highlighted: true), '${picture.id} hint $i');
        await _parses(tester, slotLayerSvg(picture, i, filled: true), '${picture.id} piece $i');
        await _parses(tester, pieceSvg(picture, i), '${picture.id} mat piece $i');
      }
    }
    for (final kind in ShapeKind.values) {
      await _parses(tester, kindIconSvg(kind, met: true), '${kind.name} icon');
      await _parses(tester, kindIconSvg(kind, met: false), '${kind.name} icon outline');
    }
  });
}
```

`test/presentation/shapes/shape_motion_test.dart`:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';
import 'package:yandee/presentation/shapes/shape_motion.dart';

void main() {
  const pivot = (x: 150.0, y: 280.0);
  Offset at(PictureMotion motion, double t, Offset point) =>
      MatrixUtils.transformPoint(pictureMotion(motion, t, pivot), point);

  test('every motion starts and ends where the picture stands', () {
    for (final motion in PictureMotion.values) {
      for (final t in [0.0, 1.0]) {
        final p = at(motion, t, const Offset(100, 100));
        expect(p.dx, closeTo(100, .01), reason: '$motion at $t');
        expect(p.dy, closeTo(100, .01), reason: '$motion at $t');
      }
      expect(motionDuration(motion), greaterThan(Duration.zero));
    }
  });

  test('a car drives off to the right before it comes back', () {
    expect(at(PictureMotion.drive, .4, const Offset(100, 100)).dx, greaterThan(300));
  });

  test('a rocket flies up', () {
    expect(at(PictureMotion.launch, .45, const Offset(100, 100)).dy, lessThan(-100));
  });

  test('turning motions keep the pivot still', () {
    for (final motion in [PictureMotion.wiggle, PictureMotion.rock, PictureMotion.sway]) {
      final p = at(motion, .1, Offset(pivot.x, pivot.y));
      expect(p.dx, closeTo(pivot.x, .01));
      expect(p.dy, closeTo(pivot.y, .01));
    }
  });

  test('pulsing stays between full size and a little bigger', () {
    for (var t = 0.0; t <= 1; t += .05) {
      expect(pulseScale(t), inInclusiveRange(1, 1.121));
    }
    expect(pulseScale(0), 1);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/presentation/shapes`
Expected: FAIL — files not found.

- [ ] **Step 3: Create `lib/presentation/shapes/shape_geometry.dart`**

```dart
import 'dart:math' as math;

import '../../domain/shapes/shape_kind.dart';
import '../../domain/shapes/shape_picture.dart';

/// A number written into SVG: at most one decimal, no trailing `.0`.
String svgNumber(double value) {
  final text = value.toStringAsFixed(1);
  if (text == '-0.0') return '0';
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

String _n(double value) => svgNumber(value);

(double, double) _toward((double, double) p, (double, double) q, double r) {
  final dx = q.$1 - p.$1, dy = q.$2 - p.$2;
  final length = math.sqrt(dx * dx + dy * dy);
  final k = math.min(r, length / 2.2) / length;
  return (p.$1 + dx * k, p.$2 + dy * k);
}

/// A polygon with softly rounded corners.
String _roundPolygon(List<(double, double)> points, double radius) {
  final out = StringBuffer();
  for (var i = 0; i < points.length; i++) {
    final previous = points[(i - 1 + points.length) % points.length];
    final corner = points[i];
    final next = points[(i + 1) % points.length];
    final a = _toward(corner, previous, radius), b = _toward(corner, next, radius);
    out.write('${i == 0 ? 'M' : 'L'}${_n(a.$1)} ${_n(a.$2)}'
        'Q${_n(corner.$1)} ${_n(corner.$2)} ${_n(b.$1)} ${_n(b.$2)}');
  }
  return '${out}Z';
}

/// The outline of [kind] filling a box of [width] × [height], upright: a
/// triangle points up, a semicircle sits on its flat side, a crescent opens
/// to the right. The same shapes as `shapePath` in the prototype.
String shapePathData(ShapeKind kind, double width, double height) {
  final w = width, h = height, m = math.min(w, h);
  String x(double v) => _n(v * w / 100);
  String y(double v) => _n(v * h / 100);
  switch (kind) {
    case ShapeKind.circle || ShapeKind.oval:
      return 'M0 ${_n(h / 2)}A${_n(w / 2)} ${_n(h / 2)} 0 1 1 ${_n(w)} ${_n(h / 2)}'
          'A${_n(w / 2)} ${_n(h / 2)} 0 1 1 0 ${_n(h / 2)}Z';
    case ShapeKind.square || ShapeKind.rectangle:
      return _roundPolygon([(0, 0), (w, 0), (w, h), (0, h)], m * .16);
    case ShapeKind.triangle:
      return _roundPolygon([(w / 2, 0), (w, h), (0, h)], m * .14);
    case ShapeKind.rhombus:
      return _roundPolygon([(w / 2, 0), (w, h / 2), (w / 2, h), (0, h / 2)], m * .12);
    case ShapeKind.star:
      return _roundPolygon([
        for (var i = 0; i < 10; i++)
          (
            (math.cos(-math.pi / 2 + i * math.pi / 5) * (i.isOdd ? .5 : 1) + .951) / 1.902 * w,
            (math.sin(-math.pi / 2 + i * math.pi / 5) * (i.isOdd ? .5 : 1) + 1) / 1.809 * h,
          ),
      ], m * .06);
    case ShapeKind.heart:
      return 'M${x(50)} ${y(97)}C${x(22)} ${y(77)} ${x(1)} ${y(58)} ${x(1)} ${y(33)}'
          'C${x(1)} ${y(14)} ${x(15)} ${y(2)} ${x(29)} ${y(2)}'
          'C${x(39)} ${y(2)} ${x(46)} ${y(8)} ${x(50)} ${y(17)}'
          'C${x(54)} ${y(8)} ${x(61)} ${y(2)} ${x(71)} ${y(2)}'
          'C${x(85)} ${y(2)} ${x(99)} ${y(14)} ${x(99)} ${y(33)}'
          'C${x(99)} ${y(58)} ${x(78)} ${y(77)} ${x(50)} ${y(97)}Z';
    case ShapeKind.semicircle:
      return 'M0 ${_n(h)}A${_n(w / 2)} ${_n(h)} 0 0 1 ${_n(w)} ${_n(h)}Z';
    case ShapeKind.crescent:
      return 'M${x(62)} ${y(3)}A${x(47)} ${y(47)} 0 1 0 ${x(62)} ${y(97)}'
          'A${x(52)} ${y(52)} 0 0 1 ${x(62)} ${y(3)}Z';
  }
}

/// Moves the upright shape (drawn from 0,0) into its slot, turned.
String slotTransform(ShapeSlot slot) {
  final up = slot.upright;
  final center = slot.box.center;
  return 'translate(${_n(center.x)} ${_n(center.y)}) rotate(${slot.quarterTurns * 90}) '
      'translate(${_n(-up.width / 2)} ${_n(-up.height / 2)})';
}
```

- [ ] **Step 4: Create `lib/presentation/shapes/shape_art.dart`**

```dart
import 'dart:math' as math;

import '../../domain/shapes/shape_kind.dart';
import '../../domain/shapes/shape_picture.dart';
import 'shape_geometry.dart';

/// The drawings of the "Фигурки" game, carried over from the prototype
/// (`docs/prototypes/shapes.html`) as SVG text in card units (300 × 300).
/// Pieces look like painted wooden toys: a darker edge underneath, light
/// from above, faint grain and a soft shine — the warm style of the scenes.

const shapesInk = '#2b211a';
const _hint = '#ffb21a';

String _n(double value) => svgNumber(value);

/// Blends two `#rrggbb` colours: t = 0 gives [a], t = 1 gives [b].
String mixHex(String a, String b, double t) {
  final pa = int.parse(a.substring(1), radix: 16), pb = int.parse(b.substring(1), radix: 16);
  String channel(int shift) {
    final value = (((pa >> shift) & 255) * (1 - t) + ((pb >> shift) & 255) * t).round();
    return value.toRadixString(16).padLeft(2, '0');
  }
  return '#${channel(16)}${channel(8)}${channel(0)}';
}

/// The tones a painted wooden piece is drawn with.
class Shades {
  const Shades(this.fill, this.light, this.side, this.line);
  final String fill;
  final String light;
  final String side;
  final String line;
}

Shades shadesOf(String fill) => Shades(
      fill,
      mixHex(fill, '#fff8ec', .38),
      mixHex(fill, '#3b2410', .32),
      mixHex(fill, '#3b2410', .62),
    );

/// Toy paint, warm like the scenes.
abstract final class ToyColors {
  static const red = '#e2553f';
  static const blue = '#3f8fd8';
  static const yellow = '#f6c447';
  static const green = '#5daa4f';
  static const darkGreen = '#3f8a45';
  static const orange = '#f08a3a';
  static const purple = '#9a6cc9';
  static const pink = '#ef8fb0';
  static const brown = '#a8703f';
  static const lightBlue = '#7cc6e8';
  static const white = '#f7f1e6';
  static const black = '#4a4038';
  static const cone = '#e0b06a';
  static const skin = '#f8d9b8';
  static const silver = '#ebe5da';
}

/// Small moving things that appear when a picture comes alive.
enum EffectKind { puff, bubble, twinkle, glow, flame, risingHeart, zz, cherry, sparkle, speedLines }

class PictureEffect {
  const PictureEffect(this.kind, this.x, this.y, {this.color = '#fff7b0', this.delay = 0, this.size = 1});
  final EffectKind kind;
  final double x;
  final double y;
  final String color;

  /// Seconds after the picture comes alive before this one starts.
  final double delay;
  final double size;
}

/// How one slot is painted: its toy colour and the details drawn on it once
/// the piece is in (a face, a window, wheel hubs).
class SlotArt {
  const SlotArt(this.color, {this.details = ''});
  final String color;
  final String details;
}

class PictureArt {
  const PictureArt({
    required this.slots,
    required this.background,
    this.backdrop = '',
    this.dark = false,
    this.effects = const [],
  });

  final List<SlotArt> slots;

  /// The stand-in background, drawn until a painted one is in
  /// `assets/shapes/backgrounds/`.
  final String background;

  /// Things that belong to the scene but move with the picture (the bear's
  /// ears, the mast, the kite's string) — over any background, under the
  /// pieces.
  final String backdrop;

  /// Dashed outlines are drawn light on this (night) background.
  final bool dark;

  final List<PictureEffect> effects;
}

// ------------------------------------------------------------- helpers

String _grad(String id, String top, String bottom) =>
    '<linearGradient id="$id" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="$top"/>'
    '<stop offset="1" stop-color="$bottom"/></linearGradient>';
String _sky(String top, String bottom) =>
    '<defs>${_grad('sky', top, bottom)}</defs><rect width="300" height="300" fill="url(#sky)"/>';
String _land(String id, String d, String top, String bottom) =>
    '<defs>${_grad(id, top, bottom)}</defs><path d="$d" fill="url(#$id)"/>';
String _sun(double x, double y, double r) =>
    '<defs><radialGradient id="sun"><stop offset="0" stop-color="#fffbe8"/><stop offset=".3" stop-color="#ffe7a6"/>'
    '<stop offset="1" stop-color="#ffe39a" stop-opacity="0"/></radialGradient></defs>'
    '<circle cx="${_n(x)}" cy="${_n(y)}" r="${_n(r)}" fill="url(#sun)"/>';
String _cloud(double x, double y, [double s = 1]) =>
    '<ellipse cx="${_n(x)}" cy="${_n(y + 4 * s)}" rx="${_n(30 * s)}" ry="${_n(10 * s)}" fill="#e8d9c6" opacity=".55"/>'
    '<g fill="#fffaf2"><ellipse cx="${_n(x)}" cy="${_n(y)}" rx="${_n(28 * s)}" ry="${_n(13 * s)}"/>'
    '<circle cx="${_n(x - 10 * s)}" cy="${_n(y - 8 * s)}" r="${_n(13 * s)}"/>'
    '<circle cx="${_n(x + 9 * s)}" cy="${_n(y - 11 * s)}" r="${_n(16 * s)}"/></g>';
String _bush(double x, double y, [double s = 1]) =>
    '<g stroke="#4e8a3c" stroke-width="2.5"><circle cx="${_n(x)}" cy="${_n(y)}" r="${_n(18 * s)}" fill="#6fae52"/>'
    '<circle cx="${_n(x + 18 * s)}" cy="${_n(y + 5 * s)}" r="${_n(13 * s)}" fill="#5f9f48"/></g>';
String _meadow(double y) =>
    _land('far', 'M0 236 Q70 212 150 232 T300 226 V300 H0Z', '#b9d991', '#9cc67a') +
    _land('near', 'M0 ${_n(y)} Q80 ${_n(y - 12)} 150 ${_n(y)} T300 ${_n(y - 4)} V300 H0Z', '#93c46a', '#6fa84f');
String _dots(List<(double, double, double)> dots, [String color = '#fffaf2']) =>
    '<g fill="$color">${dots.map((d) => '<circle cx="${_n(d.$1)}" cy="${_n(d.$2)}" r="${_n(d.$3)}"/>').join()}</g>';
String _eyes(double x1, double x2, double y, {double r = 7, String color = shapesInk}) =>
    '<circle cx="${_n(x1)}" cy="${_n(y)}" r="${_n(r)}" fill="$color"/><circle cx="${_n(x2)}" cy="${_n(y)}" r="${_n(r)}" fill="$color"/>'
    '<circle cx="${_n(x1 + r * .35)}" cy="${_n(y - r * .4)}" r="${_n(r * .32)}" fill="#fff"/>'
    '<circle cx="${_n(x2 + r * .35)}" cy="${_n(y - r * .4)}" r="${_n(r * .32)}" fill="#fff"/>';
String _smile(double x1, double x2, double y, double depth, {String color = shapesInk, double width = 4}) =>
    '<path d="M${_n(x1)} ${_n(y)} Q${_n((x1 + x2) / 2)} ${_n(y + depth)} ${_n(x2)} ${_n(y)}" '
    'stroke="$color" stroke-width="${_n(width)}" fill="none" stroke-linecap="round"/>';
String _starFace(CardBox b) {
  final cx = b.x + b.width / 2, cy = b.y + b.height * .58, k = b.width / 76;
  return _eyes(cx - 9 * k, cx + 9 * k, cy - 3 * k, r: 3.6 * k, color: '#7a5200') +
      _smile(cx - 6 * k, cx + 6 * k, cy + 6 * k, 6 * k, color: '#7a5200', width: 3);
}

// ------------------------------------------------------------- pictures

final Map<String, PictureArt> _art = {
  'ice_cream': PictureArt(
    background: _sky('#fff4e8', '#ffe3cf') +
        [for (var i = 0; i < 10; i++) '<rect x="${i * 30}" width="30" height="30" fill="${i.isOdd ? '#fff8f0' : '#f4a7a0'}"/><circle cx="${i * 30 + 15}" cy="30" r="15" fill="${i.isOdd ? '#fff8f0' : '#f4a7a0'}"/>'].join() +
        _land('table', 'M0 252 H300 V300 H0Z', '#d9a066', '#b97f48') +
        '<path d="M0 252 H300" stroke="#9a6234" stroke-width="3"/>' +
        _dots(const [(40, 90, 5), (262, 110, 4), (34, 200, 4), (266, 210, 5), (56, 140, 3), (246, 160, 3)], '#f6c8c0'),
    slots: [
      const SlotArt(ToyColors.cone,
          details: '<path d="M116 152 L150 224 M138 152 L160 198 M162 152 L140 198 M184 152 L150 224" '
              'stroke="#b27f32" stroke-width="3" opacity=".55" stroke-linecap="round" fill="none"/>'),
      SlotArt(ToyColors.pink,
          details: _eyes(132, 168, 110) +
              _smile(136, 164, 130, 12) +
              '<circle cx="118" cy="128" r="8" fill="#ff4f8f" opacity=".3"/><circle cx="182" cy="128" r="8" fill="#ff4f8f" opacity=".3"/>'
                  '<g stroke-linecap="round" stroke-width="5"><path d="M116 76 l9 -4" stroke="#ffc929"/><path d="M150 64 l2 9" stroke="#6fd0f6"/>'
                  '<path d="M180 78 l8 4" stroke="#36b95a"/><path d="M102 98 l6 6" stroke="#9b5de5"/><path d="M198 100 l-5 7" stroke="#fff"/></g>'),
    ],
    effects: const [PictureEffect(EffectKind.cherry, 150, 52)],
  ),
  'house': PictureArt(
    background: _sky('#cfe6f5', '#fdf3e3') + _sun(252, 48, 56) + _cloud(64, 64) + _cloud(190, 34, .7) + _meadow(262) + _bush(18, 262) + _bush(262, 262, .9),
    backdrop: '<rect x="186" y="48" width="28" height="62" rx="3" fill="#c66a4a" stroke="#7d3c25" stroke-width="3"/>',
    slots: const [
      SlotArt(ToyColors.yellow,
          details: '<rect x="168" y="212" width="42" height="73" rx="8" fill="#a86d3e" stroke="#6b3f1d" stroke-width="3"/>'
              '<circle cx="200" cy="250" r="4.5" fill="#ffc929"/>'),
      SlotArt(ToyColors.red),
      SlotArt(ToyColors.lightBlue, details: '<path d="M126 167 V221 M99 194 H153" stroke="#fff" stroke-width="5" stroke-linecap="round"/>'),
    ],
    effects: const [
      PictureEffect(EffectKind.puff, 200, 42),
      PictureEffect(EffectKind.puff, 200, 42, delay: .5),
      PictureEffect(EffectKind.puff, 200, 42, delay: 1.05),
      PictureEffect(EffectKind.glow, 126, 194),
    ],
  ),
  'car': PictureArt(
    background: _sky('#cfe6f5', '#fdf3e3') + _cloud(70, 55) + _cloud(232, 84, .7) +
        '<g opacity=".55"><rect x="14" y="150" width="34" height="80" fill="#e6c9a8"/><rect x="52" y="176" width="28" height="54" fill="#f0d6b8"/>'
            '<rect x="228" y="160" width="30" height="70" fill="#e6c9a8"/><rect x="262" y="184" width="30" height="46" fill="#f0d6b8"/></g>' +
        _land('grass', 'M0 226 H300 V240 H0Z', '#93c46a', '#7fb35c') +
        _land('road', 'M0 238 H300 V300 H0Z', '#a69a90', '#8c8178') +
        '<path d="M10 272 H50 M90 272 H130 M170 272 H210 M250 272 H290" stroke="#fff8f0" stroke-width="6" stroke-linecap="round"/>',
    slots: [
      SlotArt(ToyColors.red,
          details: '<rect x="98" y="80" width="46" height="50" rx="10" fill="#b8ecff" stroke="#b8301f" stroke-width="3"/>'
                  '<rect x="156" y="80" width="52" height="50" rx="10" fill="#b8ecff" stroke="#b8301f" stroke-width="3"/>' +
              _eyes(172, 194, 106, r: 6) +
              _smile(170, 204, 168, 12, color: '#7a1d12') +
              '<circle cx="212" cy="148" r="8" fill="#ffe27a" stroke="#d99a00" stroke-width="3"/>'),
      const SlotArt(ToyColors.black, details: '<circle cx="103" cy="213" r="13" fill="#c9d1dc"/>'),
      const SlotArt(ToyColors.black, details: '<circle cx="203" cy="213" r="13" fill="#c9d1dc"/>'),
    ],
    effects: const [PictureEffect(EffectKind.speedLines, 50, 140)],
  ),
  'tree': PictureArt(
    background: _sky('#d8e8f3', '#f8f1e8') +
        _land('far', 'M0 236 Q90 214 170 234 T300 228 V300 H0Z', '#f4f7fa', '#e2e9f0') +
        _land('near', 'M0 254 Q150 236 300 254 V300 H0Z', '#ffffff', '#eef2f6') +
        _dots(const [(30, 40, 4), (270, 60, 5), (40, 180, 3), (262, 170, 4), (60, 110, 3), (240, 120, 3), (24, 226, 3), (282, 212, 3)]),
    slots: const [SlotArt(ToyColors.brown), SlotArt(ToyColors.darkGreen), SlotArt(ToyColors.green)],
    effects: const [
      PictureEffect(EffectKind.twinkle, 118, 182, color: '#ffc929'),
      PictureEffect(EffectKind.twinkle, 178, 168, color: '#ec4a3a', delay: .15),
      PictureEffect(EffectKind.twinkle, 150, 210, color: '#6fd0f6', delay: .3),
      PictureEffect(EffectKind.twinkle, 206, 214, color: '#ff7eb6', delay: .45),
      PictureEffect(EffectKind.twinkle, 96, 220, color: '#ffc929'),
      PictureEffect(EffectKind.twinkle, 150, 74, color: '#ec4a3a', delay: .15),
      PictureEffect(EffectKind.twinkle, 128, 104, color: '#6fd0f6', delay: .3),
      PictureEffect(EffectKind.twinkle, 174, 104, color: '#ffc929', delay: .45),
    ],
  ),
  'train': PictureArt(
    background: _sky('#cfe6f5', '#fdf3e3') + _sun(52, 46, 50) + _cloud(236, 50, .9) +
        _land('far', 'M0 230 Q80 206 160 228 T300 222 V300 H0Z', '#b9d991', '#9cc67a') +
        _land('near', 'M0 248 H300 V300 H0Z', '#93c46a', '#6fa84f') +
        '<g fill="#9a6234">${[for (var i = 0; i < 8; i++) '<rect x="${6 + i * 38}" y="252" width="22" height="12" rx="3"/>'].join()}</g>'
            '<rect y="250" width="300" height="6" fill="#8f8a86"/>',
    slots: [
      const SlotArt(ToyColors.red,
          details: '<path d="M46 140 V104 H38 V92 H78 V104 H70 V140" fill="#3a3a46" stroke="#16161d" stroke-width="3" stroke-linejoin="round"/>'
              '<path d="M110 141 V209" stroke="#b8301f" stroke-width="4"/>'
              '<circle cx="36" cy="160" r="7" fill="#ffe27a" stroke="#d99a00" stroke-width="3"/>'),
      SlotArt(ToyColors.blue,
          details: '<rect x="164" y="80" width="130" height="16" rx="7" fill="#1b55b5"/>'
                  '<rect x="196" y="110" width="68" height="48" rx="10" fill="#b8ecff" stroke="#1b55b5" stroke-width="3"/>' +
              _eyes(220, 242, 134, r: 6)),
      const SlotArt(ToyColors.black, details: '<circle cx="79" cy="217" r="12" fill="#c9d1dc"/>'),
      const SlotArt(ToyColors.black, details: '<circle cx="229" cy="217" r="12" fill="#c9d1dc"/>'),
    ],
    effects: const [
      PictureEffect(EffectKind.puff, 58, 86),
      PictureEffect(EffectKind.puff, 58, 86, delay: .5),
      PictureEffect(EffectKind.puff, 58, 86, delay: 1.05),
    ],
  ),
  'fish': PictureArt(
    background: _sky('#a7dcef', '#5fb0d4') +
        '<g fill="#fffaf2" opacity=".18"><path d="M40 0 L80 0 L30 300 L-10 300Z"/><path d="M170 0 L200 0 L170 300 L130 300Z"/></g>' +
        _land('sand', 'M0 268 Q150 250 300 268 V300 H0Z', '#f3dcae', '#e2c08a') +
        '<path d="M40 272 Q26 242 42 216 Q56 192 40 168" stroke="#5a9e48" stroke-width="10" fill="none" stroke-linecap="round"/>'
            '<path d="M262 274 Q276 248 260 222" stroke="#467f3a" stroke-width="10" fill="none" stroke-linecap="round"/>'
            '<g fill="#d9b98a"><ellipse cx="200" cy="276" rx="12" ry="6"/><ellipse cx="96" cy="282" rx="9" ry="5"/></g>'
            '<g fill="none" stroke="#fffaf2" stroke-width="3" opacity=".8"><circle cx="70" cy="60" r="8"/><circle cx="88" cy="36" r="5"/><circle cx="250" cy="70" r="6"/></g>',
    slots: [
      const SlotArt(ToyColors.yellow),
      SlotArt(ToyColors.orange,
          details: '<path d="M124 86 Q150 54 182 84" fill="#ffc929" stroke="#d99a00" stroke-width="3"/>'
                  '<path d="M118 122 q10 10 0 20 M138 114 q12 14 0 28 M138 152 q10 8 0 16" stroke="#c95f00" stroke-width="3" fill="none" opacity=".6"/>' +
              _smile(212, 230, 162, 8, color: '#7a3300')),
      const SlotArt(ToyColors.white, details: '<circle cx="197" cy="127" r="12" fill="$shapesInk"/><circle cx="201" cy="122" r="4" fill="#fff"/>'),
    ],
    effects: const [
      PictureEffect(EffectKind.bubble, 244, 140),
      PictureEffect(EffectKind.bubble, 244, 140, delay: .6, size: .8),
      PictureEffect(EffectKind.bubble, 244, 140, delay: 1.2, size: .65),
    ],
  ),
  'rocket': PictureArt(
    dark: true,
    background: _sky('#2a2f5c', '#4a3d70') +
        _dots(const [(30, 40, 2.5), (80, 20, 2), (60, 110, 2), (250, 140, 2.5), (280, 30, 2), (24, 190, 2), (270, 230, 2.5), (180, 270, 2), (100, 280, 2)], '#fff3c4') +
        _land('planet', 'M24 244 A24 24 0 1 0 72 244 A24 24 0 1 0 24 244Z', '#f6a85a', '#d0703a') +
        '<ellipse cx="48" cy="244" rx="40" ry="8" fill="none" stroke="#f6c447" stroke-width="5" transform="rotate(-18 48 244)"/>',
    slots: [
      const SlotArt(ToyColors.silver,
          details: '<path d="M106 196 L74 258 L106 248Z M194 196 L226 258 L194 248Z" fill="#ec4a3a" stroke="#b8301f" stroke-width="3" stroke-linejoin="round"/>'
              '<rect x="107" y="222" width="86" height="10" fill="#2f7cf0" opacity=".7"/>'),
      const SlotArt(ToyColors.red),
      const SlotArt(ToyColors.lightBlue, details: '<circle cx="150" cy="151" r="28" fill="none" stroke="#8e98a4" stroke-width="5"/>'),
      SlotArt(ToyColors.yellow, details: _starFace(const CardBox(204, 34, 78, 74))),
    ],
    effects: const [
      PictureEffect(EffectKind.flame, 150, 258),
      PictureEffect(EffectKind.sparkle, 198, 30),
      PictureEffect(EffectKind.sparkle, 286, 104, delay: .25),
    ],
  ),
  'bear': PictureArt(
    background: _sky('#d6ebf3', '#fbf3e2') + _sun(256, 44, 50) + _meadow(262) +
        [for (final (x, y, c) in const [(38.0, 270.0, '#ef8fb0'), (262.0, 272.0, '#f6c447'), (70.0, 286.0, '#9a6cc9'), (232.0, 288.0, '#ef8fb0')])
          '<circle cx="${_n(x)}" cy="${_n(y)}" r="7" fill="$c"/><circle cx="${_n(x)}" cy="${_n(y)}" r="3" fill="#fffaf2"/>'].join(),
    backdrop: '<g stroke="#5e3a1c" stroke-width="3.5"><circle cx="106" cy="62" r="22" fill="#a8703f"/><circle cx="194" cy="62" r="22" fill="#a8703f"/>'
        '<ellipse cx="120" cy="284" rx="22" ry="12" fill="#a8703f"/><ellipse cx="180" cy="284" rx="22" ry="12" fill="#a8703f"/></g>'
        '<circle cx="106" cy="62" r="10" fill="#e8b48a"/><circle cx="194" cy="62" r="10" fill="#e8b48a"/>',
    slots: [
      const SlotArt(ToyColors.brown,
          details: '<ellipse cx="150" cy="228" rx="40" ry="44" fill="#e8b48a" opacity=".75"/>'
              '<g fill="#a86d3e" stroke="#6b3f1d" stroke-width="4"><ellipse cx="92" cy="196" rx="15" ry="30" transform="rotate(28 92 196)"/>'
              '<ellipse cx="208" cy="196" rx="15" ry="30" transform="rotate(-28 208 196)"/></g>'),
      SlotArt(ToyColors.brown,
          details: '<ellipse cx="150" cy="124" rx="28" ry="22" fill="#e8b48a"/><ellipse cx="150" cy="113" rx="10" ry="7" fill="#3a2a2a"/>'
                  '<path d="M150 120 V128 M139 130 Q150 139 161 130" stroke="#3a2a2a" stroke-width="3.5" fill="none" stroke-linecap="round"/>' +
              _eyes(126, 174, 92, color: '#3a2a2a')),
      const SlotArt(ToyColors.red),
    ],
    effects: const [
      PictureEffect(EffectKind.risingHeart, 226, 96, color: '#ef8fb0'),
      PictureEffect(EffectKind.risingHeart, 72, 120, color: '#ef8fb0', delay: .7),
      PictureEffect(EffectKind.risingHeart, 238, 170, color: '#ef8fb0', delay: 1.4),
    ],
  ),
  'boat': PictureArt(
    background: _sky('#cfe6f5', '#fdf3e3') + _sun(250, 52, 52) + _cloud(62, 50, .9) +
        '<path d="M196 92 q10 -10 20 0 q10 -10 20 0" stroke="#76675a" stroke-width="4" fill="none" stroke-linecap="round"/>' +
        _land('sea', 'M0 238 Q25 228 50 238 T100 238 T150 238 T200 238 T250 238 T300 238 V300 H0Z', '#6dbbe0', '#3f8fbf') +
        '<path d="M0 266 Q25 258 50 266 T100 266 T150 266 T200 266 T250 266 T300 266" stroke="#a7dcef" stroke-width="5" fill="none"/>',
    backdrop: '<rect x="147" y="30" width="8" height="152" rx="3" fill="#8a5a33"/><path d="M155 32 L184 41 L155 50Z" fill="#e2553f"/>',
    slots: const [
      SlotArt(ToyColors.yellow),
      SlotArt(ToyColors.orange),
      SlotArt(ToyColors.red,
          details: '<g fill="#fff" stroke="#b8301f" stroke-width="3"><circle cx="105" cy="200" r="8"/><circle cx="150" cy="204" r="8"/><circle cx="195" cy="200" r="8"/></g>'),
    ],
  ),
  'kite': PictureArt(
    background: _sky('#bfe0f4', '#fdf1df') + _cloud(58, 70) + _cloud(246, 126, .8) + _meadow(272),
    backdrop: '<path d="M150 203 C150 230 110 250 40 275" stroke="#76675a" stroke-width="3" fill="none"/>',
    slots: [
      SlotArt(ToyColors.purple,
          details: '<path d="M150 28 V198 M86 113 H214" stroke="#6c35b0" stroke-width="3" opacity=".5"/>'
                  '<circle cx="134" cy="98" r="9" fill="#fff"/><circle cx="166" cy="98" r="9" fill="#fff"/>'
                  '<circle cx="135" cy="100" r="4.5" fill="$shapesInk"/><circle cx="167" cy="100" r="4.5" fill="$shapesInk"/>' +
              _smile(136, 164, 126, 12, color: '#fff')),
      const SlotArt(ToyColors.yellow),
      const SlotArt(ToyColors.green),
    ],
  ),
  'night_sky': PictureArt(
    dark: true,
    background: _sky('#232a55', '#3e3a6b') +
        _dots(const [(30, 200, 2), (120, 20, 2), (150, 140, 2), (280, 140, 2.5), (20, 30, 2), (110, 210, 2)], '#fff3c4') +
        _land('hills', 'M0 250 Q80 216 160 248 T300 240 V300 H0Z', '#34507a', '#26405e') +
        '<path d="M226 236 L250 216 L274 236Z" fill="#3a3340"/><rect x="230" y="234" width="40" height="30" fill="#3a3340"/>'
            '<rect x="244" y="241" width="12" height="12" fill="#ffe39a"/>',
    slots: [
      const SlotArt(ToyColors.yellow,
          details: '<path d="M58 94 Q66 101 76 94" stroke="#7a5200" stroke-width="4" fill="none" stroke-linecap="round"/>'
              '<path d="M64 124 Q72 130 80 122" stroke="#7a5200" stroke-width="4" fill="none" stroke-linecap="round"/>'
              '<circle cx="60" cy="110" r="6" fill="#ff7eb6" opacity=".5"/>'),
      SlotArt(ToyColors.yellow, details: _starFace(const CardBox(196, 40, 80, 76))),
      SlotArt(ToyColors.yellow, details: _starFace(const CardBox(170, 150, 66, 63))),
    ],
    effects: const [
      PictureEffect(EffectKind.zz, 104, 64),
      PictureEffect(EffectKind.zz, 118, 44, delay: .8, size: .7),
      PictureEffect(EffectKind.sparkle, 60, 230, delay: .1),
      PictureEffect(EffectKind.sparkle, 130, 180, delay: .35),
    ],
  ),
  'clown': PictureArt(
    background: _sky('#fff3e0', '#ffe6cd') +
        '<g fill="#f6d2c4" opacity=".7">${[for (var i = 0; i < 5; i++) '<rect x="${i * 60}" width="30" height="300"/>'].join()}</g>' +
        _land('floor', 'M0 262 H300 V300 H0Z', '#d9a066', '#b97f48'),
    backdrop: '<g fill="#f08a3a" stroke="#9a4f1c" stroke-width="3"><circle cx="72" cy="150" r="22"/><circle cx="62" cy="180" r="20"/>'
        '<circle cx="228" cy="150" r="22"/><circle cx="238" cy="180" r="20"/></g>'
        '<g fill="#7cc6e8" stroke="#3f7f9e" stroke-width="3"><circle cx="105" cy="272" r="18"/><circle cx="195" cy="272" r="18"/>'
        '<circle cx="135" cy="280" r="18"/><circle cx="165" cy="280" r="18"/></g>',
    slots: [
      SlotArt(ToyColors.skin,
          details: '<g fill="$shapesInk"><ellipse cx="124" cy="146" rx="7" ry="10"/><ellipse cx="176" cy="146" rx="7" ry="10"/></g>'
                  '<path d="M112 126 Q124 118 136 126 M164 126 Q176 118 188 126" stroke="$shapesInk" stroke-width="4" fill="none" stroke-linecap="round"/>' +
              _smile(118, 182, 222, 28, color: '#b8301f', width: 7)),
      const SlotArt(ToyColors.purple,
          details: '<g fill="#ffc929"><circle cx="138" cy="72" r="6"/><circle cx="164" cy="86" r="6"/><circle cx="152" cy="46" r="5"/></g>'
              '<circle cx="150" cy="10" r="11" fill="#fff" stroke="#8e98a4" stroke-width="3"/>'),
      const SlotArt(ToyColors.red),
      const SlotArt(ToyColors.pink),
      const SlotArt(ToyColors.pink),
    ],
  ),
};

PictureArt artOf(ShapePicture picture) => _art[picture.id]!;

// ------------------------------------------------------------- layers

const _svgOpen = '<svg xmlns="http://www.w3.org/2000/svg"';

// Where the shine sits on each upright shape, as a fraction of its box.
const Map<ShapeKind, (double, double)> _shine = {
  ShapeKind.circle: (.32, .3),
  ShapeKind.oval: (.3, .3),
  ShapeKind.square: (.26, .24),
  ShapeKind.rectangle: (.18, .3),
  ShapeKind.triangle: (.43, .58),
  ShapeKind.star: (.42, .44),
  ShapeKind.heart: (.27, .3),
  ShapeKind.semicircle: (.3, .62),
  ShapeKind.rhombus: (.4, .34),
  ShapeKind.crescent: (.2, .42),
};

/// A painted wooden piece in its slot.
String _pieceArt(ShapeSlot slot, String color) {
  final up = slot.upright;
  final w = up.width, h = up.height;
  final k = shadesOf(color);
  final d = shapePathData(slot.kind, w, h);
  final depth = math.max(4.0, math.min(w, h) * .06);
  final (sx, sy) = _shine[slot.kind]!;
  final grain = [
    for (final (i, t) in const [.28, .52, .76].indexed)
      'M${_n(-w * .05)} ${_n(h * t)}Q${_n(w * .3)} ${_n(h * t - 7 + i * 4)} ${_n(w * .55)} ${_n(h * t)}'
          'T${_n(w * 1.05)} ${_n(h * t + 2)}',
  ].join();
  final place = slotTransform(slot);
  return '<defs><linearGradient id="wood" x1="0" y1="0" x2="0" y2="1" gradientTransform="rotate(${-slot.quarterTurns * 90} .5 .5)">'
      '<stop offset="0" stop-color="${k.light}"/><stop offset=".55" stop-color="${k.fill}"/>'
      '<stop offset="1" stop-color="${mixHex(k.fill, k.side, .45)}"/></linearGradient>'
      '<radialGradient id="shine"><stop offset="0" stop-color="#fffdf6" stop-opacity=".8"/>'
      '<stop offset="1" stop-color="#fffdf6" stop-opacity="0"/></radialGradient>'
      '<clipPath id="cut"><path d="$d"/></clipPath></defs>'
      '<g transform="translate(0 ${_n(depth)})"><g transform="$place">'
      '<path d="$d" fill="${k.side}" stroke="${k.line}" stroke-width="3.5" stroke-linejoin="round"/></g></g>'
      '<g transform="$place"><path d="$d" fill="url(#wood)" stroke="${k.line}" stroke-width="3.5" stroke-linejoin="round"/>'
      '<g clip-path="url(#cut)"><path d="$grain" fill="none" stroke="${k.side}" stroke-width="1.6" opacity=".2"/>'
      '<ellipse cx="${_n(sx * w)}" cy="${_n(sy * h)}" rx="${_n(math.max(9, .24 * w))}" ry="${_n(math.max(6, .15 * h))}" fill="url(#shine)"/>'
      '</g></g>';
}

String _outlineArt(ShapeSlot slot, {required bool dark, required bool highlighted}) {
  final up = slot.upright;
  final String paint;
  if (highlighted) {
    paint = 'fill="rgba(255,248,236,.7)" stroke="$_hint" stroke-width="6"';
  } else if (dark) {
    paint = 'fill="#fff8ec" fill-opacity=".16" stroke="#fff3d6" stroke-opacity=".85" stroke-width="3" stroke-dasharray="9 7"';
  } else {
    paint = 'fill="#fff8f0" fill-opacity=".62" stroke="#a2896f" stroke-width="3" stroke-dasharray="9 7"';
  }
  return '<g transform="${slotTransform(slot)}"><path d="${shapePathData(slot.kind, up.width, up.height)}" $paint stroke-linejoin="round"/></g>';
}

/// The box a piece is drawn in on its own: the slot, a little margin and
/// room for its wooden edge underneath.
CardBox pieceFrame(ShapeSlot slot) =>
    CardBox(slot.box.x - 8, slot.box.y - 8, slot.box.width + 16, slot.box.height + 22);

/// One slot of [picture], as a full-card layer: the dashed place (lit up
/// when [highlighted]) or, once [filled], the piece and its details.
String slotLayerSvg(ShapePicture picture, int index, {required bool filled, bool highlighted = false}) {
  final slot = picture.slots[index];
  final art = artOf(picture);
  final body = filled
      ? _pieceArt(slot, art.slots[index].color) + art.slots[index].details
      : _outlineArt(slot, dark: art.dark, highlighted: highlighted);
  return '$_svgOpen viewBox="0 0 300 300">$body</svg>';
}

/// The piece for slot [index] on its own, framed by [pieceFrame] — for the
/// mat and for flight.
String pieceSvg(ShapePicture picture, int index) {
  final slot = picture.slots[index];
  final f = pieceFrame(slot);
  return '$_svgOpen viewBox="${_n(f.x)} ${_n(f.y)} ${_n(f.width)} ${_n(f.height)}">'
      '${_pieceArt(slot, artOf(picture).slots[index].color)}</svg>';
}

/// The stand-in background of [picture].
String backgroundSvg(ShapePicture picture) => '$_svgOpen viewBox="0 0 300 300">${artOf(picture).background}</svg>';

/// The scene bits that move with [picture], or an empty string.
String backdropSvg(ShapePicture picture) {
  final backdrop = artOf(picture).backdrop;
  return backdrop.isEmpty ? '' : '$_svgOpen viewBox="0 0 300 300">$backdrop</svg>';
}

/// Where a painted background for [picture] goes.
String backgroundAssetOf(ShapePicture picture) => 'assets/shapes/backgrounds/${picture.id}.jpg';

const Map<ShapeKind, (double, double, String)> _icons = {
  ShapeKind.circle: (22, 22, ToyColors.red),
  ShapeKind.triangle: (24, 21, ToyColors.yellow),
  ShapeKind.square: (20, 20, ToyColors.blue),
  ShapeKind.rectangle: (26, 15, ToyColors.green),
  ShapeKind.oval: (26, 18, ToyColors.orange),
  ShapeKind.star: (25, 24, ToyColors.yellow),
  ShapeKind.heart: (24, 22, ToyColors.pink),
  ShapeKind.semicircle: (26, 13, ToyColors.purple),
  ShapeKind.rhombus: (18, 26, ToyColors.lightBlue),
  ShapeKind.crescent: (24, 24, ToyColors.yellow),
};

/// The little icon of [kind] in the top bar: painted once [met], a dashed
/// outline before.
String kindIconSvg(ShapeKind kind, {required bool met}) {
  final (w, h, color) = _icons[kind]!;
  final k = shadesOf(color);
  final paint = met
      ? 'fill="${k.fill}" stroke="${k.line}" stroke-width="2"'
      : 'fill="none" stroke="#dcc2a2" stroke-width="2" stroke-dasharray="3 3"';
  return '$_svgOpen viewBox="-3 -3 34 34"><g transform="translate(${_n((28 - w) / 2)} ${_n((28 - h) / 2)})">'
      '<path d="${shapePathData(kind, w, h)}" $paint stroke-linejoin="round"/></g></svg>';
}
```

- [ ] **Step 5: Create `lib/presentation/shapes/shape_motion.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/shapes/shape_picture.dart';

/// How long [motion] plays, once.
Duration motionDuration(PictureMotion motion) => Duration(
      milliseconds: switch (motion) {
        PictureMotion.wiggle => 1500,
        PictureMotion.hop => 1800,
        PictureMotion.chug => 2100,
        PictureMotion.drive => 2800,
        PictureMotion.launch => 3000,
        PictureMotion.swim => 2800,
        PictureMotion.rock => 3300,
        PictureMotion.sway => 3600,
        PictureMotion.pulse => 3000,
      },
    );

double _frac(double v) => v - v.floorToDouble();

/// Where a finished picture is [t] (0…1) of the way through [motion]: a
/// transform in card units. Every motion starts and ends at rest; turning
/// motions turn around [pivot].
Matrix4 pictureMotion(PictureMotion motion, double t, ({double x, double y}) pivot) {
  Matrix4 turn(double degrees) => Matrix4.translationValues(pivot.x, pivot.y, 0)
    ..multiply(Matrix4.rotationZ(degrees * math.pi / 180))
    ..multiply(Matrix4.translationValues(-pivot.x, -pivot.y, 0));
  Matrix4 move(double x, double y) => Matrix4.translationValues(x, y, 0);

  switch (motion) {
    case PictureMotion.wiggle || PictureMotion.rock || PictureMotion.sway:
      return turn(-5 * math.sin(t * 3 * 2 * math.pi));
    case PictureMotion.hop:
      return move(0, -18 * math.sin(math.pi * _frac(t * 4)));
    case PictureMotion.chug:
      return move(0, -5 * math.sin(math.pi * _frac(t * 7)));
    case PictureMotion.drive:
      if (t < .42) return move(360 * Curves.easeIn.transform(t / .42), 0);
      if (t < .43) return move(-360, 0);
      return move(-360 * (1 - Curves.easeOut.transform((t - .43) / .57)), 0);
    case PictureMotion.launch:
      if (t < .18) return move(2 * math.sin(t / .18 * 4 * math.pi), 0);
      if (t < .48) return move(0, -360 * Curves.easeIn.transform((t - .18) / .3));
      if (t < .49) return move(0, 360);
      return move(0, 360 * (1 - Curves.easeOut.transform((t - .49) / .51)));
    case PictureMotion.swim:
      final a = _frac(t * 2) * 2 * math.pi;
      return move(12 * (1 - math.cos(a)), -10 * math.sin(a));
    case PictureMotion.pulse:
      return Matrix4.identity();
  }
}

/// How big a pulsing piece is [t] (0…1) of the way through: three swells.
double pulseScale(double t) => 1 + .12 * math.sin(math.pi * _frac(t * 3)).abs();
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/presentation/shapes`
Expected: PASS. If a layer fails to parse, read the flutter_svg error and fix that SVG string (do not drop the feature).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/shapes test/presentation/shapes
git commit -m "feat: «Фигурки» art — wooden toy pieces, warm stand-in backgrounds, picture motions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: The picture card widget and its effects

**Files:**
- Create: `lib/presentation/shapes/shape_effects.dart`, `lib/presentation/shapes/shape_picture_view.dart`, `test/presentation/shapes/shape_picture_view_test.dart`, `assets/shapes/backgrounds/.gitkeep`
- Modify: `pubspec.yaml` (add `- assets/shapes/backgrounds/`)

**Interfaces:**
- Consumes: Task 6 (`artOf`, `slotLayerSvg`, `backgroundSvg`, `backdropSvg`, `PictureEffect`, `EffectKind`, `motionDuration`, `pictureMotion`, `pulseScale`); Task 2 types.
- Produces: `class EffectsPainter extends CustomPainter` (`EffectsPainter(List<PictureEffect> effects, double seconds)`); `class ShapePictureView extends StatefulWidget` with `ShapePictureView({Key? key, required ShapePicture picture, required Set<int> filled, int? highlighted, Set<int> hinting = const {}, int hintRun = 0, bool alive = false, String? backgroundAsset})`. Each slot layer has key `ValueKey('shapes_slot_$index')`.

- [ ] **Step 1: Write the failing test** — `test/presentation/shapes/shape_picture_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';
import 'package:yandee/presentation/shapes/shape_picture_view.dart';

Widget _host(Widget child) => MaterialApp(home: Center(child: SizedBox(width: 300, height: 300, child: child)));

void main() {
  final house = shapePictures[1];

  testWidgets('draws a layer for every slot, square in its box', (tester) async {
    await tester.pumpWidget(_host(ShapePictureView(picture: house, filled: const {0})));
    for (var i = 0; i < house.slots.length; i++) {
      expect(find.byKey(ValueKey('shapes_slot_$i')), findsOneWidget);
    }
    expect(tester.getSize(find.byType(ShapePictureView)), const Size(300, 300));
  });

  testWidgets('without a painted background it draws the stand-in one', (tester) async {
    await tester.pumpWidget(_host(ShapePictureView(picture: house, filled: const {})));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(SvgPicture), findsWidgets);
  });

  testWidgets('comes alive and settles back when the motion ends', (tester) async {
    await tester.pumpWidget(_host(ShapePictureView(picture: shapePictures[2], filled: const {0, 1, 2})));
    await tester.pumpWidget(_host(ShapePictureView(picture: shapePictures[2], filled: const {0, 1, 2}, alive: true)));
    await tester.pump(const Duration(milliseconds: 1000));
    final moving = tester.getTopLeft(find.byKey(const ValueKey('shapes_slot_0')));
    expect(moving.dx, isNot(closeTo(tester.getTopLeft(find.byType(ShapePictureView)).dx, .5)));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(find.byKey(const ValueKey('shapes_slot_0'))),
        tester.getTopLeft(find.byType(ShapePictureView)));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a hint pulses its slots and stops', (tester) async {
    await tester.pumpWidget(_host(ShapePictureView(picture: house, filled: const {})));
    await tester.pumpWidget(_host(ShapePictureView(picture: house, filled: const {}, hinting: const {2}, hintRun: 1)));
    await tester.pump(const Duration(milliseconds: 200));
    final size = tester.getSize(find.byKey(const ValueKey('shapes_slot_2')));
    expect(size.width, 300);
    await tester.pumpAndSettle();
  });
}
```

(The slot layers are full-card layers, so a hint is visible as a transform of the layer, not a size change; the last test only checks the pulse runs and settles. The "alive" test checks the drive motion moves the layers and puts them back.)

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/presentation/shapes/shape_picture_view_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Create `lib/presentation/shapes/shape_effects.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shape_art.dart';

Color _hex(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

double _frac(double v) => v - v.floorToDouble();

/// Draws the little moving things of a finished picture — smoke, bubbles,
/// lights, a flame — in card units, [seconds] after it came alive.
class EffectsPainter extends CustomPainter {
  EffectsPainter(this.effects, this.seconds);

  final List<PictureEffect> effects;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300);
    for (final effect in effects) {
      final t = seconds - effect.delay;
      if (t < 0) continue;
      _paint(canvas, effect, t);
    }
    canvas.restore();
  }

  // A value going 0 → 1 → 0 every [period] seconds.
  static double _swing(double t, double period) => .5 - .5 * math.cos(2 * math.pi * t / period);

  void _paint(Canvas canvas, PictureEffect e, double t) {
    final color = _hex(e.color);
    switch (e.kind) {
      case EffectKind.puff:
        final p = _frac(t / 1.6);
        canvas.drawCircle(Offset(e.x - 14 * p, e.y - 70 * p), 11 * (.6 + p),
            Paint()..color = const Color(0xFFEEF3F8).withValues(alpha: .95 * (1 - p)));
      case EffectKind.bubble:
        final p = _frac(t / 1.8);
        canvas.drawCircle(Offset(e.x + 10 * p, e.y - 90 * p), 6 * e.size * (.6 + .6 * p),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white.withValues(alpha: 1 - p));
      case EffectKind.twinkle:
        final s = _swing(t, 1);
        final r = 9 * (.8 + .3 * s);
        canvas.drawCircle(Offset(e.x, e.y), r, Paint()..color = color.withValues(alpha: .3 + .7 * s));
        canvas.drawCircle(Offset(e.x, e.y), r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white.withValues(alpha: .3 + .7 * s));
      case EffectKind.glow:
        canvas.drawCircle(Offset(e.x, e.y), 28, Paint()..color = const Color(0xFFFFF7B0).withValues(alpha: .3 + .45 * _swing(t, 1.8)));
      case EffectKind.flame:
        final stretch = .8 + .4 * _swing(t, .36);
        final flame = Path()
          ..moveTo(e.x - 24, e.y)
          ..quadraticBezierTo(e.x, e.y + 60 * stretch, e.x + 24, e.y)
          ..quadraticBezierTo(e.x, e.y + 16 * stretch, e.x - 24, e.y)
          ..close();
        canvas.drawPath(flame, Paint()..color = const Color(0xFFFFC929));
        canvas.drawPath(flame,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFFFF8A1F));
      case EffectKind.risingHeart:
        final p = _frac(t / 2.2);
        _heart(canvas, e.x + 16 * p, e.y - 60 * p, 22, 20, color.withValues(alpha: 1 - p));
      case EffectKind.zz:
        final p = _frac(t / 2.2);
        final text = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(fontSize: 26 * e.size, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 1 - p)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(e.x + 16 * p, e.y - 26 * e.size - 60 * p));
      case EffectKind.cherry:
        final drop = Curves.easeOutBack.transform(math.min(1, t / .7));
        final y = e.y - 120 * (1 - drop);
        canvas.drawPath(
            Path()
              ..moveTo(e.x, y - 8)
              ..quadraticBezierTo(e.x + 6, y - 30, e.x + 20, y - 38),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFF3FAE4F));
        canvas.drawCircle(Offset(e.x, y), 15, Paint()..color = const Color(0xFFE2553F));
        canvas.drawCircle(Offset(e.x, y), 15,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFFB8301F));
        canvas.drawCircle(Offset(e.x - 5, y - 5), 4, Paint()..color = Colors.white.withValues(alpha: .6));
      case EffectKind.sparkle:
        final s = _swing(t, 1);
        final r = 9 * (.8 + .3 * s);
        final sparkle = Path()
          ..moveTo(e.x, e.y - r)
          ..quadraticBezierTo(e.x + r * .17, e.y - r * .17, e.x + r, e.y)
          ..quadraticBezierTo(e.x + r * .17, e.y + r * .17, e.x, e.y + r)
          ..quadraticBezierTo(e.x - r * .17, e.y + r * .17, e.x - r, e.y)
          ..quadraticBezierTo(e.x - r * .17, e.y - r * .17, e.x, e.y - r)
          ..close();
        canvas.drawPath(sparkle, Paint()..color = color.withValues(alpha: .3 + .7 * s));
      case EffectKind.speedLines:
        final paint = Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = Colors.white;
        canvas
          ..drawLine(Offset(e.x - 6, e.y - 30), Offset(e.x + 16, e.y - 30), paint)
          ..drawLine(Offset(e.x - 16, e.y), Offset(e.x + 12, e.y), paint)
          ..drawLine(Offset(e.x - 4, e.y + 30), Offset(e.x + 18, e.y + 30), paint);
    }
  }

  // The same heart as the shape, in a w × h box at (x, y).
  static void _heart(Canvas canvas, double x, double y, double w, double h, Color color) {
    double px(double v) => x + v * w / 100;
    double py(double v) => y + v * h / 100;
    final heart = Path()
      ..moveTo(px(50), py(97))
      ..cubicTo(px(22), py(77), px(1), py(58), px(1), py(33))
      ..cubicTo(px(1), py(14), px(15), py(2), px(29), py(2))
      ..cubicTo(px(39), py(2), px(46), py(8), px(50), py(17))
      ..cubicTo(px(54), py(8), px(61), py(2), px(71), py(2))
      ..cubicTo(px(85), py(2), px(99), py(14), px(99), py(33))
      ..cubicTo(px(99), py(58), px(78), py(77), px(50), py(97))
      ..close();
    canvas.drawPath(heart, Paint()..color = color);
  }

  @override
  bool shouldRepaint(EffectsPainter old) => old.seconds != seconds || old.effects != effects;
}
```

- [ ] **Step 4: Create `lib/presentation/shapes/shape_picture_view.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/shapes/shape_picture.dart';
import 'shape_art.dart';
import 'shape_effects.dart';
import 'shape_motion.dart';

/// The picture card of the "Фигурки" game: the background, the dashed
/// places and the pieces already in them, and — once [alive] — the
/// picture's own motion and effects. Square: it takes the largest square
/// that fits.
class ShapePictureView extends StatefulWidget {
  const ShapePictureView({
    super.key,
    required this.picture,
    required this.filled,
    this.highlighted,
    this.hinting = const {},
    this.hintRun = 0,
    this.alive = false,
    this.backgroundAsset,
  });

  final ShapePicture picture;
  final Set<int> filled;

  /// The empty slot the finger is over: its outline is lit up.
  final int? highlighted;

  /// Empty slots to show the child: lit up and pulsing.
  final Set<int> hinting;

  /// Bumped to play the hint pulse again.
  final int hintRun;

  final bool alive;

  /// A painted background to show instead of the stand-in one.
  final String? backgroundAsset;

  @override
  State<ShapePictureView> createState() => _ShapePictureViewState();
}

class _ShapePictureViewState extends State<ShapePictureView> with TickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this);
  late final AnimationController _hint =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Ticker _effectsTicker = createTicker((elapsed) {
    _seconds.value = elapsed.inMicroseconds / 1e6;
  });
  final ValueNotifier<double> _seconds = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    if (widget.alive) _comeAlive();
    if (widget.hinting.isNotEmpty) _pulseHint();
  }

  @override
  void didUpdateWidget(ShapePictureView old) {
    super.didUpdateWidget(old);
    if (widget.alive && !old.alive) _comeAlive();
    if (!widget.alive && old.alive) _settle();
    if (widget.hintRun != old.hintRun && widget.hinting.isNotEmpty) _pulseHint();
  }

  void _comeAlive() {
    _motion.duration = motionDuration(widget.picture.motion);
    _motion.forward(from: 0);
    _seconds.value = 0;
    if (!_effectsTicker.isActive) _effectsTicker.start();
  }

  void _settle() {
    _motion.reset();
    _effectsTicker.stop();
    _seconds.value = 0;
  }

  void _pulseHint() {
    _hint.reset();
    _hint.repeat(reverse: true, count: 4);
  }

  @override
  void dispose() {
    _effectsTicker.dispose();
    _motion.dispose();
    _hint.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, constraints.maxHeight);
      final scale = side / cardSize;
      final picture = widget.picture;
      final art = artOf(picture);
      final backdrop = backdropSvg(picture);
      final moving = [for (var i = 0; i < picture.slots.length; i++) if (!picture.slots[i].stays) i];
      final staying = [for (var i = 0; i < picture.slots.length; i++) if (picture.slots[i].stays) i];
      return Center(
        child: SizedBox.square(
          dimension: side,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30 * scale),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.backgroundAsset != null
                    ? Image.asset(widget.backgroundAsset!, fit: BoxFit.cover)
                    : SvgPicture.string(backgroundSvg(picture)),
                AnimatedBuilder(
                  animation: _motion,
                  builder: (context, child) {
                    final m = pictureMotion(picture.motion, _motion.value, picture.pivot);
                    return Transform(
                      transform: Matrix4.diagonal3Values(scale, scale, 1)
                        ..multiply(m)
                        ..multiply(Matrix4.diagonal3Values(1 / scale, 1 / scale, 1)),
                      child: child,
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (backdrop.isNotEmpty) SvgPicture.string(backdrop),
                      for (final i in moving) _slot(i, scale),
                      if (widget.alive)
                        ValueListenableBuilder<double>(
                          valueListenable: _seconds,
                          builder: (context, seconds, _) =>
                              CustomPaint(painter: EffectsPainter(art.effects, seconds)),
                        ),
                    ],
                  ),
                ),
                for (final i in staying) _slot(i, scale),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _slot(int index, double scale) {
    final slot = widget.picture.slots[index];
    final filled = widget.filled.contains(index);
    final hinting = !filled && widget.hinting.contains(index);
    final layer = SvgPicture.string(
      slotLayerSvg(widget.picture, index,
          filled: filled, highlighted: !filled && (hinting || widget.highlighted == index)),
    );
    final center = Offset(slot.box.center.x * scale, slot.box.center.y * scale);
    Widget scaled(double s, Widget child) => Transform(
          transform: Matrix4.translationValues(center.dx, center.dy, 0)
            ..multiply(Matrix4.diagonal3Values(s, s, 1))
            ..multiply(Matrix4.translationValues(-center.dx, -center.dy, 0)),
          child: child,
        );
    final Listenable? driver = hinting ? _hint : (widget.alive && slot.pulses ? _motion : null);
    return KeyedSubtree(
      key: ValueKey('shapes_slot_$index'),
      child: driver == null
          ? layer
          : AnimatedBuilder(
              animation: driver,
              builder: (context, child) =>
                  scaled(hinting ? 1 + .12 * _hint.value : pulseScale(_motion.value), child!),
              child: layer,
            ),
    );
  }
}
```

- [ ] **Step 5: Declare the backgrounds folder**

```bash
mkdir -p assets/shapes/backgrounds && touch assets/shapes/backgrounds/.gitkeep
```

In `pubspec.yaml` under `assets:` add `- assets/shapes/backgrounds/` after `- assets/audio/shapes/`.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/presentation/shapes && flutter analyze`
Expected: PASS, no issues. (If `repeat(count:)` is unavailable in this Flutter, replace `_pulseHint` with `_hint.forward(from: 0).then((_) => _hint.reverse()).then((_) => _hint.forward()).then((_) => _hint.reverse())` guarded by `mounted`.)

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/shapes test/presentation/shapes assets/shapes pubspec.yaml
git commit -m "feat: the «Фигурки» picture card — pieces, hints, coming alive

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The game screen

**Files:**
- Create: `lib/presentation/screens/shapes_screen.dart`, `test/presentation/screens/shapes_screen_test.dart`

**Interfaces:**
- Consumes: `ShapesGame`, `PieceShown`, `DropResult` (Task 3); `ShapePhrases` (Task 4); `ShapesVoice`, `ShapesSfx`, `ShapesVoicePlayer` (Task 4); `listBundledAssets` (Task 1); `ShapePictureView` (Task 7); `pieceSvg`, `pieceFrame`, `kindIconSvg`, `backgroundAssetOf` (Task 6).
- Produces: `class ShapesScreen extends StatefulWidget` with `ShapesScreen({Key? key, ShapesVoice Function()? voiceFactory, ShapesGame Function()? gameFactory, Future<Set<String>> Function()? bundledAssets})`. Keys: `shapes_back_button`, `shapes_card` (the card area), `shapes_piece` (the piece on the mat), `shapes_kind_<name>` (bar icons).

- [ ] **Step 1: Write the failing test** — `test/presentation/screens/shapes_screen_test.dart`:

```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/shapes_voice.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';
import 'package:yandee/domain/shapes/shapes_game.dart';
import 'package:yandee/presentation/screens/shapes_screen.dart';

import '../../support/fake_shapes_voice.dart';

class _Harness {
  _Harness(this.tester, this.voice);

  final WidgetTester tester;
  final FakeShapesVoice voice;
  late ShapesGame game;

  Rect get card => tester.getRect(find.byKey(const ValueKey('shapes_card')));

  Offset slotCenter(int slot) {
    final c = card;
    final k = c.width / cardSize;
    final box = game.picture.slots[slot].box;
    return Offset(c.left + box.center.x * k, c.top + box.center.y * k);
  }

  Offset get piece => tester.getCenter(find.byKey(const ValueKey('shapes_piece')));

  /// A free slot of another shape than the piece on the mat.
  int get wrongSlot => [
        for (var i = 0; i < game.picture.slots.length; i++)
          if (!game.filled.contains(i) && game.picture.slots[i].kind != game.pieceKind) i,
      ].first;

  Future<void> run(Duration duration) async {
    for (var elapsed = Duration.zero; elapsed < duration; elapsed += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> dragPieceTo(Offset target) async {
    final gesture = await tester.startGesture(piece);
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  /// Puts every piece of the current picture in place.
  Future<void> buildPicture() async {
    while (!game.pictureComplete) {
      await dragPieceTo(slotCenter(game.pieceSlot!));
      await run(const Duration(milliseconds: 800));
    }
  }
}

Future<_Harness> _start(WidgetTester tester, {int seed = 1}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness(tester, FakeShapesVoice());
  await tester.pumpWidget(MaterialApp(
    home: ShapesScreen(
      voiceFactory: () => harness.voice,
      gameFactory: () => harness.game = ShapesGame(random: Random(seed)),
      bundledAssets: () async => const {},
    ),
  ));
  await harness.run(const Duration(milliseconds: 600));
  return harness;
}

void main() {
  testWidgets('greets the child and names the first piece as a new shape', (tester) async {
    final h = await _start(tester);
    expect(h.voice.said, ['Собери картинку из фигурок!', 'Новая фигурка! ${h.game.pieceKind!.word}!']);
    expect(find.byKey(const ValueKey('shapes_piece')), findsOneWidget);
  });

  testWidgets('a piece dragged onto its place stays there and the next one comes', (tester) async {
    final h = await _start(tester);
    final slot = h.game.pieceSlot!;
    await h.dragPieceTo(h.slotCenter(slot));
    await h.run(const Duration(milliseconds: 800));
    expect(h.game.filled, {slot});
    expect(h.voice.sfx, contains(ShapesSfx.placed));
    expect(h.voice.said.last, 'Новая фигурка! ${h.game.pieceKind!.word}!');
  });

  testWidgets('a piece let go over the wrong place says «Не сюда!» and comes back', (tester) async {
    final h = await _start(tester);
    final kind = h.game.pieceKind;
    await h.dragPieceTo(h.slotCenter(h.wrongSlot));
    await h.run(const Duration(milliseconds: 1500));
    expect(h.voice.said.last, 'Не сюда!');
    expect(h.voice.sfx, contains(ShapesSfx.wrong));
    expect(h.game.filled, isEmpty);
    expect(h.game.pieceKind, kind);
    expect(find.byKey(const ValueKey('shapes_piece')), findsOneWidget);
  });

  testWidgets('a piece let go far from every place just goes back, silently', (tester) async {
    final h = await _start(tester);
    final said = h.voice.said.length;
    await h.dragPieceTo(h.card.topLeft + const Offset(2, 2));
    await h.run(const Duration(milliseconds: 600));
    expect(h.voice.said.length, said);
    expect(h.game.filled, isEmpty);
  });

  testWidgets('tapping the piece or an empty place says the shape', (tester) async {
    final h = await _start(tester);
    await tester.tapAt(h.piece);
    await h.run(const Duration(milliseconds: 300));
    expect(h.voice.said.last, '${h.game.pieceKind!.word}!');
    final other = h.wrongSlot;
    await tester.tapAt(h.slotCenter(other));
    await h.run(const Duration(milliseconds: 300));
    expect(h.voice.said.last, '${h.game.picture.slots[other].kind.word}!');
  });

  testWidgets('a finished picture says its name with «Ура!», then the next picture comes', (tester) async {
    final h = await _start(tester);
    await h.buildPicture();
    expect(h.voice.said, contains('Мороженое! Ура!'));
    expect(h.voice.sfx, contains(ShapesSfx.pictureDone));
    await h.run(const Duration(seconds: 5));
    expect(h.game.picture.id, 'house');
    expect(h.voice.said.last, anyOf('Новая фигурка! Квадрат!', 'Круг!', 'Треугольник!'));
  });

  testWidgets('the back button leaves the game and the voice is released', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final voice = FakeShapesVoice();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ShapesScreen(voiceFactory: () => voice, bundledAssets: () async => const {}),
          )),
          child: const Text('открыть'),
        ),
      ),
    ));
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('shapes_back_button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('открыть'), findsOneWidget);
    expect(voice.disposeCalled, isTrue);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/presentation/screens/shapes_screen_test.dart`
Expected: FAIL — `shapes_screen.dart` not found.

- [ ] **Step 3: Create `lib/presentation/screens/shapes_screen.dart`**

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../audio/clip_line_player.dart';
import '../../audio/shapes_voice.dart';
import '../../audio/shapes_voice_player.dart';
import '../../domain/shapes/shape_kind.dart';
import '../../domain/shapes/shape_phrases.dart';
import '../../domain/shapes/shape_picture.dart';
import '../../domain/shapes/shapes_game.dart';
import '../shapes/shape_art.dart';
import '../shapes/shape_picture_view.dart';

const _paper = Color(0xFFFFF8F0);
const _cardColor = Color(0xFFFFF0E1);
const _mat = Color(0xFFFFE6CD);
const _stitch = Color(0xFFE3C39C);
const _ink = Color(0xFF2B211A);
const _shadow = Color(0x24543410);

/// The "Фигурки" game: a picture card made of dashed places, a mat with one
/// wooden piece on it, and the child drags the piece to its place.
///
/// The rules live in [ShapesGame]; this screen turns drags and taps into
/// its calls and plays out each result as flight, sound and speech, the way
/// the prototype (`docs/prototypes/shapes.html`) does.
class ShapesScreen extends StatefulWidget {
  const ShapesScreen({super.key, this.voiceFactory, this.gameFactory, this.bundledAssets});

  /// Makes the sound output; tests pass a fake.
  final ShapesVoice Function()? voiceFactory;

  /// Makes the game; tests pass a seeded one.
  final ShapesGame Function()? gameFactory;

  /// Lists the app's assets, to find painted backgrounds. Tests pass none.
  final Future<Set<String>> Function()? bundledAssets;

  @override
  State<ShapesScreen> createState() => _ShapesScreenState();
}

/// Where everything sits for a given screen size — plain arithmetic, so a
/// finger can be hit-tested without looking into the widget tree.
class _Layout {
  _Layout(this.size);

  final Size size;
  static const _side = 16.0;
  static const _gap = 12.0;

  Rect get bar => Rect.fromLTWH(_side, 8, size.width - 2 * _side, 60);

  Rect get mat {
    final height = (size.height * .26).clamp(120.0, 220.0);
    return Rect.fromLTWH(_side, size.height - 12 - height, size.width - 2 * _side, height);
  }

  Rect get card {
    final top = bar.bottom + _gap, bottom = mat.top - _gap;
    final side = math.min(size.width - 2 * _side, bottom - top);
    return Rect.fromCenter(center: Offset(size.width / 2, (top + bottom) / 2), width: side, height: side);
  }

  double get scale => card.width / cardSize;

  Rect onCard(CardBox box) =>
      Rect.fromLTWH(card.left + box.x * scale, card.top + box.y * scale, box.width * scale, box.height * scale);

  ({double x, double y}) toCard(Offset point) =>
      (x: (point.dx - card.left) / scale, y: (point.dy - card.top) / scale);

  /// The piece for [slot] lying on the mat, as big as the mat allows.
  Rect pieceOnMat(ShapeSlot slot) {
    final frame = pieceFrame(slot);
    final k = math.min(mat.width * .62 / frame.width, mat.height * .8 / frame.height);
    return Rect.fromCenter(center: mat.center, width: frame.width * k, height: frame.height * k);
  }
}

class _Touch {
  _Touch({required this.pointer, required this.start, required this.onPiece});

  final int pointer;
  final Offset start;
  final bool onPiece;

  /// Where the finger holds the piece, from its top left corner.
  Offset grip = Offset.zero;
  bool dragging = false;
}

class _ShapesScreenState extends State<ShapesScreen> with SingleTickerProviderStateMixin {
  static const _dragSlop = 10.0;
  static const _tapSlop = 24.0;
  static const _dropMargin = 24.0;

  late final ShapesVoice _voice = widget.voiceFactory?.call() ?? ShapesVoicePlayer();
  late final AnimationController _flight = AnimationController(vsync: this);
  late ShapesGame _game;
  final ValueNotifier<Rect?> _floating = ValueNotifier(null);
  final Set<Timer> _timers = {};
  _Layout _layout = _Layout(Size.zero);
  Set<String> _bundled = const {};

  int _session = 0;
  bool _busy = false;
  _Touch? _touch;
  int? _over;
  Set<int> _hinting = const {};
  int _hintRun = 0;
  bool _alive = false;
  ShapeKind? _justMet;
  int _pieceRun = 0;
  int _wiggleRun = 0;
  int _confettiRun = 0;
  Rect Function(double t)? _flightPath;

  @override
  void initState() {
    super.initState();
    _flight.addListener(() {
      final path = _flightPath;
      if (path != null) _floating.value = path(_flight.value);
    });
    final assets = widget.bundledAssets?.call() ?? listBundledAssets(rootBundle);
    assets.then((value) {
      if (mounted) setState(() => _bundled = value);
    });
    _game = widget.gameFactory?.call() ?? ShapesGame();
    final session = _session;
    _pause(400).then((_) {
      if (_stale(session)) return;
      unawaited(_voice.say(ShapePhrases.introLine));
      _showNextPiece();
    });
  }

  @override
  void dispose() {
    _session++;
    for (final timer in _timers) {
      timer.cancel();
    }
    _flight.dispose();
    _floating.dispose();
    _voice.dispose();
    super.dispose();
  }

  bool _stale(int session) => !mounted || session != _session;

  /// Waits [milliseconds]; the wait is dropped if the screen closes first.
  Future<void> _pause(int milliseconds) {
    final done = Completer<void>();
    late final Timer timer;
    timer = Timer(Duration(milliseconds: milliseconds), () {
      _timers.remove(timer);
      done.complete();
    });
    _timers.add(timer);
    return done.future;
  }

  /// Waits for [speech] to end, but no longer than [milliseconds].
  Future<void> _heardOut(Future<void> speech, {int milliseconds = 4000}) =>
      Future.any([speech.catchError((Object _) {}), _pause(milliseconds)]);

  void _showNextPiece() {
    final piece = _game.nextPiece();
    setState(() {
      _pieceRun++;
      if (piece.firstMeeting) _justMet = piece.kind;
    });
    unawaited(_voice.say(piece.firstMeeting ? ShapePhrases.meet(piece.kind) : ShapePhrases.name(piece.kind)));
  }

  Rect? get _pieceRect {
    final slot = _game.pieceSlot;
    return slot == null ? null : _layout.pieceOnMat(_game.picture.slots[slot]);
  }

  // ------------------------------------------------------------- touches

  void _onPointerDown(PointerDownEvent event) {
    if (_touch != null || _busy) return;
    final point = event.localPosition;
    final piece = _pieceRect;
    if (piece != null && piece.contains(point)) {
      _touch = _Touch(pointer: event.pointer, start: point, onPiece: true)..grip = point - piece.topLeft;
    } else if (_layout.card.contains(point)) {
      _touch = _Touch(pointer: event.pointer, start: point, onPiece: false);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final touch = _touch;
    if (touch == null || touch.pointer != event.pointer || !touch.onPiece || _busy) return;
    final point = event.localPosition;
    if (!touch.dragging && (point - touch.start).distance > _dragSlop) touch.dragging = true;
    if (!touch.dragging) return;
    final piece = _pieceRect!;
    _floating.value = (point - touch.grip) & piece.size;
    final over = _slotAt(point);
    if (over != _over) setState(() => _over = over);
  }

  void _onPointerUp(PointerUpEvent event) => _endTouch(event.pointer, event.localPosition, cancelled: false);

  void _onPointerCancel(PointerCancelEvent event) => _endTouch(event.pointer, event.localPosition, cancelled: true);

  int? _slotAt(Offset point) {
    final p = _layout.toCard(point);
    return _game.slotAt(p.x, p.y, margin: _dropMargin / _layout.scale);
  }

  void _endTouch(int pointer, Offset point, {required bool cancelled}) {
    final touch = _touch;
    if (touch == null || touch.pointer != pointer) return;
    _touch = null;
    if (_busy) return;
    if (_over != null) setState(() => _over = null);

    if (!touch.onPiece) {
      // A tap on an empty place: it lights up and says its shape.
      if (cancelled || (point - touch.start).distance > _tapSlop) return;
      final p = _layout.toCard(point);
      final slot = _game.slotAt(p.x, p.y);
      if (slot == null) return;
      setState(() {
        _hinting = {slot};
        _hintRun++;
      });
      unawaited(_voice.say(ShapePhrases.name(_game.picture.slots[slot].kind)));
      return;
    }
    if (!touch.dragging) {
      if (cancelled) return;
      setState(() => _wiggleRun++);
      unawaited(_voice.say(ShapePhrases.name(_game.pieceKind!)));
      return;
    }
    final slot = cancelled ? null : _slotAt(point);
    if (slot == null) {
      unawaited(_flyBack());
    } else {
      unawaited(_drop(slot));
    }
  }

  // ----------------------------------------------------------- sequences

  Future<void> _fly(Rect to, int milliseconds) async {
    final from = _floating.value ?? _pieceRect!;
    _flightPath = (t) => Rect.lerp(from, to, Curves.easeOutCubic.transform(t))!;
    _flight.duration = Duration(milliseconds: milliseconds);
    try {
      await _flight.forward(from: 0).orCancel;
    } on TickerCanceled {
      // The screen closed mid-flight.
    }
  }

  Future<void> _flyBack() async {
    _busy = true;
    final session = _session;
    await _fly(_pieceRect!, 320);
    if (_stale(session)) return;
    _floating.value = null;
    _busy = false;
  }

  Future<void> _drop(int slot) async {
    _busy = true;
    final session = _session;
    final target = _layout.onCard(pieceFrame(_game.picture.slots[slot]));
    await _fly(target, 300);
    if (_stale(session)) return;
    final result = _game.drop(slot);

    if (!result.accepted) {
      _voice.playSfx(ShapesSfx.wrong);
      final speech = _voice.say(ShapePhrases.notHereLine);
      await _heardOut(speech, milliseconds: 2500);
      if (_stale(session)) return;
      final kind = _game.pieceKind;
      setState(() {
        _hinting = {
          for (var i = 0; i < _game.picture.slots.length; i++)
            if (!_game.filled.contains(i) && _game.picture.slots[i].kind == kind) i,
        };
        _hintRun++;
      });
      await _fly(_pieceRect!, 320);
      if (_stale(session)) return;
      _floating.value = null;
      _busy = false;
      return;
    }

    _voice.playSfx(ShapesSfx.placed);
    _floating.value = null;
    setState(() => _hinting = const {});
    if (!result.pictureComplete) {
      await _pause(320);
      if (_stale(session)) return;
      _showNextPiece();
      _busy = false;
      return;
    }
    await _celebrate(result, session);
  }

  Future<void> _celebrate(DropResult result, int session) async {
    await _pause(350);
    if (_stale(session)) return;
    setState(() => _alive = true);
    _voice.playSfx(ShapesSfx.pictureDone);
    final speech = _voice.say(ShapePhrases.done(_game.picture));
    await Future.wait([_pause(3500), _heardOut(speech)]);
    if (_stale(session)) return;
    if (result.chainComplete) {
      setState(() => _confettiRun++);
      _voice.playSfx(ShapesSfx.allDone);
      final win = _voice.say(ShapePhrases.winLine);
      await Future.wait([_pause(3200), _heardOut(win)]);
      if (_stale(session)) return;
    }
    _game.nextPicture();
    setState(() {
      _alive = false;
      _justMet = null;
    });
    _showNextPiece();
    _busy = false;
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    // A swipe from the screen edge must not throw a toddler back to the
    // list; the round back button still works.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _paper,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final layout = _layout = _Layout(constraints.biggest);
            final picture = _game.picture;
            final pieceSlot = _game.pieceSlot;
            final background = backgroundAssetOf(picture);
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Positioned.fromRect(rect: layout.bar, child: _buildBar()),
                  Positioned.fromRect(
                    key: const ValueKey('shapes_card'),
                    rect: layout.card,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30 * layout.scale),
                        boxShadow: const [BoxShadow(color: _shadow, blurRadius: 18, offset: Offset(0, 12))],
                      ),
                      child: ShapePictureView(
                        picture: picture,
                        filled: _game.filled,
                        highlighted: _over,
                        hinting: _hinting,
                        hintRun: _hintRun,
                        alive: _alive,
                        backgroundAsset: _bundled.contains(background) ? background : null,
                      ),
                    ),
                  ),
                  Positioned.fromRect(rect: layout.mat, child: const _Mat()),
                  if (pieceSlot != null)
                    ValueListenableBuilder<Rect?>(
                      valueListenable: _floating,
                      builder: (context, floating, _) => Positioned.fromRect(
                        key: const ValueKey('shapes_piece'),
                        rect: layout.pieceOnMat(picture.slots[pieceSlot]),
                        child: Opacity(
                          opacity: floating == null ? 1 : 0,
                          child: _MatPiece(
                            svg: pieceSvg(picture, pieceSlot),
                            popRun: _pieceRun,
                            wiggleRun: _wiggleRun,
                          ),
                        ),
                      ),
                    ),
                  if (pieceSlot != null)
                    ValueListenableBuilder<Rect?>(
                      valueListenable: _floating,
                      builder: (context, floating, _) => floating == null
                          ? const Positioned(left: 0, top: 0, child: SizedBox.shrink())
                          : Positioned.fromRect(
                              rect: floating,
                              child: IgnorePointer(child: SvgPicture.string(pieceSvg(picture, pieceSlot))),
                            ),
                    ),
                  if (_confettiRun > 0)
                    Positioned.fill(child: IgnorePointer(child: _Confetti(key: ValueKey(_confettiRun)))),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBar() {
    final met = _game.metKinds;
    return Row(
      children: [
        _RoundButton(
          key: const ValueKey('shapes_back_button'),
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Semantics(
            label: 'Знакомых фигурок: ${met.length} из ${ShapeKind.values.length}',
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final kind in ShapeKind.values)
                  AnimatedScale(
                    key: ValueKey('shapes_kind_${kind.name}'),
                    scale: kind == _justMet ? 1.35 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: SvgPicture.string(kindIconSvg(kind, met: met.contains(kind)), width: 26, height: 26),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 56),
      ],
    );
  }
}

/// The soft stitched mat the piece lies on.
class _Mat extends StatelessWidget {
  const _Mat();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _mat,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: _shadow, blurRadius: 26, offset: Offset(0, 10))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _stitch, width: 2),
          ),
        ),
      ),
    );
  }
}

/// The piece on the mat: it pops in when new ([popRun] changes) and
/// wiggles when tapped ([wiggleRun] changes).
class _MatPiece extends StatelessWidget {
  const _MatPiece({required this.svg, required this.popRun, required this.wiggleRun});

  final String svg;
  final int popRun;
  final int wiggleRun;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('pop_$popRun'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('wiggle_$wiggleRun'),
        tween: Tween(begin: wiggleRun == 0 ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (context, t, child) =>
            Transform.rotate(angle: math.sin(t * 2 * math.pi) * .17, child: child),
        child: SvgPicture.string(svg),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: _cardColor,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _shadow, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onPressed, child: Icon(icon, color: _ink, size: 28)),
        ),
      ),
    );
  }
}

/// A burst of confetti in toy colours, falling once from top to bottom.
class _Confetti extends StatefulWidget {
  const _Confetti({super.key});

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  static const _colors = [
    ToyColors.red, ToyColors.blue, ToyColors.yellow, ToyColors.green,
    ToyColors.orange, ToyColors.purple, ToyColors.pink, ToyColors.lightBlue,
  ];
  late final AnimationController _fall =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..forward();
  final _pieces = [
    for (var i = 0; i < 40; i++)
      (x: (i * 37 % 100) / 100, delay: (i * 13 % 10) / 25, spin: (i % 7 - 3) * 1.4, color: _colors[i % _colors.length]),
  ];

  @override
  void dispose() {
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      return AnimatedBuilder(
        animation: _fall,
        builder: (context, _) => Stack(children: [
          for (final p in _pieces)
            if (_fall.value > p.delay)
              Positioned(
                left: p.x * size.width,
                top: -20 + (size.height + 60) * ((_fall.value - p.delay) / (1 - p.delay)),
                child: Transform.rotate(
                  angle: p.spin * _fall.value * math.pi,
                  child: Container(
                    width: 14,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Color(0xFF000000 | int.parse(p.color.substring(1), radix: 16)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
        ]),
      );
    });
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/presentation/screens/shapes_screen_test.dart`
Expected: PASS. If the drag lands short (finger slop), check `dragPieceTo` moves past `_dragSlop` before `moveTo`.

- [ ] **Step 5: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/shapes_screen.dart test/presentation/screens/shapes_screen_test.dart
git commit -m "feat: the «Фигурки» game screen — drag a piece to its place, the picture comes alive

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: The «Фигурки» card in the grid

**Files:**
- Modify: `lib/presentation/screens/scene_list_screen.dart`, `test/presentation/screens/scene_list_screen_test.dart`, `README.md`

**Interfaces:**
- Consumes: `ShapesScreen` (Task 8), `ShapePictureView` (Task 7), `shapePictures` (Task 2).
- Produces: `SceneListScreen({..., WidgetBuilder? shapesScreenBuilder})`; grid card key `shapes_game_card`, second in the grid.

- [ ] **Step 1: Write the failing test** — append to `test/presentation/screens/scene_list_screen_test.dart`, modelled on the existing «Монстрики» card test (reuse its repository/setup helpers exactly as that test does):

```dart
  testWidgets('shows the "Фигурки" game right after "Монстрики", and it opens the game', (tester) async {
    // Same setup as the "Монстрики" card test above.
    await pumpSceneList(tester, shapesScreenBuilder: (_) => const Scaffold(body: Text('фигурки открыты')));

    final cards = find.descendant(of: find.byType(GridView), matching: find.byType(GestureDetector));
    expect((tester.widget(cards.at(1)) as GestureDetector).key, const ValueKey('shapes_game_card'));
    expect(find.text('Фигурки'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shapes_game_card')));
    await tester.pumpAndSettle();
    expect(find.text('фигурки открыты'), findsOneWidget);
  });
```

Before writing it, read the existing «Монстрики» card test (around line 201) and copy its setup verbatim instead of `pumpSceneList` if no such helper exists — the setup lines (fake repository with cached scenes, `pumpWidget(MaterialApp(home: SceneListScreen(...)))`, `pumpAndSettle`) must be the same, plus `shapesScreenBuilder:`.

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/presentation/screens/scene_list_screen_test.dart`
Expected: FAIL — `shapesScreenBuilder` is not a parameter.

- [ ] **Step 3: Add the card**

In `scene_list_screen.dart`: import `../../domain/shapes/shape_picture.dart`, `../shapes/shape_picture_view.dart`, `shapes_screen.dart`. Add the field:

```dart
  /// Builds the screen the "Фигурки" card opens. Defaults to the real game;
  /// tests pass one that needs no audio plugin.
  final WidgetBuilder? shapesScreenBuilder;
```

(constructor: `this.shapesScreenBuilder`). In the grid children use `[_buildMonstersCard(), _buildShapesCard(), ...scenes.map(_buildCard)]` and update the comment to «The two games are not scenes, but they are entered the same way: cards like the others, first in the grid.» Add:

```dart
  Widget _buildShapesCard() {
    return GestureDetector(
      key: const ValueKey('shapes_game_card'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: widget.shapesScreenBuilder ?? (_) => const ShapesScreen()),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // The finished house on a warm card, in the same upright shape
            // as a scene thumbnail.
            Expanded(
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: ColoredBox(
                  color: const Color(0xFFFFF0E1),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: ShapePictureView(picture: shapePictures[1], filled: const {0, 1, 2}),
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.all(8), child: Text('Фигурки')),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Note the game in `README.md`**

Under «Структура», after the `presentation/` block lines, add to `domain/`: `shapes/   — правила игры «Фигурки» (ShapesGame, картинки, фразы)` and to `presentation/`: `shapes/ — рисунки и карточка игры «Фигурки»`; and under `tool/`: `write_shapes_phrases_doc.dart — docs/shapes_phrases.md из списка фраз «Фигурок»`.

- [ ] **Step 5: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/scene_list_screen.dart test/presentation/screens/scene_list_screen_test.dart README.md
git commit -m "feat: the «Фигурки» card in the grid, right after «Монстрики»

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Look at it for real

**Files:** none unless something is visibly wrong.

- [ ] **Step 1:** Run the app on the iOS simulator (`flutter run -d <simulator>`), open «Фигурки», build «Мороженое» and «Домик» by dragging, try a wrong drop and a tap on an outline; screenshot the game screen and the grid card.
- [ ] **Step 2:** Compare with the prototype: wooden edge under every piece (also on the turned cone and hull), outlines dashed, highlight orange, the picture moves and effects play. Fix anything broken in the art strings or view, with a test where the fault is testable.
- [ ] **Step 3:** `flutter test && flutter analyze`; commit any fixes with a `fix:` message.
