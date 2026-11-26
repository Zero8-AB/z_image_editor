import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/image_editor.dart';

// Synthetic versions of the photos from the auto-contrast study: cropped
// artworks as the editor sees them after the frame step. The region is the
// white paper, mat or wall of each photo (or the neutral part when there is
// no white). Run with AUTO_LEVELS_TABLE=1 to print the before/after table.

const _w = 160, _h = 200;

/// RGB float image, row-major.
class _Img {
  final Float64List px = Float64List(_w * _h * 3);

  void set(int x, int y, List<double> rgb) {
    final o = (y * _w + x) * 3;
    px[o] = rgb[0];
    px[o + 1] = rgb[1];
    px[o + 2] = rgb[2];
  }

  void fill(List<double> rgb, {int x0 = 0, int y0 = 0, int? x1, int? y1}) {
    for (var y = y0; y < (y1 ?? _h); y++) {
      for (var x = x0; x < (x1 ?? _w); x++) {
        set(x, y, rgb);
      }
    }
  }

  void circle(double cx, double cy, double r, List<double> rgb) {
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r) set(x, y, rgb);
      }
    }
  }

  _Img copy() => _Img()..px.setAll(0, px);

  /// Each pixel: v * mul + add (per channel).
  _Img map(List<double> mul, [double add = 0]) {
    final out = copy();
    for (var i = 0; i < px.length; i++) {
      out.px[i] = px[i] * mul[i % 3] + add;
    }
    return out;
  }

  /// Uneven room light: brightness from [top] to [bottom].
  _Img light(double top, double bottom) {
    final out = copy();
    for (var y = 0; y < _h; y++) {
      final f = top + (bottom - top) * y / (_h - 1);
      for (var i = y * _w * 3; i < (y + 1) * _w * 3; i++) {
        out.px[i] *= f;
      }
    }
    return out;
  }

  /// Sensor noise (deterministic), then 8 bits.
  Uint8List rgba({double sigma = 2.5, int seed = 5}) {
    final rnd = math.Random(seed);
    final out = Uint8List(_w * _h * 4);
    for (var i = 0; i < _w * _h; i++) {
      for (var c = 0; c < 3; c++) {
        // Sum of 4 uniforms: close enough to a Gaussian.
        var g = 0.0;
        for (var k = 0; k < 4; k++) {
          g += rnd.nextDouble() - 0.5;
        }
        final v = px[i * 3 + c] + sigma * g * math.sqrt(3);
        out[i * 4 + c] = v.clamp(0, 255).floor();
      }
      out[i * 4 + 3] = 255;
    }
    return out;
  }
}

/// The study's test painting: blue top, orange bottom, yellow sun, red and
/// green blocks.
_Img _painting(_Img into, int x0, int y0, int w, int h,
    {List<double> Function(List<double>)? tweak}) {
  void put(int x, int y, List<double> c) =>
      into.set(x0 + x, y0 + y, tweak == null ? c : tweak(c));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var c =
          y < h / 2 ? const [30.0, 90.0, 190.0] : const [225.0, 120.0, 40.0];
      final dx = x - w / 2, dy = y - h / 2;
      if (dx * dx + dy * dy <= (h / 5) * (h / 5)) c = const [240, 200, 60];
      if (x >= w / 8 && x < w * 3 / 8 && y >= h * 5 / 8 && y < h * 7 / 8) {
        c = const [160, 40, 40];
      }
      if (x >= w * 5 / 8 && x < w * 7 / 8 && y >= h / 8 && y < h * 3 / 8) {
        c = const [50, 110, 60];
      }
      put(x, y, c);
    }
  }
  return into;
}

typedef _Mask = bool Function(int x, int y);

class _Case {
  final String name;
  final Uint8List rgba;
  final _Mask region;
  const _Case(this.name, this.rgba, this.region);
}

bool _all(int x, int y) => true;

