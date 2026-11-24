import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/image_editor.dart';

const vp = Size(400, 600);
const imgLandscape = Size(3000, 2000); // fitted: 400 x 266.67, centred
const imgPortrait = Size(2000, 3000); // fitted: 400 x 600 (fills)

/// Fitted image rect (BoxFit.contain) in viewport px.
Rect fitted(Size image, [Size viewport = vp]) {
  final s =
      math.min(viewport.width / image.width, viewport.height / image.height);
  final w = image.width * s, h = image.height * s;
  return Rect.fromLTWH(
      (viewport.width - w) / 2, (viewport.height - h) / 2, w, h);
}

CropRect cropOf(Rect r, [Size viewport = vp]) => CropRect(
      left: r.left / viewport.width,
      top: r.top / viewport.height,
      width: r.width / viewport.width,
      height: r.height / viewport.height,
    );

List<Offset> cornersPx(CropRect c, [Size viewport = vp]) => [
      Offset(c.left * viewport.width, c.top * viewport.height),
      Offset((c.left + c.width) * viewport.width, c.top * viewport.height),
      Offset((c.left + c.width) * viewport.width,
          (c.top + c.height) * viewport.height),
      Offset(c.left * viewport.width, (c.top + c.height) * viewport.height),
    ];

void main() {
  late TransformationService ts;
  setUp(() => ts = TransformationService());

  group('viewport <-> image coordinates', () {
    test('identity: fitted rect corners map to image corners', () {
      final r = fitted(imgLandscape);
      Offset toImg(Offset p) => ts.viewportToImageCoordinates(
            viewportPoint: p,
            viewportSize: vp,
            imageSize: imgLandscape,
            rotationDegrees: 0,
            scale: 1,
            panOffset: Offset.zero,
            flipHorizontal: false,
          );
      expect((toImg(r.topLeft) - Offset.zero).distance, lessThan(1e-6));
      expect(
          (toImg(r.bottomRight) -
                  Offset(imgLandscape.width, imgLandscape.height))
              .distance,
          lessThan(1e-6));
      expect(
          (toImg(vp.center(Offset.zero)) - imgLandscape.center(Offset.zero))
              .distance,
          lessThan(1e-6));
    });

    test('round-trips for rotation, scale, pan, flips and tilt', () {
      final rnd = math.Random(42);
      for (var i = 0; i < 200; i++) {
        final rot = rnd.nextDouble() * 360 - 180;
        final scale = 0.3 + rnd.nextDouble() * 3;
        final pan =
            Offset(rnd.nextDouble() * 200 - 100, rnd.nextDouble() * 200 - 100);
        final fh = rnd.nextBool(), fv = rnd.nextBool();
        final th = rnd.nextBool() ? rnd.nextDouble() * 60 - 30 : 0.0;
        final tv = rnd.nextBool() ? rnd.nextDouble() * 60 - 30 : 0.0;
        final p = Offset(rnd.nextDouble() * 3000, rnd.nextDouble() * 2000);
        final v = ts.imageToViewportCoordinates(
          imagePoint: p,
          viewportSize: vp,
          imageSize: imgLandscape,
          rotationDegrees: rot,
          scale: scale,
          panOffset: pan,
          flipHorizontal: fh,
          flipVertical: fv,
          tiltHorizontal: th,
          tiltVertical: tv,
        );
        final back = ts.viewportToImageCoordinates(
          viewportPoint: v,
          viewportSize: vp,
          imageSize: imgLandscape,
          rotationDegrees: rot,
          scale: scale,
          panOffset: pan,
          flipHorizontal: fh,
          flipVertical: fv,
          tiltHorizontal: th,
          tiltVertical: tv,
        );
        expect((back - p).distance, lessThan(1e-3), reason: 'case $i');
      }
    });

    test('horizontal flip mirrors around the vertical centre line', () {
      final r = fitted(imgLandscape);
      final p = ts.viewportToImageCoordinates(
        viewportPoint: r.topLeft,
        viewportSize: vp,
        imageSize: imgLandscape,
        rotationDegrees: 0,
        scale: 1,
        panOffset: Offset.zero,
        flipHorizontal: true,
      );
      expect(p.dx, closeTo(imgLandscape.width, 1e-6));
      expect(p.dy, closeTo(0, 1e-6));
    });

    test('90° rotation turns the image clockwise on screen', () {
      // Image top-left corner should appear on the right side after +90°.
      final v = ts.imageToViewportCoordinates(
        imagePoint: Offset.zero,
        viewportSize: vp,
        imageSize: imgLandscape,
        rotationDegrees: 90,
        scale: 1,
        panOffset: Offset.zero,
        flipHorizontal: false,
      );
      expect(v.dx, greaterThan(vp.width / 2));
      expect(v.dy, lessThan(vp.height / 2));
    });
  });

  group('calculateMinScaleForRotation', () {
    test('is 1.0 without rotation and for exact quarter turns of a square', () {
      expect(
          ts.calculateMinScaleForRotation(
              rotationDegrees: 0, imageAspectRatio: 1.5),
          1.0);
      expect(
          ts.calculateMinScaleForRotation(
              rotationDegrees: 90, imageAspectRatio: 1, cropAspectRatio: 1),
          closeTo(1.0, 1e-9));
    });

    test('square at 45° needs sqrt(2)', () {
      expect(
        ts.calculateMinScaleForRotation(
            rotationDegrees: 45, imageAspectRatio: 1, cropAspectRatio: 1),
        closeTo(math.sqrt2, 1e-9),
      );
    });

    test('is symmetric in the sign of the angle', () {
      for (final a in [3.0, 12.5, 30.0, 44.0]) {
        final pos = ts.calculateMinScaleForRotation(
            rotationDegrees: a, imageAspectRatio: 1.5, cropAspectRatio: 1.5);
        ts.clearCache();
        final neg = ts.calculateMinScaleForRotation(
            rotationDegrees: -a, imageAspectRatio: 1.5, cropAspectRatio: 1.5);
        expect(neg, closeTo(pos, 1e-12), reason: 'angle $a');
      }
    });

    test('grows monotonically from 0° to 45° (fine rotation range)', () {
      var prev = 1.0;
      for (var a = 1.0; a <= 45; a += 1) {
        ts.clearCache();
        final s = ts.calculateMinScaleForRotation(
            rotationDegrees: a, imageAspectRatio: 1.5, cropAspectRatio: 1.5);
        expect(s, greaterThanOrEqualTo(prev), reason: 'angle $a');
        prev = s;
      }
    });

    test('the scaled, rotated image covers the crop corners', () {
      // Crop = fitted image; rotate by 10°: every crop corner must map
      // inside the image when the image is scaled by minScaleForRotation.
      final crop = cropOf(fitted(imgLandscape));
      final s = ts.calculateMinScaleForRotation(
          rotationDegrees: 10, imageAspectRatio: 1.5, cropAspectRatio: 1.5);
      for (final c in cornersPx(crop)) {
        final p = ts.viewportToImageCoordinates(
          viewportPoint: c,
          viewportSize: vp,
          imageSize: imgLandscape,
          rotationDegrees: 10,
          scale: s,
          panOffset: Offset.zero,
          flipHorizontal: false,
        );
        expect(p.dx, inInclusiveRange(-1e-6, imgLandscape.width + 1e-6));
        expect(p.dy, inInclusiveRange(-1e-6, imgLandscape.height + 1e-6));
      }
    });

    test('memoization does not return a stale value for new inputs', () {
      final a = ts.calculateMinScaleForRotation(
          rotationDegrees: 20, imageAspectRatio: 1.5, cropAspectRatio: 1.5);
      final b = ts.calculateMinScaleForRotation(
          rotationDegrees: 20, imageAspectRatio: 1.0, cropAspectRatio: 1.0);
      expect(a, isNot(closeTo(b, 1e-6)));
    });
  });

  group('calculateMinUserScaleForCrop', () {
    test('full fitted crop without rotation needs exactly 1.0', () {
      expect(
        ts.calculateMinUserScaleForCrop(
          cropRect: cropOf(fitted(imgLandscape)),
          imageSize: imgLandscape,
          viewportSize: vp,
          rotationDegrees: 0,
        ),
        closeTo(1.0, 1e-9),
      );
    });

    test('a half-size crop allows zooming out to 0.5', () {
      final f = fitted(imgLandscape);
      final half = Rect.fromCenter(
          center: f.center, width: f.width / 2, height: f.height / 2);
      expect(
        ts.calculateMinUserScaleForCrop(
          cropRect: cropOf(half),
          imageSize: imgLandscape,
          viewportSize: vp,
          rotationDegrees: 0,
        ),
        closeTo(0.5, 1e-9),
      );
    });

    test('never returns less than 0.01', () {
      expect(
        ts.calculateMinUserScaleForCrop(
          cropRect: const CropRect(left: 0.5, top: 0.5, width: 0, height: 0),
          imageSize: imgLandscape,
          viewportSize: vp,
          rotationDegrees: 0,
        ),
        0.01,
      );
    });
  });

  group('clampPanToCoverCrop', () {
    bool covered(CropRect crop, Offset pan, double rot, double total,
        {bool fh = false, bool fv = false}) {
      for (final c in cornersPx(crop)) {
        final p = ts.viewportToImageCoordinates(
          viewportPoint: c,
          viewportSize: vp,
          imageSize: imgLandscape,
          rotationDegrees: rot,
          scale: total,
          panOffset: pan,
          flipHorizontal: fh,
          flipVertical: fv,
        );
        if (p.dx < -1e-3 ||
            p.dy < -1e-3 ||
            p.dx > imgLandscape.width + 1e-3 ||
            p.dy > imgLandscape.height + 1e-3) {
          return false;
        }
      }
      return true;
    }

    test('leaves a valid pan untouched', () {
      final crop = cropOf(fitted(imgLandscape));
      final pan = ts.clampPanToCoverCrop(
        pan: Offset.zero,
        cropRect: crop,
        imageSize: imgLandscape,
        viewportSize: vp,
        rotationDegrees: 0,
        totalScale: 1,
        flipHorizontal: false,
        flipVertical: false,
      );
      expect(pan, Offset.zero);
    });

    test('pulls an over-panned image back so the crop is covered', () {
      final f = fitted(imgLandscape);
      final crop = cropOf(Rect.fromCenter(
          center: f.center, width: f.width / 2, height: f.height / 2));
      for (final rot in [0.0, 7.0, -15.0, 90.0]) {
        for (final flips in [
          [false, false],
          [true, false],
          [false, true],
        ]) {
          final total = ts.calculateMinScaleForRotation(
                  rotationDegrees: rot,
                  imageAspectRatio: 1.5,
                  cropAspectRatio: 1.5) *
              1.5;
          ts.clearCache();
          final pan = ts.clampPanToCoverCrop(
            pan: const Offset(500, -400),
            cropRect: crop,
            imageSize: imgLandscape,
            viewportSize: vp,
            rotationDegrees: rot,
            totalScale: total,
            flipHorizontal: flips[0],
            flipVertical: flips[1],
          );
          expect(covered(crop, pan, rot, total, fh: flips[0], fv: flips[1]),
              isTrue,
              reason: 'rot $rot flips $flips -> $pan');
        }
      }
    });
  });

  group('clampPanOffset (AABB)', () {
    test('at fit scale with the full crop, pan is forced to zero', () {
      final p = ts.clampPanOffset(
        currentOffset: const Offset(50, -80),
        imageSize: imgLandscape,
        viewportSize: vp,
        rotationDegrees: 0,
        userScale: 1,
        cropViewport: fitted(imgLandscape),
      );
      expect(p.dx, closeTo(0, 1e-9));
      expect(p.dy, closeTo(0, 1e-9));
    });

    test('zoomed in 2x allows panning by half the fitted size', () {
      final f = fitted(imgLandscape);
      final p = ts.clampPanOffset(
        currentOffset: const Offset(10000, 10000),
        imageSize: imgLandscape,
        viewportSize: vp,
        rotationDegrees: 0,
        userScale: 2,
        cropViewport: f,
      );
      expect(p.dx, closeTo(f.width / 2, 1e-6));
      expect(p.dy, closeTo(f.height / 2, 1e-6));
    });
  });

  group('constrainCropRectToImage (raycast)', () {
    test('a crop inside the image is unchanged', () {
      final f = fitted(imgLandscape);
      final inner = cropOf(f.deflate(30));
      final c = ts.constrainCropRectToImage(
        cropRect: inner,
        imageSize: imgLandscape,
        viewportSize: vp,
        rotationDegrees: 0,
        totalScale: 1,
        panOffset: Offset.zero,
        flipHorizontal: false,
        flipVertical: false,
      );
      expect(c.left, closeTo(inner.left, 1e-9));
      expect(c.top, closeTo(inner.top, 1e-9));
      expect(c.width, closeTo(inner.width, 1e-9));
      expect(c.height, closeTo(inner.height, 1e-9));
    });

    test('a crop over the letterbox is clamped to the image', () {
      const whole = CropRect(left: 0, top: 0, width: 1, height: 1);
      final c = ts.constrainCropRectToImage(
        cropRect: whole,
        imageSize: imgLandscape,
        viewportSize: vp,
        rotationDegrees: 0,
        totalScale: 1,
        panOffset: Offset.zero,
        flipHorizontal: false,
        flipVertical: false,
      );
      final f = cropOf(fitted(imgLandscape));
      expect(c.top, closeTo(f.top, 1e-9));
      expect(c.height, closeTo(f.height, 1e-9));
      expect(c.left, closeTo(0, 1e-9));
      expect(c.width, closeTo(1, 1e-9));
    });

    test('result corners always lie inside the rotated image', () {
      final rnd = math.Random(7);
      for (var i = 0; i < 100; i++) {
        final rot = rnd.nextDouble() * 90 - 45;
        final total = ts.calculateMinScaleForRotation(
                rotationDegrees: rot,
                imageAspectRatio: 1.5,
                cropAspectRatio: 1.5) *
            (1 + rnd.nextDouble());
        ts.clearCache();
        final raw = CropRect(
          left: rnd.nextDouble() * 0.4,
          top: rnd.nextDouble() * 0.4,
          width: 0.3 + rnd.nextDouble() * 0.6,
          height: 0.3 + rnd.nextDouble() * 0.6,
        );
        final c = ts.constrainCropRectToImage(
          cropRect: raw,
          imageSize: imgLandscape,
          viewportSize: vp,
          rotationDegrees: rot,
          totalScale: total,
          panOffset: Offset.zero,
          flipHorizontal: false,
          flipVertical: false,
        );
        for (final p in cornersPx(c)) {
          final ip = ts.viewportToImageCoordinates(
            viewportPoint: p,
            viewportSize: vp,
            imageSize: imgLandscape,
            rotationDegrees: rot,
            scale: total,
            panOffset: Offset.zero,
            flipHorizontal: false,
          );
          expect(ip.dx, inInclusiveRange(-0.5, imgLandscape.width + 0.5),
              reason: 'case $i rot $rot');
          expect(ip.dy, inInclusiveRange(-0.5, imgLandscape.height + 0.5),
              reason: 'case $i rot $rot');
        }
      }
    });

    test('enforces a 5% minimum size', () {
      final f = fitted(imgPortrait);
      final c = ts.constrainCropRectToImage(
        cropRect: CropRect(
            left: f.left / vp.width + 0.4,
            top: 0.4,
            width: 0.001,
            height: 0.001),
        imageSize: imgPortrait,
        viewportSize: vp,
        rotationDegrees: 0,
        totalScale: 1,
        panOffset: Offset.zero,
        flipHorizontal: false,
        flipVertical: false,
      );
      expect(c.width, closeTo(0.05, 1e-9));
      expect(c.height, closeTo(0.05, 1e-9));
    });
  });

  test('buildPerspectiveMatrix is identity without tilt', () {
    final m = TransformationService.buildPerspectiveMatrix(
        0, 0, const Offset(200, 300));
    expect(m.isIdentity(), isTrue);
  });

  test('CropRect.lerp interpolates linearly', () {
    const a = CropRect(left: 0, top: 0, width: 1, height: 1);
    const b = CropRect(left: 0.2, top: 0.4, width: 0.5, height: 0.2);
    final m = CropRect.lerp(a, b, 0.5);
    expect(m.left, closeTo(0.1, 1e-12));
    expect(m.top, closeTo(0.2, 1e-12));
    expect(m.width, closeTo(0.75, 1e-12));
    expect(m.height, closeTo(0.6, 1e-12));
  });
}
