import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/scene_manifest_entry.dart';

void main() {
  test('SceneManifestEntry.fromJson parses all fields', () {
    final entry = SceneManifestEntry.fromJson({
      'id': 'city',
      'version': 3,
      'title': 'Город',
      'thumbnail': 'city/thumb.png',
    });
    expect(entry.id, 'city');
    expect(entry.version, 3);
    expect(entry.title, 'Город');
    expect(entry.thumbnail, 'city/thumb.png');
  });
}
