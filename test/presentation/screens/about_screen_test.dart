import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/data/sound_credits_repository.dart';
import 'package:yandee/domain/models/sound_credit.dart';
import 'package:yandee/platform/external_links.dart';
import 'package:yandee/presentation/screens/about_screen.dart';

final _cow = SoundCreditLine(
  label: 'Корова',
  credit: SoundCredit(
    id: 'cow',
    scene: 'farm',
    artist: 'Secretlondon',
    license: 'CC BY-SA 3.0',
    page: Uri.parse('https://commons.wikimedia.org/wiki/File:Mudchute_cow_1.ogg'),
  ),
);

Future<List<Uri>> _pump(WidgetTester tester, {bool opens = true}) async {
  final opened = <Uri>[];
  await tester.pumpWidget(MaterialApp(
    home: AboutScreen(
      openLink: (uri) async {
        opened.add(uri);
        return opens;
      },
      readVersion: () async => '1.2.0 (5)',
      loadCredits: () async => [_cow],
    ),
  ));
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('shows the version and who recorded each sound', (tester) async {
    await _pump(tester);
    expect(find.text('Версия 1.2.0 (5)'), findsOneWidget);
    expect(find.text('Авторы звуков'), findsOneWidget);
    expect(find.text('Корова'), findsOneWidget);
    expect(find.text('Secretlondon · CC BY-SA 3.0'), findsOneWidget);
  });

  testWidgets('opens the terms page and a sound\'s own page', (tester) async {
    final opened = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('about_terms')));
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('about_credit_cow')), 100);
    await tester.tap(find.byKey(const ValueKey('about_credit_cow')));
    await tester.pump();
    expect(opened, [termsUri, _cow.credit.page]);
  });

  testWidgets('says so when a link could not be opened', (tester) async {
    await _pump(tester, opens: false);
    await tester.tap(find.byKey(const ValueKey('about_terms')));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось открыть ссылку'), findsOneWidget);
  });
}
