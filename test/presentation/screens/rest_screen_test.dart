import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/presentation/monsters/monster_art.dart';
import 'package:yandee/presentation/screens/rest_screen.dart';

import '../../support/asset_image_finder.dart';

void main() {
  testWidgets('the blue monster sleeps with its eyes shut', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RestScreen(playPhrase: () async {})));

    expect(find.text('Пора отдохнуть!'), findsOneWidget);
    final monster = findAssetImage(monsterPictureAsset(MonsterColor.blue, MonsterPicture.chomp));
    expect(monster, findsOneWidget);
    expect(tester.getSize(monster), const Size(200, 200));
  });
}