Map<String, _Case> _cases() {
  final out = <String, _Case>{};
  void add(String n, Uint8List rgba, _Mask m) => out[n] = _Case(n, rgba, m);

  // 1. Pencil drawing on white paper, warm room light, paper ~205.
  final paper = _Img()..fill(const [210, 205, 196]);
  final rnd = math.Random(5);
  for (var l = 0; l < 40; l++) {
    final ax = 15 + rnd.nextInt(130), ay = 15 + rnd.nextInt(130);
    final bx = 15 + rnd.nextInt(130), by = 15 + rnd.nextInt(160);
    const steps = 200;
    for (var s = 0; s <= steps; s++) {
      final x = (ax + (bx - ax) * s / steps).round();
      final y = (ay + (by - ay) * s / steps).round();
      paper.set(x, y, const [115, 112, 110]);
    }
  }
  add('White paper drawing', paper.light(1.0, 0.9).rgba(), _all);

  // 2. Pale watercolour on cream paper.
  final cream = _Img()
    ..fill(const [226, 214, 188])
    ..circle(80, 82, 38, const [150, 190, 200])
    ..circle(62, 120, 28, const [220, 180, 150]);
  add('Cream paper watercolour', cream.light(1.0, 0.9).rgba(),
      (x, y) => y < 30 || y >= 175);

  // 3. Blue/orange painting, white mat, black frame.
  final matted = _Img()
    ..fill(const [38, 36, 35])
    ..fill(const [222, 219, 214], x0: 10, y0: 10, x1: 150, y1: 190);
  _painting(matted, 30, 35, 100, 130);
  final matImg = matted.light(1.0, 0.9);
  bool mat(int x, int y) =>
      x >= 12 && x < 148 && ((y >= 12 && y < 32) || (y >= 168 && y < 188));
  add('Blue/orange painting, white mat', matImg.rgba(), mat);

  // 4. Blue-dominant painting on a white wall (no mat).
  final wall = _Img()..fill(const [211, 210, 208]);
  _painting(wall, 20, 25, 120, 150,
      tweak: (c) => [c[0], c[1], math.min(c[2] * 1.3 + 30, 250)]);
  bool wallTopBottom(int x, int y) => y < 22 || y >= 178;
  final wallImg = wall.light(1.0, 0.9);
  add('Painting on white wall', wallImg.rgba(), wallTopBottom);

  // 4b. Same, with stronger fall-off; the shaded lower wall (neutral
  // mid-tones) is measured.
  add('Same, shaded part of the wall', wall.light(1.0, 0.72).rgba(),
      (x, y) => y >= 180);

  // 5. Hazy version of 3 (veiling glare: contrast x0.55 + lift).
  add('Hazy painting, white mat',
      matImg.map(const [0.55, 0.55, 0.55], 75).rgba(sigma: 1.5), mat);

  // 6. White wall + a clipped window glare spot (> 0.5 % of the pixels).
  final glare = wallImg.copy()..circle(117, 50, 11, const [255, 255, 255]);
  add('White wall + glare spot', glare.rgba(), wallTopBottom);

  // 7. Warm tungsten light: the white mat is yellowish in the photo.
  add('Painting + mat, warm lamp', matImg.map(const [1.0, 0.93, 0.80]).rgba(),
      mat);

  // 8. Dark painting, no white anywhere.
  final dark = _painting(_Img(), 0, 0, _w, _h).map(const [0.45, 0.45, 0.45], 8);
  add('Dark painting, no white', dark.rgba(), _all);

  // 9. Like the real listing image: a warm painting whose blue channel never
  // gets bright (no white), with neutral grey stones.
  final listing = _Img()
    ..fill(const [235, 200, 150])
    ..fill(const [150, 100, 60], y0: 90, y1: 140)
    ..fill(const [120, 118, 118], y0: 140, y1: 180)
    ..fill(const [20, 15, 12], y0: 180);
  add('Real listing image (warm, no white)', listing.rgba(),
      (x, y) => y >= 142 && y < 178);
  return out;
}

// ── Measurements ───────────────────────────────────────────────────────────

