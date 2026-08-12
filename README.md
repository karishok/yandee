# Yandee

Интерактивные обучающие сцены для детей 1–3 лет. Ребёнок открывает сцену
(статичная иллюстрация с ~10 объектами) и может:

- **«Исследовать»** — тапнуть объект, услышать его название.
- **«Найти»** — приложение просит найти конкретный объект.

Контент (иллюстрации, аудио) раздаётся со статического хостинга и кэшируется
локально — приложение полностью работает офлайн после первой загрузки.

Дизайн-документ: `docs/superpowers/specs/2026-08-11-yandee-interactive-scenes-design.md`.

## Структура

```
lib/
  domain/
    models/   — Scene, SceneObject, ObjectRect, SceneManifestEntry (зеркалят JSON-схему контента)
    modes/    — SceneMode/SceneModeEffects и реализации ExploreMode, FindMode
  data/       — ContentRepository (кэш + синхронизация с хостингом), DemoContentSeeder
  audio/      — AudioSink/AudioPlayerService
  presentation/
    controllers/ — SceneController
    screens/     — SceneListScreen, SceneScreen, SettingsScreen, GuidedAccessScreen
    widgets/     — SceneIllustration и др.
  platform/   — openGuidedAccessSettings() и другой код, завязанный на конкретную ОС
assets/
  audio/system/    — системные фразы (интро, подсказки, туш)
  demo_content/    — офлайн демо-сцена для первого запуска/ручной проверки
tool/
  generate_placeholder_assets.dart — генератор плейсхолдер-арта/аудио
  record_voiceover.dart — интерактивная запись реальной озвучки с микрофона;
    каждая сохранённая запись автоматически чистится от шума (см. ниже)
  denoise_audio.dart — чистит фоновый шум/шуршание в уже записанных .wav
    (`dart run tool/denoise_audio.dart [--dry-run]`); использует ту же
    спектральную шумоподавляющую логику, что и запись в реальном времени
```

## Запуск

```bash
flutter pub get
flutter test
flutter run
```
