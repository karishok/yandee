import 'package:flutter/material.dart';

import 'guided_access_screen.dart';

/// The app's settings screen. Currently a single entry — instructions for
/// locking the device into Yandee (Guided Access / app pinning) — but kept
/// as its own screen (rather than a dialog off the scene list) so future
/// settings have somewhere to go without another redesign.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            key: const ValueKey('settings_guided_access_tile'),
            leading: const Icon(Icons.lock_outline),
            title: const Text('Блокировка на одном приложении'),
            subtitle: const Text('Чтобы ребёнок не мог случайно выйти из Yandee'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GuidedAccessScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
