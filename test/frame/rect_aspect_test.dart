import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:z_image_editor/z_image_editor.dart';

const imageSize = Size(4000, 3000);
const f = 3000.0; // ~27 mm equivalent

/// Projects a w x h rectangle (cm) rotated by [yaw]/[pitch] (degrees) at
/// [distance] in front of a pinhole camera with focal [f] px.
List<Offset> project(double w, double h,
    {double yaw = 0, double pitch = 0, double distance = 150, double cx = 0}) {
  final ya = yaw * math.pi / 180, pa = pitch * math.pi / 180;
  Offset p(double x, double y) {
    // Rotate about Y (yaw), then X (pitch).
    var X = x * math.cos(ya);
    var Z = -x * math.sin(ya);
    var Y = y;
    final y2 = Y * math.cos(pa) - Z * math.sin(pa);
    final z2 = Y * math.sin(pa) + Z * math.cos(pa);
    Y = y2;
    Z = z2 + distance;
    X += cx;
    return Offset(
      imageSize.width / 2 + f * X / Z,
      imageSize.height / 2 + f * Y / Z,
    );
  }

  return [
    p(-w / 2, -h / 2),
    p(w / 2, -h / 2),
    p(w / 2, h / 2),
    p(-w / 2, h / 2)
  ];
}

