import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../platform/external_links.dart';
import '../widgets/play_timer_scope.dart';
import 'about_screen.dart';
import 'guided_access_screen.dart';

/// The parents menu, behind the parental gate: the play timer, locking the
/// device into Yandee, writing to us, rating the app, and About.
class ParentsScreen extends StatelessWidget {
  const ParentsScreen({super.key, this.openLink, this.readVersion, this.readInstaller, this.platform});

  final LinkOpener? openLink;
  final AppVersionReader? readVersion;

  /// Which store installed the build: an Android build from Google Play is
  /// rated there, not on RuStore.
  final InstallerStoreReader? readInstaller;

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
    String? installer;
    try {
      installer = await (readInstaller ?? readInstallerStore)();
    } catch (_) {
      installer = null;
    }
    final opened = await _openLink(storeReviewUri(platform ?? defaultTargetPlatform, installerStore: installer));
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
              MaterialPageRoute(builder: (_) => const GuidedAccessScreen()),
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
