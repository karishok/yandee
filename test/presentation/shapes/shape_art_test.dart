import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';
import 'package:yandee/presentation/shapes/shape_art.dart';
import 'package:yandee/presentation/shapes/shape_geometry.dart';

Future<void> _parses(WidgetTester tester, String svg, String what) async {
  final info = await tester.runAsync(() => vg.loadPicture(SvgStringLoader(svg), null));
  expect(info, isNotNull, reason: what);
  info!.picture.dispose();
}

void main() {
  test('numbers in SVG are short', () {
    expect(svgNumber(2), '2');
    expect(svgNumber(10.5), '10.5');
    expect(svgNumber(-3.04), '-3');
  });

  test('every shape has a closed outline with no gaps in the numbers', () {
    for (final kind in ShapeKind.values) {
      final d = shapePathData(kind, 120, 90);
      expect(d, startsWith('M'), reason: kind.name);
      expect(d, endsWith('Z'), reason: kind.name);
      expect(d, isNot(contains('NaN')), reason: kind.name);
      expect(d, isNot(contains('Infinity')), reason: kind.name);
    }
  });

  test('every picture has art for each of its slots', () {
    for (final picture in shapePictures) {
      expect(artOf(picture).slots, hasLength(picture.slots.length), reason: picture.id);
    }
  });

  test('a piece on the mat is framed with room for its wooden edge', () {
    const slot = ShapeSlot(ShapeKind.square, CardBox(10, 20, 100, 100));
    final frame = pieceFrame(slot);
    expect((frame.x, frame.y, frame.width, frame.height), (2.0, 12.0, 116.0, 122.0));
  });

  test('colours mix', () {
    expect(mixHex('#000000', '#ffffff', .5), '#808080');
    expect(shadesOf('#e2553f').fill, '#e2553f');
  });

  testWidgets('every layer of every picture is SVG flutter_svg can draw', (tester) async {
    for (final picture in shapePictures) {
      await _parses(tester, backgroundSvg(picture), '${picture.id} background');
      final backdrop = backdropSvg(picture);
      if (backdrop.isNotEmpty) await _parses(tester, backdrop, '${picture.id} backdrop');
      for (var i = 0; i < picture.slots.length; i++) {
        await _parses(tester, slotLayerSvg(picture, i, filled: false), '${picture.id} outline $i');
        await _parses(tester, slotLayerSvg(picture, i, filled: false, highlighted: true), '${picture.id} hint $i');
        await _parses(tester, slotLayerSvg(picture, i, filled: true), '${picture.id} piece $i');
        await _parses(tester, pieceSvg(picture, i), '${picture.id} mat piece $i');
      }
    }
    for (final kind in ShapeKind.values) {
      await _parses(tester, kindIconSvg(kind, met: true), '${kind.name} icon');
      await _parses(tester, kindIconSvg(kind, met: false), '${kind.name} icon outline');
    }
  });
}
