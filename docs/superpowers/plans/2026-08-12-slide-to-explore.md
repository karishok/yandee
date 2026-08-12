# Slide-to-Explore Multitouch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make touching or sliding a finger over a scene object's tap zone play its sound — not just a clean tap-in-place — with each simultaneously touching finger tracked independently.

**Architecture:** Replace `SceneIllustration`'s per-object `Positioned(GestureDetector(onTap: ...))` zones with a single `Listener` spanning the whole illustration that tracks, per `PointerEvent.pointer` id, which object (if any) that finger currently sits over, and calls `SceneController.onObjectTapped` whenever that changes to a new object. The per-object `Positioned` widgets stay in the tree as inert (`IgnorePointer`-wrapped) geometry markers, keyed exactly as before, so widget tests can still measure and center-locate a given object's zone — they just no longer receive touches themselves.

**Tech Stack:** Flutter/Dart, `flutter_test`, `provider` (existing `ChangeNotifierProvider<SceneController>`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-12-slide-to-explore-design.md`.
- Only `lib/presentation/widgets/scene_illustration.dart` changes at the source level. `SceneController`, `ExploreMode`, `FindMode`, and the audio layer are untouched — they already tolerate rapid/repeated `onObjectTapped` calls (see that file's comments on `_voiceQueue`, `_correctPending`, `playInterruptibleSystemPhrase`).
- Overlap priority when two objects' rects intersect: the object later in `scene.objects` wins (same as today's Stack paint order).
- A pointer's sound fires exactly once per "entry" into an object's zone: on initial touch-down into it, and again on every subsequent re-entry after having left it (including leaving to empty space and coming straight back) — never repeatedly while resting/moving within the same zone.
- Every step that runs tests must be run from the repo root: `/Users/karina/flutter/yandee`.

---

### Task 1: Adapt existing zone-tap assertions to coordinate-based taps

**Files:**
- Modify: `test/presentation/widgets/scene_illustration_test.dart:99-101`
- Modify: `test/presentation/screens/scene_screen_test.dart:156,160,164,321,387`

**Interfaces:**
- Consumes: `WidgetTester.tapAt(Offset)` and `WidgetTester.getCenter(Finder)` (both existing `flutter_test` APIs, no new code).
- Produces: nothing new — this task only changes *how* existing tests deliver a tap, not what they assert. Task 3 relies on these call sites already being coordinate-based before the widget's zones stop being tappable directly.

This task is pure mechanical prep, and must still pass against **today's** unmodified `scene_illustration.dart` — it's not testing new behavior yet, just switching the tap mechanism so Task 3's implementation change doesn't also have to rewrite these assertions.

- [ ] **Step 1: Switch the interaction assertion in `scene_illustration_test.dart`**

In `test/presentation/widgets/scene_illustration_test.dart`, replace (around line 99):

```dart
    await tester.tap(zoneFinder);
    await tester.pump();
    expect(audio.playedFiles, [cachedScene.audioPathFor(ball)]);
```

with:

```dart
    await tester.tapAt(tester.getCenter(zoneFinder));
    await tester.pump();
    expect(audio.playedFiles, [cachedScene.audioPathFor(ball)]);
```

(The geometry assertions above it — `topLeft`, `size` — are unchanged.)

- [ ] **Step 2: Switch the five zone taps in `scene_screen_test.dart`**

In `test/presentation/screens/scene_screen_test.dart`, replace each of these five lines:

Line 156:
```dart
    await tester.tap(find.byKey(const ValueKey('object_zone_cat'))); // wrong
```
→
```dart
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('object_zone_cat')))); // wrong
```

Line 160:
```dart
    await tester.tap(find.byKey(const ValueKey('object_zone_ball'))); // correct
```
→
```dart
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('object_zone_ball')))); // correct
```

Line 164:
```dart
    await tester.tap(find.byKey(const ValueKey('object_zone_cat'))); // correct, last
```
→
```dart
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('object_zone_cat')))); // correct, last
```

Line 321 (inside the top-left-corner overlap test):
```dart
    await tester.tap(cornerZoneFinder);
```
→
```dart
    await tester.tapAt(tester.getCenter(cornerZoneFinder));
```

Line 387 (inside the top-right-corner overlap test):
```dart
      await tester.tap(cornerZoneFinder);
```
→
```dart
      await tester.tapAt(tester.getCenter(cornerZoneFinder));
