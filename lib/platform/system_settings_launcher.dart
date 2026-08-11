import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';

/// Best-effort jump to a relevant system settings screen, for the "Открыть
/// настройки" shortcut on the Guided Access instructions screen.
///
/// Neither iOS nor Android exposes a public API for a third-party app to
/// turn on Guided Access / app pinning itself — both are deliberately
/// gated behind a hardware gesture the OS trusts (triple-click the side
/// button; long-press Recents) precisely so no app, this one included, can
/// lock a device into itself without the person holding it choosing to. So
/// this can only shorten the trip to the right settings screen; the actual
/// toggle and the final gesture are always left to whoever's following the
/// in-app instructions. Returns whether a settings screen was actually
/// opened, so the caller can tell the user to do it by hand if not.
Future<bool> openGuidedAccessSettings() async {
  try {
    if (Platform.isIOS || Platform.isMacOS) {
      // "app-settings:" is the one Apple-sanctioned deep link a
      // third-party app gets — there's no public API for a specific
      // subpage like Accessibility, so this lands on Settings' root (or
      // this app's own page); the in-app instructions cover the rest of
      // the path from there.
      return launchUrl(Uri(scheme: 'app-settings'), mode: LaunchMode.externalApplication);
    }
    if (Platform.isAndroid) {
      // ACTION_SECURITY_SETTINGS is a public, documented Android intent
      // action. On stock Android it opens the Security screen that hosts
      // "App pinning" — exact wording/location still varies by OEM and
      // OS version, which is why the instructions describe it too.
      const intent = AndroidIntent(action: 'android.settings.SECURITY_SETTINGS');
      await intent.launch();
      return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}
