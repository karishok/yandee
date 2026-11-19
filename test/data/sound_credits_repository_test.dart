import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
