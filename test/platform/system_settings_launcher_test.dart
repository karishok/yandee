import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/platform/system_settings_launcher.dart';

void main() {
  test('returns false when opening settings fails asynchronously', () async {
    expect(await openGuidedAccessSettings(), isFalse);
  });
}
