// Pictures are assembled from SVG fragments; joining them with `+` reads better
// than nesting interpolations.
// ignore_for_file: prefer_interpolation_to_compose_strings

import 'dart:math' as math;

import '../../domain/shapes/shape_kind.dart';
import '../../domain/shapes/shape_picture.dart';
import 'shape_geometry.dart';

/// The drawings of the "Фигурки" game, carried over from the prototype
/// (`docs/prototypes/shapes.html`) as SVG text in card units (300 × 300).
/// Pieces look like painted wooden toys: a darker edge underneath, light
/// from above, faint grain and a soft shine — the warm style of the scenes.

const shapesInk = '#2b211a';
const _hint = '#ffb21a';

String _n(double value) => svgNumber(value);

/// Blends two `#rrggbb` colours: t = 0 gives [a], t = 1 gives [b].
String mixHex(String a, String b, double t) {
  final pa = int.parse(a.substring(1), radix: 16), pb = int.parse(b.substring(1), radix: 16);
  String channel(int shift) {
    final value = (((pa >> shift) & 255) * (1 - t) + ((pb >> shift) & 255) * t).round();
    return value.toRadixString(16).padLeft(2, '0');
  }
  return '#${channel(16)}${channel(8)}${channel(0)}';
}

/// The tones a painted wooden piece is drawn with.
class Shades {
  const Shades(this.fill, this.light, this.side, this.line);
  final String fill;
  final String light;
  final String side;
  final String line;
}

Shades shadesOf(String fill) => Shades(
      fill,
      mixHex(fill, '#fff8ec', .38),
      mixHex(fill, '#3b2410', .32),
      mixHex(fill, '#3b2410', .62),
    );

/// Toy paint, warm like the scenes.
abstract final class ToyColors {
  static const red = '#e2553f';
  static const blue = '#3f8fd8';
  static const yellow = '#f6c447';
  static const green = '#5daa4f';
  static const darkGreen = '#3f8a45';
  static const orange = '#f08a3a';
  static const purple = '#9a6cc9';
  static const pink = '#ef8fb0';
  static const brown = '#a8703f';
  static const lightBlue = '#7cc6e8';
  static const white = '#f7f1e6';
  static const black = '#4a4038';
  static const cone = '#e0b06a';
  static const skin = '#f8d9b8';
  static const silver = '#ebe5da';
}

/// Small moving things that appear when a picture comes alive.
enum EffectKind { puff, bubble, twinkle, glow, flame, risingHeart, zz, cherry, sparkle, speedLines }

class PictureEffect {
  const PictureEffect(this.kind, this.x, this.y, {this.color = '#fff7b0', this.delay = 0, this.size = 1});
  final EffectKind kind;
  final double x;
  final double y;
  final String color;

  /// Seconds after the picture comes alive before this one starts.
  final double delay;
  final double size;
}

/// How one slot is painted: its toy colour and the details drawn on it once
/// the piece is in (a face, a window, wheel hubs).
class SlotArt {
  const SlotArt(this.color, {this.details = ''});
  final String color;
  final String details;
}

class PictureArt {
  const PictureArt({
    required this.slots,
    required this.background,
    this.backdrop = '',
    this.dark = false,
    this.effects = const [],
  });

  final List<SlotArt> slots;

  /// The stand-in background, drawn until a painted one is in
  /// `assets/shapes/backgrounds/`.
  final String background;

  /// Things that belong to the scene but move with the picture (the bear's
  /// ears, the mast, the kite's string) — over any background, under the
  /// pieces.
  final String backdrop;

  /// Dashed outlines are drawn light on this (night) background.
  final bool dark;

  final List<PictureEffect> effects;
}

// ------------------------------------------------------------- helpers

String _grad(String id, String top, String bottom) =>
    '<linearGradient id="$id" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="$top"/>'
    '<stop offset="1" stop-color="$bottom"/></linearGradient>';
String _sky(String top, String bottom) =>
    '<defs>${_grad('sky', top, bottom)}</defs><rect width="300" height="300" fill="url(#sky)"/>';
String _land(String id, String d, String top, String bottom) =>
    '<defs>${_grad(id, top, bottom)}</defs><path d="$d" fill="url(#$id)"/>';
String _sun(double x, double y, double r) =>
    '<defs><radialGradient id="sun"><stop offset="0" stop-color="#fffbe8"/><stop offset=".3" stop-color="#ffe7a6"/>'
    '<stop offset="1" stop-color="#ffe39a" stop-opacity="0"/></radialGradient></defs>'
    '<circle cx="${_n(x)}" cy="${_n(y)}" r="${_n(r)}" fill="url(#sun)"/>';
