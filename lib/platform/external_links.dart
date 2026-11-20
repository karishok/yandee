import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the parents menu sends people outside the app. The addresses are
/// the ones on the public site (website/README.md).
const feedbackEmail = 'babaliants@gmail.com';
final termsUri = Uri.parse('https://yandee-app.ru/terms');
final appStoreReviewUri = Uri.parse('https://apps.apple.com/app/yandee/id6817918076?action=write-review');
final ruStoreUri = Uri.parse('https://www.rustore.ru/catalog/app/com.yandee.yandee');
final googlePlayUri = Uri.parse('https://play.google.com/store/apps/details?id=com.yandee.yandee');

/// What Android reports as the installer of a build that came from Google Play.
const googlePlayInstaller = 'com.android.vending';

/// A letter to [feedbackEmail] whose subject says which version wrote it.
/// Spaces are encoded as %20: mail apps show a `+` literally.
Uri feedbackMailUri(String appVersion) => Uri(
      scheme: 'mailto',
      path: feedbackEmail,
      query: 'subject=${Uri.encodeComponent('Yandee $appVersion')}',
    );

/// The store page to rate the app on: the App Store on Apple devices; on
/// Android the store the build came from — Google Play when [installerStore]
/// says so, RuStore otherwise (it is also where a sideloaded build belongs).
Uri storeReviewUri(TargetPlatform platform, {String? installerStore}) => switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => appStoreReviewUri,
      _ => installerStore == googlePlayInstaller ? googlePlayUri : ruStoreUri,
    };

typedef LinkOpener = Future<bool> Function(Uri uri);
typedef AppVersionReader = Future<String> Function();
typedef InstallerStoreReader = Future<String?> Function();

/// Opens [uri] in the app that handles it (browser, mail, store). Returns
/// false instead of throwing when nothing could open it.
Future<bool> openExternalLink(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// The app's version as people see it in the store, with the build: `1.2.0 (5)`.
Future<String> readAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}

/// The store that installed this build, as the system names it
/// (`com.android.vending` for Google Play); null when it cannot tell.
Future<String?> readInstallerStore() async {
  final info = await PackageInfo.fromPlatform();
  return info.installerStore;
}
