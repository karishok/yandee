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