String _cloud(double x, double y, [double s = 1]) =>
    '<ellipse cx="${_n(x)}" cy="${_n(y + 4 * s)}" rx="${_n(30 * s)}" ry="${_n(10 * s)}" fill="#e8d9c6" opacity=".55"/>'
    '<g fill="#fffaf2"><ellipse cx="${_n(x)}" cy="${_n(y)}" rx="${_n(28 * s)}" ry="${_n(13 * s)}"/>'
    '<circle cx="${_n(x - 10 * s)}" cy="${_n(y - 8 * s)}" r="${_n(13 * s)}"/>'
    '<circle cx="${_n(x + 9 * s)}" cy="${_n(y - 11 * s)}" r="${_n(16 * s)}"/></g>';
String _bush(double x, double y, [double s = 1]) =>
    '<g stroke="#4e8a3c" stroke-width="2.5"><circle cx="${_n(x)}" cy="${_n(y)}" r="${_n(18 * s)}" fill="#6fae52"/>'
    '<circle cx="${_n(x + 18 * s)}" cy="${_n(y + 5 * s)}" r="${_n(13 * s)}" fill="#5f9f48"/></g>';
String _meadow(double y) =>
    _land('far', 'M0 236 Q70 212 150 232 T300 226 V300 H0Z', '#b9d991', '#9cc67a') +
    _land('near', 'M0 ${_n(y)} Q80 ${_n(y - 12)} 150 ${_n(y)} T300 ${_n(y - 4)} V300 H0Z', '#93c46a', '#6fa84f');
String _dots(List<(double, double, double)> dots, [String color = '#fffaf2']) =>
    '<g fill="$color">${dots.map((d) => '<circle cx="${_n(d.$1)}" cy="${_n(d.$2)}" r="${_n(d.$3)}"/>').join()}</g>';
String _eyes(double x1, double x2, double y, {double r = 7, String color = shapesInk}) =>
    '<circle cx="${_n(x1)}" cy="${_n(y)}" r="${_n(r)}" fill="$color"/><circle cx="${_n(x2)}" cy="${_n(y)}" r="${_n(r)}" fill="$color"/>'
    '<circle cx="${_n(x1 + r * .35)}" cy="${_n(y - r * .4)}" r="${_n(r * .32)}" fill="#fff"/>'
    '<circle cx="${_n(x2 + r * .35)}" cy="${_n(y - r * .4)}" r="${_n(r * .32)}" fill="#fff"/>';
String _smile(double x1, double x2, double y, double depth, {String color = shapesInk, double width = 4}) =>
    '<path d="M${_n(x1)} ${_n(y)} Q${_n((x1 + x2) / 2)} ${_n(y + depth)} ${_n(x2)} ${_n(y)}" '
    'stroke="$color" stroke-width="${_n(width)}" fill="none" stroke-linecap="round"/>';
String _starFace(CardBox b) {
  final cx = b.x + b.width / 2, cy = b.y + b.height * .58, k = b.width / 76;
  return _eyes(cx - 9 * k, cx + 9 * k, cy - 3 * k, r: 3.6 * k, color: '#7a5200') +
      _smile(cx - 6 * k, cx + 6 * k, cy + 6 * k, 6 * k, color: '#7a5200', width: 3);
}

// ------------------------------------------------------------- pictures

