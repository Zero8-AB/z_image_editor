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
