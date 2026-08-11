import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'data/content_repository.dart';
import 'data/demo_content_seeder.dart';
import 'presentation/screens/scene_list_screen.dart';

/// Root of the static hosting endpoint that serves `index.json` and each
/// scene's files. Must end with a trailing slash — `Uri.resolve` treats a
/// URL's last path segment as a filename otherwise, and would silently
/// drop it when building request URLs. Point this at the real CDN once
/// content hosting is deployed; until then, requests simply fail and the
/// app falls back to its local (seeded demo) cache, per the offline
/// error-handling behavior in ContentRepository.refresh().
final kContentBaseUrl = Uri.parse('https://content.yandee.app/v1/');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YandeeApp());
}

class YandeeApp extends StatelessWidget {
  const YandeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final contentRepository = ContentRepository(
      httpClient: http.Client(),
      baseUrl: kContentBaseUrl,
      cacheRootProvider: getApplicationDocumentsDirectory,
    );
    return MaterialApp(
      title: 'Yandee',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.orange),
      home: _StartupScreen(contentRepository: contentRepository),
    );
  }
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen({required this.contentRepository});

  final ContentRepository contentRepository;

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  late final Future<void> _seeded = _seed();

  Future<void> _seed() async {
    final cacheRoot = await getApplicationDocumentsDirectory();
    await const DemoContentSeeder().seedIfEmpty(cacheRoot);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _seeded,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return SceneListScreen(contentRepository: widget.contentRepository);
      },
    );
  }
}
