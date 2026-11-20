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

  test('an Android build installed from Google Play is rated on Google Play', () {
    expect(storeReviewUri(TargetPlatform.android, installerStore: 'com.android.vending').toString(),
        'https://play.google.com/store/apps/details?id=com.yandee.yandee');
    expect(storeReviewUri(TargetPlatform.android, installerStore: 'ru.vk.store'), ruStoreUri);
    expect(storeReviewUri(TargetPlatform.iOS, installerStore: 'com.android.vending'), appStoreReviewUri);
  });

  test('the terms page is the one on the site', () {
    expect(termsUri.toString(), 'https://yandee-app.ru/terms');
  });
}