/// sRGB (0..255) to CIE L*a*b* (D65), as OpenCV does for float input.
List<double> _lab(double r, double g, double b) {
  double lin(double c) {
    c /= 255;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final rl = lin(r), gl = lin(g), bl = lin(b);
  final x = (0.412453 * rl + 0.357580 * gl + 0.180423 * bl) / 0.950456;
  final y = 0.212671 * rl + 0.715160 * gl + 0.072169 * bl;
  final z = (0.019334 * rl + 0.119193 * gl + 0.950227 * bl) / 1.088754;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final l = y > 0.008856 ? 116 * math.pow(y, 1 / 3) - 16 : 903.3 * y;
  return [l.toDouble(), 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

class _Stats {
  final double l, b, chroma;
  const _Stats(this.l, this.b, this.chroma);
  @override
  String toString() => 'L* ${l.toStringAsFixed(1)}, b* ${b.toStringAsFixed(1)}'
      ', C ${chroma.toStringAsFixed(1)}';
}

_Stats _stats(Uint8List rgba, _Mask m) {
  var l = 0.0, b = 0.0, c = 0.0, n = 0;
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      if (!m(x, y)) continue;
      final o = (y * _w + x) * 4;
      final v = _lab(
          rgba[o].toDouble(), rgba[o + 1].toDouble(), rgba[o + 2].toDouble());
      l += v[0];
      b += v[2];
      c += math.sqrt(v[1] * v[1] + v[2] * v[2]);
      n++;
    }
  }
  return _Stats(l / n, b / n, c / n);
}

/// The photo with Auto applied (8 bits, like the export).
Uint8List _applied(ZAutoLevels a, Uint8List rgba) {
  final out = Uint8List.fromList(rgba);
  for (var i = 0; i < out.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      out[i + c] = a.apply(c, rgba[i + c].toDouble()).floor();
    }
  }
  return out;
}

int _lumaPercentile(Uint8List rgba, double q) {
  final v = <int>[
    for (var i = 0; i < rgba.length; i += 4)
      (299 * rgba[i] + 587 * rgba[i + 1] + 114 * rgba[i + 2]) ~/ 1000,
  ]..sort();
  return v[(q * (v.length - 1)).round()];
}

class _Result {
  final _Case c;
  final ZAutoLevels auto;
  final _Stats region0, region1, whole0, whole1;
  final Uint8List after;
  _Result(this.c, this.auto, this.region0, this.region1, this.whole0,
      this.whole1, this.after);
}

_Result _run(_Case c) {
  final a = ZAutoLevels.analyzeRgba(c.rgba, _w, _h);
  final after = _applied(a, c.rgba);
  return _Result(c, a, _stats(c.rgba, c.region), _stats(after, c.region),
      _stats(c.rgba, _all), _stats(after, _all), after);
}