final Map<String, PictureArt> _art = {
  'ice_cream': PictureArt(
    background: _sky('#fff4e8', '#ffe3cf') +
        [for (var i = 0; i < 10; i++) '<rect x="${i * 30}" width="30" height="30" fill="${i.isOdd ? '#fff8f0' : '#f4a7a0'}"/><circle cx="${i * 30 + 15}" cy="30" r="15" fill="${i.isOdd ? '#fff8f0' : '#f4a7a0'}"/>'].join() +
        _land('table', 'M0 252 H300 V300 H0Z', '#d9a066', '#b97f48') +
        '<path d="M0 252 H300" stroke="#9a6234" stroke-width="3"/>' +
        _dots(const [(40, 90, 5), (262, 110, 4), (34, 200, 4), (266, 210, 5), (56, 140, 3), (246, 160, 3)], '#f6c8c0'),
    slots: [
      const SlotArt(ToyColors.cone,
          details: '<path d="M116 152 L150 224 M138 152 L160 198 M162 152 L140 198 M184 152 L150 224" '
              'stroke="#b27f32" stroke-width="3" opacity=".55" stroke-linecap="round" fill="none"/>'),
      SlotArt(ToyColors.pink,
          details: _eyes(132, 168, 110) +
              _smile(136, 164, 130, 12) +
              '<circle cx="118" cy="128" r="8" fill="#ff4f8f" opacity=".3"/><circle cx="182" cy="128" r="8" fill="#ff4f8f" opacity=".3"/>'
                  '<g stroke-linecap="round" stroke-width="5"><path d="M116 76 l9 -4" stroke="#ffc929"/><path d="M150 64 l2 9" stroke="#6fd0f6"/>'
                  '<path d="M180 78 l8 4" stroke="#36b95a"/><path d="M102 98 l6 6" stroke="#9b5de5"/><path d="M198 100 l-5 7" stroke="#fff"/></g>'),
    ],
    effects: const [PictureEffect(EffectKind.cherry, 150, 52)],
  ),
  'house': PictureArt(
    background: _sky('#cfe6f5', '#fdf3e3') + _sun(252, 48, 56) + _cloud(64, 64) + _cloud(190, 34, .7) + _meadow(262) + _bush(18, 262) + _bush(262, 262, .9),
    backdrop: '<rect x="186" y="48" width="28" height="62" rx="3" fill="#c66a4a" stroke="#7d3c25" stroke-width="3"/>',
    slots: const [
      SlotArt(ToyColors.yellow,
          details: '<rect x="168" y="212" width="42" height="73" rx="8" fill="#a86d3e" stroke="#6b3f1d" stroke-width="3"/>'
              '<circle cx="200" cy="250" r="4.5" fill="#ffc929"/>'),
      SlotArt(ToyColors.red),
      SlotArt(ToyColors.lightBlue, details: '<path d="M126 167 V221 M99 194 H153" stroke="#fff" stroke-width="5" stroke-linecap="round"/>'),
    ],
    effects: const [
      PictureEffect(EffectKind.puff, 200, 42),
      PictureEffect(EffectKind.puff, 200, 42, delay: .5),
      PictureEffect(EffectKind.puff, 200, 42, delay: 1.05),
      PictureEffect(EffectKind.glow, 126, 194),
    ],
  ),
  'car': PictureArt(
    background: _sky('#cfe6f5', '#fdf3e3') + _cloud(70, 55) + _cloud(232, 84, .7) +
        '<g opacity=".55"><rect x="14" y="150" width="34" height="80" fill="#e6c9a8"/><rect x="52" y="176" width="28" height="54" fill="#f0d6b8"/>'
            '<rect x="228" y="160" width="30" height="70" fill="#e6c9a8"/><rect x="262" y="184" width="30" height="46" fill="#f0d6b8"/></g>' +
        _land('grass', 'M0 226 H300 V240 H0Z', '#93c46a', '#7fb35c') +
        _land('road', 'M0 238 H300 V300 H0Z', '#a69a90', '#8c8178') +
        '<path d="M10 272 H50 M90 272 H130 M170 272 H210 M250 272 H290" stroke="#fff8f0" stroke-width="6" stroke-linecap="round"/>',
    slots: [
      SlotArt(ToyColors.red,
          details: '<rect x="98" y="80" width="46" height="50" rx="10" fill="#b8ecff" stroke="#b8301f" stroke-width="3"/>'
                  '<rect x="156" y="80" width="52" height="50" rx="10" fill="#b8ecff" stroke="#b8301f" stroke-width="3"/>' +
              _eyes(172, 194, 106, r: 6) +
              _smile(170, 204, 168, 12, color: '#7a1d12') +
              '<circle cx="212" cy="148" r="8" fill="#ffe27a" stroke="#d99a00" stroke-width="3"/>'),
      const SlotArt(ToyColors.black, details: '<circle cx="103" cy="213" r="13" fill="#c9d1dc"/>'),
      const SlotArt(ToyColors.black, details: '<circle cx="203" cy="213" r="13" fill="#c9d1dc"/>'),
    ],
    effects: const [PictureEffect(EffectKind.speedLines, 50, 140)],
  ),
  'tree': PictureArt(
    background: _sky('#d8e8f3', '#f8f1e8') +
        _land('far', 'M0 236 Q90 214 170 234 T300 228 V300 H0Z', '#f4f7fa', '#e2e9f0') +
        _land('near', 'M0 254 Q150 236 300 254 V300 H0Z', '#ffffff', '#eef2f6') +
        _dots(const [(30, 40, 4), (270, 60, 5), (40, 180, 3), (262, 170, 4), (60, 110, 3), (240, 120, 3), (24, 226, 3), (282, 212, 3)]),
    slots: const [SlotArt(ToyColors.brown), SlotArt(ToyColors.darkGreen), SlotArt(ToyColors.green)],
    effects: const [
      PictureEffect(EffectKind.twinkle, 118, 182, color: '#ffc929'),
      PictureEffect(EffectKind.twinkle, 178, 168, color: '#ec4a3a', delay: .15),
      PictureEffect(EffectKind.twinkle, 150, 210, color: '#6fd0f6', delay: .3),
      PictureEffect(EffectKind.twinkle, 206, 214, color: '#ff7eb6', delay: .45),
      PictureEffect(EffectKind.twinkle, 96, 220, color: '#ffc929'),
      PictureEffect(EffectKind.twinkle, 150, 74, color: '#ec4a3a', delay: .15),
      PictureEffect(EffectKind.twinkle, 128, 104, color: '#6fd0f6', delay: .3),
      PictureEffect(EffectKind.twinkle, 174, 104, color: '#ffc929', delay: .45),
    ],
  ),
  'train': PictureArt(
    background: _sky('#cfe6f5', '#fdf3e3') + _sun(52, 46, 50) + _cloud(236, 50, .9) +
        _land('far', 'M0 230 Q80 206 160 228 T300 222 V300 H0Z', '#b9d991', '#9cc67a') +
        _land('near', 'M0 248 H300 V300 H0Z', '#93c46a', '#6fa84f') +
        '<g fill="#9a6234">${[for (var i = 0; i < 8; i++) '<rect x="${6 + i * 38}" y="252" width="22" height="12" rx="3"/>'].join()}</g>'
            '<rect y="250" width="300" height="6" fill="#8f8a86"/>',
    slots: [
      const SlotArt(ToyColors.red,
          details: '<path d="M46 140 V104 H38 V92 H78 V104 H70 V140" fill="#3a3a46" stroke="#16161d" stroke-width="3" stroke-linejoin="round"/>'
              '<path d="M110 141 V209" stroke="#b8301f" stroke-width="4"/>'
              '<circle cx="36" cy="160" r="7" fill="#ffe27a" stroke="#d99a00" stroke-width="3"/>'),
      SlotArt(ToyColors.blue,
          details: '<rect x="164" y="80" width="130" height="16" rx="7" fill="#1b55b5"/>'
                  '<rect x="196" y="110" width="68" height="48" rx="10" fill="#b8ecff" stroke="#1b55b5" stroke-width="3"/>' +
              _eyes(220, 242, 134, r: 6)),
      const SlotArt(ToyColors.black, details: '<circle cx="79" cy="217" r="12" fill="#c9d1dc"/>'),
      const SlotArt(ToyColors.black, details: '<circle cx="229" cy="217" r="12" fill="#c9d1dc"/>'),
    ],
    effects: const [
      PictureEffect(EffectKind.puff, 58, 86),
      PictureEffect(EffectKind.puff, 58, 86, delay: .5),
      PictureEffect(EffectKind.puff, 58, 86, delay: 1.05),
    ],
  ),
  'fish': PictureArt(
    background: _sky('#a7dcef', '#5fb0d4') +
        '<g fill="#fffaf2" opacity=".18"><path d="M40 0 L80 0 L30 300 L-10 300Z"/><path d="M170 0 L200 0 L170 300 L130 300Z"/></g>' +
        _land('sand', 'M0 268 Q150 250 300 268 V300 H0Z', '#f3dcae', '#e2c08a') +
        '<path d="M40 272 Q26 242 42 216 Q56 192 40 168" stroke="#5a9e48" stroke-width="10" fill="none" stroke-linecap="round"/>'
            '<path d="M262 274 Q276 248 260 222" stroke="#467f3a" stroke-width="10" fill="none" stroke-linecap="round"/>'
            '<g fill="#d9b98a"><ellipse cx="200" cy="276" rx="12" ry="6"/><ellipse cx="96" cy="282" rx="9" ry="5"/></g>'
            '<g fill="none" stroke="#fffaf2" stroke-width="3" opacity=".8"><circle cx="70" cy="60" r="8"/><circle cx="88" cy="36" r="5"/><circle cx="250" cy="70" r="6"/></g>',
    slots: [
      const SlotArt(ToyColors.yellow),
      SlotArt(ToyColors.orange,
          details: '<path d="M124 86 Q150 54 182 84" fill="#ffc929" stroke="#d99a00" stroke-width="3"/>'
                  '<path d="M118 122 q10 10 0 20 M138 114 q12 14 0 28 M138 152 q10 8 0 16" stroke="#c95f00" stroke-width="3" fill="none" opacity=".6"/>' +
              _smile(212, 230, 162, 8, color: '#7a3300')),
      const SlotArt(ToyColors.white, details: '<circle cx="197" cy="127" r="12" fill="$shapesInk"/><circle cx="201" cy="122" r="4" fill="#fff"/>'),
    ],
    effects: const [
      PictureEffect(EffectKind.bubble, 244, 140),
      PictureEffect(EffectKind.bubble, 244, 140, delay: .6, size: .8),
      PictureEffect(EffectKind.bubble, 244, 140, delay: 1.2, size: .65),
    ],
  ),
  'rocket': PictureArt(
    dark: true,
    background: _sky('#2a2f5c', '#4a3d70') +
        _dots(const [(30, 40, 2.5), (80, 20, 2), (60, 110, 2), (250, 140, 2.5), (280, 30, 2), (24, 190, 2), (270, 230, 2.5), (180, 270, 2), (100, 280, 2)], '#fff3c4') +
        _land('planet', 'M24 244 A24 24 0 1 0 72 244 A24 24 0 1 0 24 244Z', '#f6a85a', '#d0703a') +
        '<ellipse cx="48" cy="244" rx="40" ry="8" fill="none" stroke="#f6c447" stroke-width="5" transform="rotate(-18 48 244)"/>',
    slots: [
      const SlotArt(ToyColors.silver,
          details: '<path d="M106 196 L74 258 L106 248Z M194 196 L226 258 L194 248Z" fill="#ec4a3a" stroke="#b8301f" stroke-width="3" stroke-linejoin="round"/>'
              '<rect x="107" y="222" width="86" height="10" fill="#2f7cf0" opacity=".7"/>'),
      const SlotArt(ToyColors.red),
      const SlotArt(ToyColors.lightBlue, details: '<circle cx="150" cy="151" r="28" fill="none" stroke="#8e98a4" stroke-width="5"/>'),
      SlotArt(ToyColors.yellow, details: _starFace(const CardBox(204, 34, 78, 74))),
    ],
    effects: const [
      PictureEffect(EffectKind.flame, 150, 258),
      PictureEffect(EffectKind.sparkle, 198, 30),
      PictureEffect(EffectKind.sparkle, 286, 104, delay: .25),
    ],
  ),
  'bear': PictureArt(
    background: _sky('#d6ebf3', '#fbf3e2') + _sun(256, 44, 50) + _meadow(262) +
        [for (final (x, y, c) in const [(38.0, 270.0, '#ef8fb0'), (262.0, 272.0, '#f6c447'), (70.0, 286.0, '#9a6cc9'), (232.0, 288.0, '#ef8fb0')])
          '<circle cx="${_n(x)}" cy="${_n(y)}" r="7" fill="$c"/><circle cx="${_n(x)}" cy="${_n(y)}" r="3" fill="#fffaf2"/>'].join(),
    backdrop: '<g stroke="#5e3a1c" stroke-width="3.5"><circle cx="106" cy="62" r="22" fill="#a8703f"/><circle cx="194" cy="62" r="22" fill="#a8703f"/>'
        '<ellipse cx="120" cy="284" rx="22" ry="12" fill="#a8703f"/><ellipse cx="180" cy="284" rx="22" ry="12" fill="#a8703f"/></g>'
        '<circle cx="106" cy="62" r="10" fill="#e8b48a"/><circle cx="194" cy="62" r="10" fill="#e8b48a"/>',
    slots: [
      const SlotArt(ToyColors.brown,
          details: '<ellipse cx="150" cy="228" rx="40" ry="44" fill="#e8b48a" opacity=".75"/>'
              '<g fill="#a86d3e" stroke="#6b3f1d" stroke-width="4"><ellipse cx="92" cy="196" rx="15" ry="30" transform="rotate(28 92 196)"/>'
              '<ellipse cx="208" cy="196" rx="15" ry="30" transform="rotate(-28 208 196)"/></g>'),
      SlotArt(ToyColors.brown,
          details: '<ellipse cx="150" cy="124" rx="28" ry="22" fill="#e8b48a"/><ellipse cx="150" cy="113" rx="10" ry="7" fill="#3a2a2a"/>'
                  '<path d="M150 120 V128 M139 130 Q150 139 161 130" stroke="#3a2a2a" stroke-width="3.5" fill="none" stroke-linecap="round"/>' +
              _eyes(126, 174, 92, color: '#3a2a2a')),
      const SlotArt(ToyColors.red),
    ],
    effects: const [
      PictureEffect(EffectKind.risingHeart, 226, 96, color: '#ef8fb0'),
      PictureEffect(EffectKind.risingHeart, 72, 120, color: '#ef8fb0', delay: .7),
      PictureEffect(EffectKind.risingHeart, 238, 170, color: '#ef8fb0', delay: 1.4),
    ],
  ),
  'boat': PictureArt(
    background: _sky('#cfe6f5', '#fdf3e3') + _sun(250, 52, 52) + _cloud(62, 50, .9) +
        '<path d="M196 92 q10 -10 20 0 q10 -10 20 0" stroke="#76675a" stroke-width="4" fill="none" stroke-linecap="round"/>' +
        _land('sea', 'M0 238 Q25 228 50 238 T100 238 T150 238 T200 238 T250 238 T300 238 V300 H0Z', '#6dbbe0', '#3f8fbf') +
        '<path d="M0 266 Q25 258 50 266 T100 266 T150 266 T200 266 T250 266 T300 266" stroke="#a7dcef" stroke-width="5" fill="none"/>',
    backdrop: '<rect x="147" y="30" width="8" height="152" rx="3" fill="#8a5a33"/><path d="M155 32 L184 41 L155 50Z" fill="#e2553f"/>',
    slots: const [
      SlotArt(ToyColors.yellow),
      SlotArt(ToyColors.orange),
      SlotArt(ToyColors.red,
          details: '<g fill="#fff" stroke="#b8301f" stroke-width="3"><circle cx="105" cy="200" r="8"/><circle cx="150" cy="204" r="8"/><circle cx="195" cy="200" r="8"/></g>'),
    ],
  ),
  'kite': PictureArt(
    background: _sky('#bfe0f4', '#fdf1df') + _cloud(58, 70) + _cloud(246, 126, .8) + _meadow(272),
    backdrop: '<path d="M150 203 C150 230 110 250 40 275" stroke="#76675a" stroke-width="3" fill="none"/>',
    slots: [
      SlotArt(ToyColors.purple,
          details: '<path d="M150 28 V198 M86 113 H214" stroke="#6c35b0" stroke-width="3" opacity=".5"/>'
                  '<circle cx="134" cy="98" r="9" fill="#fff"/><circle cx="166" cy="98" r="9" fill="#fff"/>'
                  '<circle cx="135" cy="100" r="4.5" fill="$shapesInk"/><circle cx="167" cy="100" r="4.5" fill="$shapesInk"/>' +
              _smile(136, 164, 126, 12, color: '#fff')),
      const SlotArt(ToyColors.yellow),
      const SlotArt(ToyColors.green),
    ],
  ),
  'night_sky': PictureArt(
    dark: true,
    background: _sky('#232a55', '#3e3a6b') +
        _dots(const [(30, 200, 2), (120, 20, 2), (150, 140, 2), (280, 140, 2.5), (20, 30, 2), (110, 210, 2)], '#fff3c4') +
        _land('hills', 'M0 250 Q80 216 160 248 T300 240 V300 H0Z', '#34507a', '#26405e') +
        '<path d="M226 236 L250 216 L274 236Z" fill="#3a3340"/><rect x="230" y="234" width="40" height="30" fill="#3a3340"/>'
            '<rect x="244" y="241" width="12" height="12" fill="#ffe39a"/>',
    slots: [
      const SlotArt(ToyColors.yellow,
          details: '<path d="M58 94 Q66 101 76 94" stroke="#7a5200" stroke-width="4" fill="none" stroke-linecap="round"/>'
              '<path d="M64 124 Q72 130 80 122" stroke="#7a5200" stroke-width="4" fill="none" stroke-linecap="round"/>'
              '<circle cx="60" cy="110" r="6" fill="#ff7eb6" opacity=".5"/>'),
      SlotArt(ToyColors.yellow, details: _starFace(const CardBox(196, 40, 80, 76))),
      SlotArt(ToyColors.yellow, details: _starFace(const CardBox(170, 150, 66, 63))),
    ],
    effects: const [
      PictureEffect(EffectKind.zz, 104, 64),
      PictureEffect(EffectKind.zz, 118, 44, delay: .8, size: .7),
      PictureEffect(EffectKind.sparkle, 60, 230, delay: .1),
      PictureEffect(EffectKind.sparkle, 130, 180, delay: .35),
    ],
  ),
  'clown': PictureArt(
    background: _sky('#fff3e0', '#ffe6cd') +
        '<g fill="#f6d2c4" opacity=".7">${[for (var i = 0; i < 5; i++) '<rect x="${i * 60}" width="30" height="300"/>'].join()}</g>' +
        _land('floor', 'M0 262 H300 V300 H0Z', '#d9a066', '#b97f48'),
    backdrop: '<g fill="#f08a3a" stroke="#9a4f1c" stroke-width="3"><circle cx="72" cy="150" r="22"/><circle cx="62" cy="180" r="20"/>'
        '<circle cx="228" cy="150" r="22"/><circle cx="238" cy="180" r="20"/></g>'
        '<g fill="#7cc6e8" stroke="#3f7f9e" stroke-width="3"><circle cx="105" cy="272" r="18"/><circle cx="195" cy="272" r="18"/>'
        '<circle cx="135" cy="280" r="18"/><circle cx="165" cy="280" r="18"/></g>',
    slots: [
      SlotArt(ToyColors.skin,
          details: '<g fill="$shapesInk"><ellipse cx="124" cy="146" rx="7" ry="10"/><ellipse cx="176" cy="146" rx="7" ry="10"/></g>'
                  '<path d="M112 126 Q124 118 136 126 M164 126 Q176 118 188 126" stroke="$shapesInk" stroke-width="4" fill="none" stroke-linecap="round"/>' +
              _smile(118, 182, 222, 28, color: '#b8301f', width: 7)),
      const SlotArt(ToyColors.purple,
          details: '<g fill="#ffc929"><circle cx="138" cy="72" r="6"/><circle cx="164" cy="86" r="6"/><circle cx="152" cy="46" r="5"/></g>'
              '<circle cx="150" cy="10" r="11" fill="#fff" stroke="#8e98a4" stroke-width="3"/>'),
      const SlotArt(ToyColors.red),
      const SlotArt(ToyColors.pink),
      const SlotArt(ToyColors.pink),
    ],
  ),
};

PictureArt artOf(ShapePicture picture) => _art[picture.id]!;

// ------------------------------------------------------------- layers

const _svgOpen = '<svg xmlns="http://www.w3.org/2000/svg"';

// Where the shine sits on each upright shape, as a fraction of its box.
const Map<ShapeKind, (double, double)> _shine = {
  ShapeKind.circle: (.32, .3),
  ShapeKind.oval: (.3, .3),
  ShapeKind.square: (.26, .24),
  ShapeKind.rectangle: (.18, .3),
  ShapeKind.triangle: (.43, .58),
  ShapeKind.star: (.42, .44),
  ShapeKind.heart: (.27, .3),
  ShapeKind.semicircle: (.3, .62),
  ShapeKind.rhombus: (.4, .34),
  ShapeKind.crescent: (.2, .42),
};

/// A painted wooden piece in its slot.
String _pieceArt(ShapeSlot slot, String color) {
  final up = slot.upright;
  final w = up.width, h = up.height;
  final k = shadesOf(color);
  final d = shapePathData(slot.kind, w, h);
  final depth = math.max(4.0, math.min(w, h) * .06);
  final (sx, sy) = _shine[slot.kind]!;
  final grain = [
    for (final (i, t) in const [.28, .52, .76].indexed)
      'M${_n(-w * .05)} ${_n(h * t)}Q${_n(w * .3)} ${_n(h * t - 7 + i * 4)} ${_n(w * .55)} ${_n(h * t)}'
          'T${_n(w * 1.05)} ${_n(h * t + 2)}',
  ].join();
  final place = slotTransform(slot);
  return '<defs><linearGradient id="wood" x1="0" y1="0" x2="0" y2="1" gradientTransform="rotate(${-slot.quarterTurns * 90} .5 .5)">'
      '<stop offset="0" stop-color="${k.light}"/><stop offset=".55" stop-color="${k.fill}"/>'
      '<stop offset="1" stop-color="${mixHex(k.fill, k.side, .45)}"/></linearGradient>'
      '<radialGradient id="shine"><stop offset="0" stop-color="#fffdf6" stop-opacity=".8"/>'
      '<stop offset="1" stop-color="#fffdf6" stop-opacity="0"/></radialGradient>'
      '<clipPath id="cut"><path d="$d"/></clipPath></defs>'
      '<g transform="translate(0 ${_n(depth)})"><g transform="$place">'
      '<path d="$d" fill="${k.side}" stroke="${k.line}" stroke-width="3.5" stroke-linejoin="round"/></g></g>'
      '<g transform="$place"><path d="$d" fill="url(#wood)" stroke="${k.line}" stroke-width="3.5" stroke-linejoin="round"/>'
      '<g clip-path="url(#cut)"><path d="$grain" fill="none" stroke="${k.side}" stroke-width="1.6" opacity=".2"/>'
      '<ellipse cx="${_n(sx * w)}" cy="${_n(sy * h)}" rx="${_n(math.max(9, .24 * w))}" ry="${_n(math.max(6, .15 * h))}" fill="url(#shine)"/>'
      '</g></g>';
}

String _outlineArt(ShapeSlot slot, {required bool dark, required bool highlighted}) {
  final up = slot.upright;
  final String paint;
  if (highlighted) {
    paint = 'fill="rgba(255,248,236,.7)" stroke="$_hint" stroke-width="6"';
  } else if (dark) {
    paint = 'fill="#fff8ec" fill-opacity=".16" stroke="#fff3d6" stroke-opacity=".85" stroke-width="3" stroke-dasharray="9 7"';
  } else {
    paint = 'fill="#fff8f0" fill-opacity=".62" stroke="#a2896f" stroke-width="3" stroke-dasharray="9 7"';
  }
  return '<g transform="${slotTransform(slot)}"><path d="${shapePathData(slot.kind, up.width, up.height)}" $paint stroke-linejoin="round"/></g>';
}

/// The box a piece is drawn in on its own: the slot, a little margin and
/// room for its wooden edge underneath.
CardBox pieceFrame(ShapeSlot slot) =>
    CardBox(slot.box.x - 8, slot.box.y - 8, slot.box.width + 16, slot.box.height + 22);

/// One slot of [picture], as a full-card layer: the dashed place (lit up
/// when [highlighted]) or, once [filled], the piece and its details.
String slotLayerSvg(ShapePicture picture, int index, {required bool filled, bool highlighted = false}) {
  final slot = picture.slots[index];
  final art = artOf(picture);
  final body = filled
      ? _pieceArt(slot, art.slots[index].color) + art.slots[index].details
      : _outlineArt(slot, dark: art.dark, highlighted: highlighted);
  return '$_svgOpen viewBox="0 0 300 300">$body</svg>';
}

/// The piece for slot [index] on its own, framed by [pieceFrame] — for the
/// mat and for flight.
String pieceSvg(ShapePicture picture, int index) {
  final slot = picture.slots[index];
  final f = pieceFrame(slot);
  return '$_svgOpen viewBox="${_n(f.x)} ${_n(f.y)} ${_n(f.width)} ${_n(f.height)}">'
      '${_pieceArt(slot, artOf(picture).slots[index].color)}</svg>';
}

/// The stand-in background of [picture].
String backgroundSvg(ShapePicture picture) => '$_svgOpen viewBox="0 0 300 300">${artOf(picture).background}</svg>';

/// The scene bits that move with [picture], or an empty string.
String backdropSvg(ShapePicture picture) {
  final backdrop = artOf(picture).backdrop;
  return backdrop.isEmpty ? '' : '$_svgOpen viewBox="0 0 300 300">$backdrop</svg>';
}

/// Where a painted background for [picture] goes.
String backgroundAssetOf(ShapePicture picture) => 'assets/shapes/backgrounds/${picture.id}.jpg';

const Map<ShapeKind, (double, double, String)> _icons = {
  ShapeKind.circle: (22, 22, ToyColors.red),
  ShapeKind.triangle: (24, 21, ToyColors.yellow),
  ShapeKind.square: (20, 20, ToyColors.blue),
  ShapeKind.rectangle: (26, 15, ToyColors.green),
  ShapeKind.oval: (26, 18, ToyColors.orange),
  ShapeKind.star: (25, 24, ToyColors.yellow),
  ShapeKind.heart: (24, 22, ToyColors.pink),
  ShapeKind.semicircle: (26, 13, ToyColors.purple),
  ShapeKind.rhombus: (18, 26, ToyColors.lightBlue),
  ShapeKind.crescent: (24, 24, ToyColors.yellow),
};

/// The little icon of [kind] in the top bar: painted once [met], a dashed
/// outline before.
String kindIconSvg(ShapeKind kind, {required bool met}) {
  final (w, h, color) = _icons[kind]!;
  final k = shadesOf(color);
  final paint = met
      ? 'fill="${k.fill}" stroke="${k.line}" stroke-width="2"'
      : 'fill="none" stroke="#dcc2a2" stroke-width="2" stroke-dasharray="3 3"';
  return '$_svgOpen viewBox="-3 -3 34 34"><g transform="translate(${_n((28 - w) / 2)} ${_n((28 - h) / 2)})">'
      '<path d="${shapePathData(kind, w, h)}" $paint stroke-linejoin="round"/></g></svg>';
}