```

(All the `getRect`/`overlaps` geometry assertions in both of those tests are unchanged — only the final "is it actually reachable" tap call changes.)

- [ ] **Step 3: Run both files and confirm everything still passes**

Run: `flutter test test/presentation/widgets/scene_illustration_test.dart test/presentation/screens/scene_screen_test.dart`
Expected: all tests PASS (this is prep only — today's `GestureDetector`-per-zone code handles a plain `tapAt` at the zone's center exactly like `tester.tap` on the zone widget itself).

- [ ] **Step 4: Commit**

```bash
git add test/presentation/widgets/scene_illustration_test.dart test/presentation/screens/scene_screen_test.dart
git commit -m "test: switch object-zone taps to coordinate-based tapAt"
```

---

### Task 2: Add slide/re-entry/multitouch tests, then implement the Listener-based hit test

**Files:**
- Modify: `test/presentation/widgets/scene_illustration_test.dart` (add three new `testWidgets` cases)
- Modify: `lib/presentation/widgets/scene_illustration.dart` (replace per-object `GestureDetector` zones with a single `Listener` + manual hit-testing)

**Interfaces:**
- Consumes: `SceneObject` (`lib/domain/models/scene_object.dart`, fields `id`, `label`, `audio`, `rect`), `ObjectRect` (fields `x`, `y`, `width`, `height`, all normalized 0..1 doubles), `CachedScene.scene.objects` (`List<SceneObject>`), `SceneController.onObjectTapped(SceneObject)` (existing method, unchanged).
- Produces: `SceneIllustration` keeps its public API exactly as-is (`const SceneIllustration({required CachedScene cachedScene})`) — this is an internal-only change, nothing outside this widget depends on its new private state.

The three new tests must fail against today's implementation (Step 1), confirming they actually exercise the new behavior, before you implement it (Step 3).

- [ ] **Step 1: Add the three new tests to `scene_illustration_test.dart`**

Add a second object next to the existing `ball` at the top of `main()` (right after the existing `const ball = ...;` declaration):

```dart
  const cat = SceneObject(
    id: 'cat',
    label: 'Кот',
    audio: 'cat.wav',
    rect: ObjectRect(x: 0.5, y: 0.5, width: 0.1, height: 0.2),
  );
```

With the file's existing 800×800 surface / 400×300 image / 100px-top-letterbox setup, `ball` renders at screen rect `[200, 400, 280, 520]` (center `240, 460`) and `cat` at `[400, 400, 480, 520]` (center `440, 460`) — there's empty space between them around `x=340`. The three new tests below rely on those exact numbers.

Add these three `testWidgets` cases inside `main()`, after the existing two:

```dart
  testWidgets(
    "a finger sliding through several objects without lifting plays each one's audio in order",
    (tester) async {
      late Directory tempDir;
      late CachedScene cachedScene;
      final audio = FakeAudioSink();

      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('yandee_illustration_slide_test_');
        await writeFixturePng(tempDir, 'background.png', width: 400, height: 300);

        cachedScene = CachedScene(
          scene: Scene(
            id: 'demo',
            version: 1,
            title: 'Демо',
            minAgeMonths: 12,
            background: 'background.png',
            objects: [ball, cat],
          ),
          directoryPath: tempDir.path,
        );

        await tester.pumpWidget(MaterialApp(
          home: SizedBox(
            width: 800,
            height: 800,
            child: ChangeNotifierProvider(
              create: (_) => SceneController(cachedScene: cachedScene, audioSink: audio),
              child: SceneIllustration(cachedScene: cachedScene),
            ),
          ),
        ));

        for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      addTearDown(() => tempDir.delete(recursive: true));

      final gesture = await tester.createGesture();
      await gesture.down(const Offset(240, 460)); // inside ball
      await tester.pump();
      await gesture.moveTo(const Offset(340, 460)); // empty gap between the two
      await tester.pump();
      await gesture.moveTo(const Offset(440, 460)); // inside cat
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(audio.playedFiles, [
        cachedScene.audioPathFor(ball),
        cachedScene.audioPathFor(cat),
      ]);
    },
  );

  testWidgets(
    'leaving an object and coming back to it plays its audio again, but moving within it does not repeat',
    (tester) async {
      late Directory tempDir;
      late CachedScene cachedScene;
      final audio = FakeAudioSink();

      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('yandee_illustration_reentry_test_');
        await writeFixturePng(tempDir, 'background.png', width: 400, height: 300);

        cachedScene = CachedScene(
          scene: Scene(
            id: 'demo',
            version: 1,
            title: 'Демо',
            minAgeMonths: 12,
            background: 'background.png',
            objects: [ball],
          ),
          directoryPath: tempDir.path,
        );

        await tester.pumpWidget(MaterialApp(
          home: SizedBox(
            width: 800,
            height: 800,
            child: ChangeNotifierProvider(
              create: (_) => SceneController(cachedScene: cachedScene, audioSink: audio),
              child: SceneIllustration(cachedScene: cachedScene),
            ),
          ),
        ));

        for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      addTearDown(() => tempDir.delete(recursive: true));

      final gesture = await tester.createGesture();
      await gesture.down(const Offset(240, 460)); // inside ball
      await tester.pump();
      await gesture.moveTo(const Offset(260, 460)); // still inside ball
      await tester.pump();
      expect(audio.playedFiles, [cachedScene.audioPathFor(ball)]); // only once so far

      await gesture.moveTo(const Offset(340, 460)); // outside, empty space
      await tester.pump();
      await gesture.moveTo(const Offset(240, 460)); // back inside ball
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(audio.playedFiles, [
        cachedScene.audioPathFor(ball),
        cachedScene.audioPathFor(ball),
      ]);
    },
  );

  testWidgets(
    'two fingers touching different objects at the same time both play their audio',
    (tester) async {
      late Directory tempDir;
      late CachedScene cachedScene;
      final audio = FakeAudioSink();

      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('yandee_illustration_multitouch_test_');
        await writeFixturePng(tempDir, 'background.png', width: 400, height: 300);

        cachedScene = CachedScene(
          scene: Scene(
            id: 'demo',
            version: 1,
            title: 'Демо',
            minAgeMonths: 12,
            background: 'background.png',
            objects: [ball, cat],
          ),
          directoryPath: tempDir.path,
        );

        await tester.pumpWidget(MaterialApp(
          home: SizedBox(
            width: 800,
            height: 800,
            child: ChangeNotifierProvider(
              create: (_) => SceneController(cachedScene: cachedScene, audioSink: audio),
              child: SceneIllustration(cachedScene: cachedScene),
            ),
          ),
        ));

        for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      addTearDown(() => tempDir.delete(recursive: true));

      final leftHand = await tester.createGesture(pointer: 1);
      final rightHand = await tester.createGesture(pointer: 2);
      await leftHand.down(const Offset(240, 460)); // inside ball
      await tester.pump();
      await rightHand.down(const Offset(440, 460)); // inside cat, simultaneously
      await tester.pump();
      await leftHand.up();
      await rightHand.up();
      await tester.pump();

      expect(audio.playedFiles, [
        cachedScene.audioPathFor(ball),
        cachedScene.audioPathFor(cat),
      ]);
    },
  );