void main() {
  final cases = _cases();
  final results = {for (final c in cases.values) c.name: _run(c)};
  _Result r(String name) => results[name]!;

  if (Platform.environment['AUTO_LEVELS_TABLE'] != null) {
    debugPrint('| image | region L* | region b* | mean chroma | gain | offset '
        '| hazy |');
    debugPrint('|---|---|---|---|---|---|:-:|');
    for (final x in results.values) {
      String f(double v) => v.toStringAsFixed(1);
      // ignore: deprecated_member_use_from_same_package
      final hazy = x.auto.hazy;
      debugPrint('| ${x.c.name} '
          '| ${f(x.region0.l)} → ${f(x.region1.l)} '
          '| ${f(x.region0.b)} → ${f(x.region1.b)} '
          '| ${f(x.whole0.chroma)} → ${f(x.whole1.chroma)} '
          '| ${x.auto.gain.map((g) => g.toStringAsFixed(3)).join(' / ')} '
          '| ${x.auto.offset.map(f).join(' / ')} '
          '| ${hazy ? 'yes' : 'no'} |');
    }
  }

  group('Auto is gentle (auto-contrast study)', () {
    test('never switches itself on', () {
      for (final x in results.values) {
        // ignore: deprecated_member_use_from_same_package
        expect(x.auto.hazy, isFalse, reason: x.c.name);
      }
    });

    test('white paper: lifted, not darkened or tinted', () {
      final x = r('White paper drawing');
      expect(x.region1.l, greaterThanOrEqualTo(x.region0.l - 1),
          reason: '${x.region0} → ${x.region1}');
      expect((x.region1.b - x.region0.b).abs(), lessThanOrEqualTo(3),
          reason: '${x.region0} → ${x.region1}');
    });

    test('cream paper watercolour: the paper does not drop > 1 L*', () {
      final x = r('Cream paper watercolour');
      expect(x.region0.l, closeTo(82, 3));
      expect(x.region1.l, greaterThanOrEqualTo(x.region0.l - 1),
          reason: '${x.region0} → ${x.region1}');
    });

    test('shaded white wall does not go yellow (b* change ≤ 3)', () {
      final x = r('Same, shaded part of the wall');
      expect((x.region1.b - x.region0.b).abs(), lessThanOrEqualTo(3),
          reason: '${x.region0} → ${x.region1}');
    });

    test('glare spot: the wall does not get darker', () {
      final x = r('White wall + glare spot');
      expect(x.region1.l, greaterThanOrEqualTo(x.region0.l - 1),
          reason: '${x.region0} → ${x.region1}');
      // The whole photo: the black cut may darken the darks a little.
      expect(x.whole1.l, greaterThanOrEqualTo(x.whole0.l - 2),
          reason: 'mean ${x.whole0} → ${x.whole1}');
    });

    test('dark painting: chroma does not explode', () {
      final x = r('Dark painting, no white');
      expect(x.whole1.chroma, lessThanOrEqualTo(x.whole0.chroma * 1.25),
          reason: '${x.whole0} → ${x.whole1}');
    });

    test('real listing image: the neutral greys do not turn blue', () {
      final x = r('Real listing image (warm, no white)');
      expect((x.region1.b - x.region0.b).abs(), lessThanOrEqualTo(3),
          reason: '${x.region0} → ${x.region1}');
    });

    test('hazy photo: still improved (mat lighter, wider range)', () {
      final x = r('Hazy painting, white mat');
      expect(x.region1.l, greaterThanOrEqualTo(x.region0.l + 5),
          reason: '${x.region0} → ${x.region1}');
      final range0 =
          _lumaPercentile(x.c.rgba, 0.99) - _lumaPercentile(x.c.rgba, 0.01);
      final range1 =
          _lumaPercentile(x.after, 0.99) - _lumaPercentile(x.after, 0.01);
      expect(range1, greaterThanOrEqualTo(range0 * 1.15),
          reason: 'luma range $range0 → $range1');
    });

    test('every white region: never > 1 L* darker, b* moves ≤ 3', () {
      for (final x in results.values) {
        // No white there: its darks may get a little darker.
        if (x.c.name == 'Dark painting, no white') continue;
        expect(x.region1.l, greaterThanOrEqualTo(x.region0.l - 1),
            reason: '${x.c.name}: ${x.region0} → ${x.region1}');
        expect((x.region1.b - x.region0.b).abs(), lessThanOrEqualTo(3),
            reason: '${x.c.name}: ${x.region0} → ${x.region1}');
      }
    });

    test('without a neutral white, one gain for all channels (hue kept)', () {
      for (final name in [
        'Dark painting, no white',
        'Real listing image (warm, no white)',
      ]) {
        final a = r(name).auto;
        expect(a.gain[1], closeTo(a.gain[0], 1e-9), reason: name);
        expect(a.gain[2], closeTo(a.gain[0], 1e-9), reason: name);
        expect(a.offset[1], closeTo(a.offset[0], 1e-9), reason: name);
        expect(a.offset[2], closeTo(a.offset[0], 1e-9), reason: name);
      }
    });
  });

  test('a near-black photo (99.5th luma percentile 0) is left alone', () {
    // 0.4 % of the pixels at 200, the rest black: the top percentile is 0.
    const w = 100, h = 100;
    final rgba = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      final v = i < 40 ? 200 : 0;
      rgba[i * 4] = v;
      rgba[i * 4 + 1] = v;
      rgba[i * 4 + 2] = v;
      rgba[i * 4 + 3] = 255;
    }
    final fix = ZAutoLevels.analyzeRgba(rgba, w, h);
    expect(fix.isNoop, isTrue, reason: 'gain ${fix.gain}');
    for (var c = 0; c < 3; c++) {
      expect(fix.apply(c, 200), greaterThanOrEqualTo(199));
    }
  });
}
