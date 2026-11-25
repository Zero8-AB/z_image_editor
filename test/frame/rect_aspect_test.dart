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
    expect(ZRectAspect.focalPxFromExif(bytes, const Size(4000, 3000)),
        closeTo(26 * 4000 / 36, 1e-6));
    final plain =
        Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4)));
    expect(ZRectAspect.focalPxFromExif(plain, imageSize), isNull);
    expect(ZRectAspect.focalPxFromExif(Uint8List(3), imageSize), isNull);
  });
}