void main() {
  group('ZRectAspect.widthOverHeight', () {
    test('front-on rectangle', () {
      final q = project(40, 50);
      expect(ZRectAspect.widthOverHeight(q, imageSize), closeTo(0.8, 1e-6));
    });

    for (final c in const [
      (yaw: 30.0, pitch: 0.0),
      (yaw: -35.0, pitch: 10.0),
      (yaw: 20.0, pitch: -25.0),
      (yaw: 45.0, pitch: 5.0),
    ]) {
      test('known focal: exact at yaw ${c.yaw}° pitch ${c.pitch}°', () {
        final q = project(40, 50, yaw: c.yaw, pitch: c.pitch, cx: 10);
        expect(ZRectAspect.widthOverHeight(q, imageSize, focalPx: f),
            closeTo(0.8, 1e-6));
      });

      test('solved focal: close at yaw ${c.yaw}° pitch ${c.pitch}°', () {
        final q = project(40, 50, yaw: c.yaw, pitch: c.pitch, cx: 10);
        expect(ZRectAspect.widthOverHeight(q, imageSize), closeTo(0.8, 0.02));
      });
    }

    test('35 mm-equivalent focal lengths are measured across the diagonal', () {
      // A 4 : 3 photo: 36 mm across its long side would be 3.9 % short.
      expect(ZRectAspect.focalPxFor(26, imageSize),
          closeTo(26 * 5000 / 43.2666, 0.01));
      // A 16 : 9 still from the camera plugin (1080 × 1920).
      expect(ZRectAspect.focalPxFor(26, const Size(1080, 1920)),
          closeTo(26 * 2202.9 / 43.2666, 0.05));
    });

    group('real photos without EXIF (corners marked by hand)', () {
      // 2576 × 1932 iPhone photos; the far vanishing point is 26 to 1900
      // diagonals away, and solving the focal length from these quads
      // gave 115, 46, 17 and 7 mm for the same 26 mm lens.
      const size = Size(2576, 1932);
      const portrait = Size(1932, 2576);
      final cases = <(String, List<Offset>, Size, double)>[
        (
          'a 65" TV from the left (1456.8 × 831.9 mm)',
          const [
            Offset(449, 370),
            Offset(1859, 629),
            Offset(1843, 1379),
            Offset(424, 1598),
          ],
          size,
          1456.8 / 831.9,
        ),
        (
          'the same TV, a second photo',
          const [
            Offset(497, 370),
            Offset(1889, 636),
            Offset(1871, 1386),
            Offset(465, 1596),
          ],
          size,
          1456.8 / 831.9,
        ),
        (
          'a felt board from the side (front photos: 1 : 0.470)',
          const [
            Offset(770, 566),
            Offset(2410, 683),
            Offset(2406, 1441),
            Offset(745, 1525),
          ],
          size,
          1 / 0.470,
        ),
        (
          'a framed poster from the side (front photos: 1 : 1.394)',
          const [
            Offset(690.6, 802.1),
            Offset(1405.4, 668.2),
            Offset(1450.4, 1899.9),
            Offset(723.1, 1810.4),
          ],
          portrait,
          1 / 1.394,
        ),
      ];
      for (final (name, quad, imageSize, truth) in cases) {
        test(name, () {
          final wh = ZRectAspect.widthOverHeight(quad, imageSize)!;
          expect((wh / truth - 1).abs(), lessThan(0.015),
              reason: 'got ${wh.toStringAsFixed(4)}, '
                  'true ${truth.toStringAsFixed(4)}');
        });
      }

      test('strong perspective both ways, a phone lens', () {
        // A tablet leaning back on a stand, seen from the side and above
        // (15 : 9 screen): both vanishing points are near; the focal
        // length solves to 26 mm.
        const screen = [
          Offset(451, 810),
          Offset(1383, 721),
          Offset(1460, 1267),
          Offset(575, 1467),
        ];
        final wh = ZRectAspect.widthOverHeight(screen, portrait)!;
        expect((wh / (15 / 9) - 1).abs(), lessThan(0.01));
      });
    });

    test('another lens without EXIF: the focal length is solved', () {
      // A 70 mm tele (8000 px), seen from the side and above: assuming a
      // phone's 26 mm would be 6 % off.
      List<Offset> tele(double yaw, double pitch) {
        const ft = 8000.0;
        final ya = yaw * math.pi / 180, pa = pitch * math.pi / 180;
        Offset p(double x, double y) {
          final X = x * math.cos(ya);
          final z = -x * math.sin(ya);
          final y2 = y * math.cos(pa) - z * math.sin(pa);
          final z2 = y * math.sin(pa) + z * math.cos(pa) + 400;
          return Offset(2000 + ft * X / z2, 1500 + ft * y2 / z2);
        }

        return [p(-20, -25), p(20, -25), p(20, 25), p(-20, 25)];
      }

      final q = tele(35, 20);
      expect(ZRectAspect.widthOverHeight(q, imageSize), closeTo(0.8, 1e-6));
      final assumed = ZRectAspect.widthOverHeight(
        q,
        imageSize,
        focalPx: ZRectAspect.focalPxFor(26, imageSize),
      )!;
      expect((assumed / 0.8 - 1).abs(), greaterThan(0.03));
    });

    test('side averages are wrong from the side (why this exists)', () {
      final q = project(40, 50, yaw: 40);
      final naive = ZRectAspect.sideAverage(q);
      final good = ZRectAspect.widthOverHeight(q, imageSize, focalPx: f)!;
      expect((naive - 0.8).abs(), greaterThan(0.08));
      expect((good - 0.8).abs(), lessThan(1e-6));
    });

    test('degenerate quads give null', () {
      expect(
        ZRectAspect.widthOverHeight(
            const [Offset.zero, Offset.zero, Offset.zero, Offset.zero],
            imageSize),
        isNull,
      );
    });
  });

  group('ZRectAspect.sizeOnPlane', () {
    // A 50 × 70 cm frame with a 5 cm mat window inset and a 30 × 40 cm
    // print, all in one plane.
    List<Offset> level(double w, double h,
            {double yaw = 0, double pitch = 0}) =>
        project(w, h, yaw: yaw, pitch: pitch);

    for (final c in const [
      (yaw: 0.0, pitch: 0.0),
      (yaw: 30.0, pitch: 0.0),
      (yaw: -25.0, pitch: 15.0),
      (yaw: 40.0, pitch: -20.0),
    ]) {
      test('inner levels from the frame, yaw ${c.yaw} pitch ${c.pitch}', () {
        final frame = level(50, 70, yaw: c.yaw, pitch: c.pitch);
        for (final (w, h) in const [(40.0, 60.0), (30.0, 40.0), (50.0, 70.0)]) {
          final s = ZRectAspect.sizeOnPlane(
            reference: frame,
            referenceHeight: 70,
            referenceWidth: 50,
            quad: level(w, h, yaw: c.yaw, pitch: c.pitch),
          )!;
          expect(s.width, closeTo(w, 1e-6));
          expect(s.height, closeTo(h, 1e-6));
        }
      });

      test('the frame from the print, yaw ${c.yaw} pitch ${c.pitch}', () {
        final s = ZRectAspect.sizeOnPlane(
          reference: level(30, 40, yaw: c.yaw, pitch: c.pitch),
          referenceHeight: 40,
          referenceWidth: 30,
          quad: level(50, 70, yaw: c.yaw, pitch: c.pitch),
        )!;
        expect(s.width, closeTo(50, 1e-6));
        expect(s.height, closeTo(70, 1e-6));
      });
    }

    test('normalized coordinates work as well as pixels', () {
      List<Offset> n(List<Offset> q) => [
            for (final p in q)
              Offset(p.dx / imageSize.width, p.dy / imageSize.height),
          ];
      final s = ZRectAspect.sizeOnPlane(
        reference: n(level(50, 70, yaw: 30)),
        referenceHeight: 70,
        referenceWidth: 50,
        quad: n(level(30, 40, yaw: 30)),
      )!;
      expect(s.width, closeTo(30, 1e-6));
      expect(s.height, closeTo(40, 1e-6));
    });

    test('degenerate reference, or a quad beyond the horizon: null', () {
      const flat = [Offset.zero, Offset(1, 0), Offset(2, 0), Offset(3, 0)];
      expect(
        ZRectAspect.sizeOnPlane(
            reference: flat,
            referenceHeight: 1,
            referenceWidth: 1,
            quad: level(30, 40)),
        isNull,
      );
      // A strongly foreshortened reference: its plane's horizon crosses
      // the image, and a quad over it has no size on that plane.
      const steep = [
        Offset(1900, 1000),
        Offset(2100, 1000),
        Offset(3000, 2000),
        Offset(1000, 2000),
      ];
      expect(
        ZRectAspect.sizeOnPlane(
          reference: steep,
          referenceHeight: 1,
          referenceWidth: 1,
          quad: const [
            Offset(1000, 100),
            Offset(3000, 100),
            Offset(3000, 2000),
            Offset(1000, 2000),
          ],
        ),
        isNull,
      );
    });
  });

  test('focalPxFromExif reads FocalLengthIn35mmFilm', () {
    final im = img.Image(width: 40, height: 30);
    im.exif.exifIfd['FocalLengthIn35mmFilm'] = img.IfdValueShort(26);
    final bytes = Uint8List.fromList(img.encodeJpg(im));
    expect(
        ZRectAspect.focalPxFromExif(bytes, const Size(4000, 3000)),
        // 35 mm-equivalent: across the diagonal (5000 px / 43.27 mm).
        closeTo(26 * 5000 / 43.266615305567875, 1e-6));
    final plain =
        Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4)));
    expect(ZRectAspect.focalPxFromExif(plain, imageSize), isNull);
    expect(ZRectAspect.focalPxFromExif(Uint8List(3), imageSize), isNull);
  });
}