```

- [ ] **Step 2: Run the new tests and confirm they fail**

Run: `flutter test test/presentation/widgets/scene_illustration_test.dart`
Expected: the two pre-existing tests PASS; the three new ones FAIL — sliding/re-entering/second-finger touches don't dispatch to zones they weren't pressed down on, so `audio.playedFiles` won't match (e.g. the slide test will only have `ball`'s file, not `[ball, cat]`).

- [ ] **Step 3: Replace the per-object `GestureDetector` zones with a `Listener` + manual hit test**

Replace the full contents of `lib/presentation/widgets/scene_illustration.dart` with:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/cached_scene.dart';
import '../../domain/models/scene_object.dart';
import '../controllers/scene_controller.dart';

class SceneIllustration extends StatefulWidget {
  const SceneIllustration({super.key, required this.cachedScene});

  final CachedScene cachedScene;

  @override
  State<SceneIllustration> createState() => _SceneIllustrationState();
}

class _SceneIllustrationState extends State<SceneIllustration> {
  late final ImageProvider _imageProvider;
  ImageStreamListener? _listener;
  Size? _imageSize;
  bool _hasError = false;

  // Which object each active pointer (finger) is currently over, keyed by
  // Flutter's PointerEvent.pointer id. Absent/null means "over empty
  // space". Tracked per-pointer so two simultaneous touches (e.g. a child
  // holding the phone with one hand while the other slides across the
  // picture) are followed independently.
  final Map<int, String?> _activeObjectIdByPointer = {};

  @override
  void initState() {
    super.initState();
    _imageProvider = FileImage(File(widget.cachedScene.backgroundPath));
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
      },
      onError: (exception, stackTrace) {
        // A missing/corrupt background.png must not spin forever with no
        // user-visible feedback — surface a simple error state instead.
        if (!mounted) return;
        setState(() => _hasError = true);
      },
    );
    _imageProvider.resolve(const ImageConfiguration()).addListener(_listener!);
  }

  @override
  void dispose() {
    _imageProvider.resolve(const ImageConfiguration()).removeListener(_listener!);
    super.dispose();
  }

  /// The object whose rect (scaled to [size]) contains [localPosition], or
  /// null if none does. Objects are checked last-to-first so that, when
  /// rects overlap, the one later in `scene.objects` wins — the same
  /// "painted on top" priority the old Stack ordering gave it.
  SceneObject? _objectAt(Offset localPosition, Size size) {
    for (final object in widget.cachedScene.scene.objects.reversed) {
      final rect = Rect.fromLTWH(
        object.rect.x * size.width,
        object.rect.y * size.height,
        object.rect.width * size.width,
        object.rect.height * size.height,
      );
      if (rect.contains(localPosition)) return object;
    }
    return null;
  }

  // Shared by onPointerDown/onPointerMove: whenever this pointer's current
  // object differs from what it was last time (including from/to empty
  // space), record the new one and — only when it just entered a real
  // object — dispatch the tap. This is what makes a plain tap and a finger
  // sliding through several objects without lifting behave the same way:
  // both are just "this pointer just entered object X".
  void _handlePointerActivity(PointerEvent event, Size size) {
    final object = _objectAt(event.localPosition, size);
    final previousId = _activeObjectIdByPointer[event.pointer];
    if (object?.id == previousId) return;
    _activeObjectIdByPointer[event.pointer] = object?.id;
    if (object != null) {
      context.read<SceneController>().onObjectTapped(object);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _activeObjectIdByPointer.remove(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, size: 64, color: Colors.grey),
            SizedBox(height: 8),
            Text('Не удалось загрузить изображение'),
          ],
        ),
      );
    }
    final imageSize = _imageSize;
    if (imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Only watched so this widget rebuilds when the controller changes;
    // object taps are dispatched via context.read in the pointer handlers
    // above, not through a value read during build.
    context.watch<SceneController>();
    return Center(
      child: AspectRatio(
        aspectRatio: imageSize.width / imageSize.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                Image(image: _imageProvider, fit: BoxFit.fill),
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) => _handlePointerActivity(event, size),
                    onPointerMove: (event) => _handlePointerActivity(event, size),
                    onPointerUp: _handlePointerEnd,
                    onPointerCancel: _handlePointerEnd,
                  ),
                ),
                // Inert geometry markers only — no gesture handling of
                // their own (IgnorePointer keeps them out of hit-testing
                // entirely, so they never shadow the Listener above).
                // Widget tests use their keys/rects to find and measure a
                // given object's tap zone.
                for (final object in widget.cachedScene.scene.objects)
                  Positioned(
                    key: ValueKey('object_zone_${object.id}'),
                    left: object.rect.x * size.width,
                    top: object.rect.y * size.height,
                    width: object.rect.width * size.width,
                    height: object.rect.height * size.height,
                    child: const IgnorePointer(child: SizedBox.shrink()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the illustration tests and confirm everything passes**

Run: `flutter test test/presentation/widgets/scene_illustration_test.dart`
Expected: all 5 tests PASS (the 2 pre-existing + the 3 new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/scene_illustration.dart test/presentation/widgets/scene_illustration_test.dart
git commit -m "feat: play object audio on slide-through and multi-finger touch, not just tap-in-place"
```

