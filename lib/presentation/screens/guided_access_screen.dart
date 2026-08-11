import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../../platform/system_settings_launcher.dart';

const _iosSteps = [
  'Настройки → Универсальный доступ → Направленный доступ — включите переключатель.',
  'Там же нажмите «Код-пароль» и задайте код (он понадобится, чтобы потом выйти из режима).',
  'Вернитесь в Yandee и откройте нужную сцену.',
  'Быстро нажмите три раза боковую кнопку (или кнопку «Домой» на моделях с ней).',
  'Нажмите «Начать» в углу экрана — готово, ребёнок больше не сможет случайно выйти из приложения.',
];

const _androidSteps = [
  'Настройки → Безопасность (иногда «Дополнительные настройки» → «Безопасность») → Закрепление приложения — включите его.',
  'Вернитесь в Yandee и откройте нужную сцену.',
  'Откройте экран последних приложений (кнопка ▢ или свайп вверх с удержанием).',
  'Нажмите на значок Yandee вверху карточки приложения и выберите «Закрепить».',
  'Готово — чтобы выйти, зажмите одновременно «Назад» и «Обзор» (на некоторых устройствах — потяните вверх и удерживайте).',
];

/// Plain-language, platform-aware instructions for turning on the OS's
/// "lock to just this app" feature — Guided Access on iOS, app pinning on
/// Android — plus a best-effort "Открыть настройки" shortcut. Neither OS
/// lets a third-party app finish the job itself (see
/// [openGuidedAccessSettings]), so the final toggle and gesture are always
/// left to whoever reads these steps; that's stated plainly rather than
/// silently failing to "just turn it on".
class GuidedAccessScreen extends StatefulWidget {
  const GuidedAccessScreen({super.key, Future<bool> Function()? openSettings})
      : openSettings = openSettings ?? openGuidedAccessSettings;

  final Future<bool> Function() openSettings;

  @override
  State<GuidedAccessScreen> createState() => _GuidedAccessScreenState();
}

class _GuidedAccessScreenState extends State<GuidedAccessScreen> {
  bool _opening = false;

  bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> _openSettings() async {
    setState(() => _opening = true);
    final opened = await widget.openSettings();
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть Настройки — открой их вручную.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _isApple ? _iosSteps : _androidSteps;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Блокировка на одном приложении')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _isApple
                ? 'В iOS это называется «Направленный доступ» (Guided Access). Он не даёт '
                    'выйти из приложения, пока вы сами это не разрешите.'
                : 'В Android это называется «Закрепление приложения». Оно не даёт выйти '
                    'из приложения, пока вы сами это не разрешите.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Шаги могут немного отличаться в зависимости от версии системы и производителя устройства.',
            style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colorScheme.primary,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(steps[i], style: textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Мы не можем включить это за вас: ни iOS, ни Android не позволяют '
            'приложениям делать это самостоятельно — последний шаг всегда '
            'выполняется вручную, это сделано специально из соображений безопасности.',
            style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            key: const ValueKey('open_system_settings_button'),
            onPressed: _opening ? null : _openSettings,
            icon: _opening
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.settings),
            label: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }
}
