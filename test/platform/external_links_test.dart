import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/platform/external_links.dart';

void main() {
  test('the feedback letter goes to the address on the site, with the version in its subject', () {
    final uri = feedbackMailUri('1.2.0 (5)');
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'babaliants@gmail.com');
    expect(uri.queryParameters['subject'], 'Yandee 1.2.0 (5)');
    expect(uri.toString(), isNot(contains('+')), reason: 'mail apps show a "+" literally');
  });

  test('rating opens the App Store on Apple devices and RuStore elsewhere', () {
    expect(storeReviewUri(TargetPlatform.iOS).toString(),
        'https://apps.apple.com/app/yandee/id6817918076?action=write-review');
    expect(storeReviewUri(TargetPlatform.macOS), storeReviewUri(TargetPlatform.iOS));
    expect(storeReviewUri(TargetPlatform.android).toString(), 'https://www.rustore.ru/catalog/app/com.yandee.yandee');
  });

  test('the terms page is the one on the site', () {
    expect(termsUri.toString(), 'https://yandee-app.ru/terms');
  });
}