---

### Task 3: Full regression pass

**Files:** none (verification only; fix forward in the files above if something breaks).

**Interfaces:** none — this task only runs the existing suite.

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: PASS, same total test count as before this plan started plus the 3 new tests from Task 2 (in particular `test/presentation/screens/scene_screen_test.dart` — its Task 1 `tapAt`-based taps must now be landing on the new `Listener`, not the old per-zone `GestureDetector`).

If anything in `scene_screen_test.dart` fails: re-check that `tester.getCenter(...)` for the affected finder lands inside the object's rect (not exactly on an edge/corner pixel, which floating-point rounding could occasionally push just outside) — nudge the fixture's `rect` in that test's scene JSON slightly if so, rather than changing the widget.

- [ ] **Step 2: Run static analysis**

Run: `dart analyze lib/ test/`
Expected: `No issues found!`

- [ ] **Step 3: Commit if Step 1 or 2 required any fixes**

```bash
git add -A
git commit -m "fix: address regressions found in full test suite after slide-to-explore change"
```

If no fixes were needed, skip this step — there's nothing to commit.

## Self-Review Notes

- **Spec coverage:** §3's enter/leave/re-entry/independent-pointer table is covered by Task 2's three new tests plus the pre-existing tap test. §4's `Listener` + `Map<int, String?>` + reverse-order `_objectAt` are implemented verbatim in Task 2 Step 3. §5's testing plan (coordinate-based taps, slide test, two-pointer test, re-entry test) is Tasks 1–2. The "what doesn't change" list (§2/§4) is honored — no other file is touched.
- **Placeholder scan:** no TBDs; every step has literal code or an exact command.
- **Type consistency:** `SceneObject`, `ObjectRect`, `CachedScene`, `SceneController.onObjectTapped(SceneObject)`, `cachedScene.audioPathFor(SceneObject)` are used identically to their existing signatures throughout — no renames introduced.
