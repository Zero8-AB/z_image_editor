import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:z_image_editor/z_image_editor.dart';

void main() {
  group('ZQuadMath.orderCorners', () {
    test('orders a shuffled axis-aligned rectangle as TL, TR, BR, BL', () {
      final q = ZQuadMath.orderCorners(const [
        Offset(10, 20),
        Offset(1, 20),
        Offset(10, 2),
        Offset(1, 2),
      ]);
      expect(q, const [
        Offset(1, 2),
        Offset(10, 2),
        Offset(10, 20),
        Offset(1, 20),
      ]);
    });

    test('orders a perspective quad', () {
      const tl = Offset(0.2, 0.1), tr = Offset(0.9, 0.2);
      const br = Offset(0.8, 0.9), bl = Offset(0.1, 0.8);
      expect(ZQuadMath.orderCorners(const [br, tl, bl, tr]), [tl, tr, br, bl]);
    });

    test('orders a quad rotated by ~30 degrees', () {
      const pts = [
        Offset(0.40, 0.10),
        Offset(0.90, 0.39),
        Offset(0.60, 0.90),
        Offset(0.10, 0.61),
      ];
      final q = ZQuadMath.orderCorners([pts[2], pts[0], pts[3], pts[1]]);
      expect(q.first, pts[0]);
      expect(ZQuadMath.isConvex(q, clockwiseOnly: true), isTrue);
    });

    test('needs exactly four points', () {
      expect(() => ZQuadMath.orderCorners(const [Offset.zero]),
          throwsArgumentError);
    });
  });

  group('ZQuadMath.isConvex', () {
    test('accepts the full image clockwise', () {
      expect(
          ZQuadMath.isConvex(ZQuadMath.fullImage, clockwiseOnly: true), isTrue);
    });

    test('rejects a self-intersecting (bow-tie) quad', () {
      expect(
        ZQuadMath.isConvex(const [
          Offset(0, 0),
          Offset(1, 1),
          Offset(1, 0),
          Offset(0, 1),
        ]),
        isFalse,
      );
    });

    test('rejects a concave quad', () {
      expect(
        ZQuadMath.isConvex(const [
          Offset(0, 0),
          Offset(1, 0),
          Offset(0.3, 0.3),
          Offset(0, 1),
        ]),
        isFalse,
      );
    });

    test('rejects collinear points', () {
      expect(
        ZQuadMath.isConvex(const [
          Offset(0, 0),
          Offset(0.5, 0),
          Offset(1, 0),
          Offset(0, 1),
        ]),
        isFalse,
      );
    });

    test('clockwiseOnly rejects a mirrored quad', () {
      final mirrored = ZQuadMath.fullImage.reversed.toList();
      expect(ZQuadMath.isConvex(mirrored), isTrue);
      expect(ZQuadMath.isConvex(mirrored, clockwiseOnly: true), isFalse);
    });
  });

  test('area of the unit square and a triangle-ish quad', () {
    expect(ZQuadMath.area(ZQuadMath.fullImage), closeTo(1, 1e-12));
    expect(
      ZQuadMath.area(const [
        Offset(0, 0),
        Offset(2, 0),
        Offset(2, 1),
        Offset(0, 1),
      ]),
      closeTo(2, 1e-12),
    );
  });

  test('normalize / denormalize round-trip', () {
    const size = Size(4000, 3000);
    const q = [
      Offset(100, 200),
      Offset(3900, 150),
      Offset(3800, 2900),
      Offset(50, 2950),
    ];
    final back = ZQuadMath.denormalize(ZQuadMath.normalize(q, size), size);
    for (var i = 0; i < 4; i++) {
      expect((back[i] - q[i]).distance, lessThan(1e-9));
    }
  });

  test('isFullImage honours its tolerance', () {
    expect(ZQuadMath.isFullImage(ZQuadMath.fullImage), isTrue);
    expect(
      ZQuadMath.isFullImage(const [
        Offset(0.001, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ]),
      isTrue,
    );
    expect(
      ZQuadMath.isFullImage(const [
        Offset(0.05, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ]),
      isFalse,
    );
  });

  group('ZQuadMath.warpOutputSize', () {
    test('rectangle keeps its size', () {
      expect(
        ZQuadMath.warpOutputSize(const [
          Offset(10, 10),
          Offset(110, 10),
          Offset(110, 60),
          Offset(10, 60),
        ]),
        const Size(100, 50),
      );
    });

    test('uses the longer of each pair of opposite edges', () {
      // Top edge 80, bottom 100; left 50, right 60 (keystoned).
      final s = ZQuadMath.warpOutputSize(const [
        Offset(10, 0),
        Offset(90, 0),
        Offset(100, 60),
        Offset(0, 50),
      ]);
      expect(s.width, 100);
      expect(s.height, closeTo(60.8, 0.5)); // right edge sqrt(10²+60²)
    });

    test('maxSide scales down keeping the aspect ratio', () {
      final s = ZQuadMath.warpOutputSize(
        const [
          Offset(0, 0),
          Offset(4000, 0),
          Offset(4000, 2000),
          Offset(0, 2000)
        ],
        maxSide: 1000,
      );
      expect(s, const Size(1000, 500));
    });

    test('never returns an empty size', () {
      final s = ZQuadMath.warpOutputSize(const [
        Offset(0, 0),
        Offset(0.2, 0),
        Offset(0.2, 0.2),
        Offset(0, 0.2),
      ]);
      expect(s.width, greaterThanOrEqualTo(1));
      expect(s.height, greaterThanOrEqualTo(1));
    });
  });

  group('ZQuadMath.squareToQuad', () {
    test('maps the unit square corners onto the quad corners', () {
      const q = [
        Offset(12, 30),
        Offset(220, 10),
        Offset(250, 300),
        Offset(5, 260),
      ];
      final m = ZQuadMath.squareToQuad(q);
      const uv = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
      for (var i = 0; i < 4; i++) {
        final p = ZQuadMath.applySquareToQuad(m, uv[i].dx, uv[i].dy);
        expect((p - q[i]).distance, lessThan(1e-9), reason: 'corner $i');
      }
    });

    test('keeps straight lines straight (projective, not bilinear)', () {
      const q = [
        Offset(0, 0),
        Offset(100, 20),
        Offset(100, 80),
        Offset(0, 100),
      ];
      final m = ZQuadMath.squareToQuad(q);
      // Points along the diagonal u == v must stay collinear.
      final a = ZQuadMath.applySquareToQuad(m, 0, 0);
      final b = ZQuadMath.applySquareToQuad(m, 0.3, 0.3);
      final c = ZQuadMath.applySquareToQuad(m, 1, 1);
      final cross =
          (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
      expect(cross.abs(), lessThan(1e-6));
    });

    test('parallelogram is affine', () {
      final m = ZQuadMath.squareToQuad(const [
        Offset(0, 0),
        Offset(10, 0),
        Offset(15, 10),
        Offset(5, 10),
      ]);
      expect(m[6], 0);
      expect(m[7], 0);
    });
  });

  group('quarter turns', () {
    test('rotatePoint turns clockwise and unrotatePoint undoes it', () {
      expect(ZQuadMath.rotatePoint(const Offset(0, 0), 1), const Offset(1, 0));
      expect(ZQuadMath.rotatePoint(const Offset(1, 0), 1), const Offset(1, 1));
      const p = Offset(0.2, 0.7);
      for (var t = 0; t < 4; t++) {
        final back = ZQuadMath.unrotatePoint(ZQuadMath.rotatePoint(p, t), t);
        expect((back - p).distance, lessThan(1e-12));
      }
      expect(ZQuadMath.rotatePoint(p, 4), p);
    });

    test('rotateQuad keeps TL first on screen', () {
      final q = ZQuadMath.rotateQuad(ZQuadMath.fullImage, 1);
      expect(q, ZQuadMath.fullImage);
      const inner = [
        Offset(0.1, 0.2),
        Offset(0.6, 0.2),
        Offset(0.6, 0.9),
        Offset(0.1, 0.9),
      ];
      final r = ZQuadMath.rotateQuad(inner, 1);
      // (x, y) -> (1 - y, x)
      expect(r.first.dx, closeTo(0.1, 1e-12));
      expect(r.first.dy, closeTo(0.1, 1e-12));
      expect(ZQuadMath.isConvex(r, clockwiseOnly: true), isTrue);
    });
  });

  group('ZPerspectiveWarp', () {
    img.Image checker(int w, int h) {
      final im = img.Image(width: w, height: h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final on = ((x ~/ 10) + (y ~/ 10)).isEven;
          im.setPixelRgb(x, y, on ? 255 : 0, x % 256, y % 256);
        }
      }
      return im;
    }

    test('identity quad reproduces the image', () {
      final src = checker(40, 30);
      final out = ZPerspectiveWarp.warpImage(src, const [
        Offset(0, 0),
        Offset(40, 0),
        Offset(40, 30),
        Offset(0, 30),
      ]);
      expect(out.width, 40);
      expect(out.height, 30);
      for (final p in const [Offset(0, 0), Offset(13, 7), Offset(39, 29)]) {
        final a = src.getPixel(p.dx.toInt(), p.dy.toInt());
        final b = out.getPixel(p.dx.toInt(), p.dy.toInt());
        expect(b.r, a.r);
        expect(b.g, a.g);
        expect(b.b, a.b);
      }
    });

    test('sub-rectangle quad is a crop', () {
      final src = checker(100, 80);
      final out = ZPerspectiveWarp.warpImage(src, const [
        Offset(20, 10),
        Offset(70, 10),
        Offset(70, 50),
        Offset(20, 50),
      ]);
      expect(out.width, 50);
      expect(out.height, 40);
      final a = src.getPixel(25, 15);
      final b = out.getPixel(5, 5);
      expect(b.r, a.r);
      expect(b.g, a.g);
      expect(b.b, a.b);
    });

    test('a quad listed from the top-right turns the output', () {
      // Output TL = source TR etc. -> 90° counter-clockwise view.
      final src = img.Image(width: 20, height: 10);
      img.fill(src, color: img.ColorRgb8(0, 0, 0));
      img.fillRect(src,
          x1: 15, y1: 0, x2: 19, y2: 4, color: img.ColorRgb8(255, 0, 0));
      final out = ZPerspectiveWarp.warpImage(src, const [
        Offset(20, 0),
        Offset(20, 10),
        Offset(0, 10),
        Offset(0, 0),
      ]);
      expect(out.width, 10);
      expect(out.height, 20);
      expect(out.getPixel(1, 1).r, 255);
      expect(out.getPixel(8, 18).r, 0);
    });

    test('rectifies a keystoned rectangle back to a rectangle', () {
      // Draw a white quad on black, warp it: the output should be white.
      final src = img.Image(width: 200, height: 200);
      img.fill(src, color: img.ColorRgb8(0, 0, 0));
      const quad = [
        Offset(40, 30),
        Offset(170, 50),
        Offset(160, 170),
        Offset(30, 150),
      ];
      img.fillPolygon(
        src,
        vertices: [for (final p in quad) img.Point(p.dx, p.dy)],
        color: img.ColorRgb8(255, 255, 255),
      );
      final out = ZPerspectiveWarp.warpImage(src, quad);
      var white = 0;
      for (var y = 2; y < out.height - 2; y++) {
        for (var x = 2; x < out.width - 2; x++) {
          if (out.getPixel(x, y).r > 200) white++;
        }
      }
      final total = (out.width - 4) * (out.height - 4);
      expect(white / total, greaterThan(0.98));
    });

    test('warpBytesSync applies EXIF orientation and encodes JPEG', () {
      final src = checker(60, 40);
      src.exif.imageIfd.orientation = 6; // rotate 90° cw when displayed
      final bytes = Uint8List.fromList(img.encodeJpg(src));
      final out = ZPerspectiveWarp.warpBytesSync(bytes, ZQuadMath.fullImage);
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 40);
      expect(decoded.height, 60);
      expect(out[0], 0xFF);
      expect(out[1], 0xD8);
    });

    test('warpBytesSync keeps alpha as PNG', () {
      final src = img.Image(width: 8, height: 8, numChannels: 4);
      final out = ZPerspectiveWarp.warpBytesSync(
        Uint8List.fromList(img.encodePng(src)),
        ZQuadMath.fullImage,
      );
      expect(out.sublist(1, 4), 'PNG'.codeUnits);
    });

    test('warpBytesSync throws on garbage', () {
      expect(
        () => ZPerspectiveWarp.warpBytesSync(
            Uint8List.fromList([1, 2, 3]), ZQuadMath.fullImage),
        throwsFormatException,
      );
    });
  });

  group('review fixes', () {
    test('indexed (palette) PNGs are expanded before warping', () {
      final rgb = img.Image(width: 40, height: 20);
      img.fill(rgb, color: img.ColorRgb8(0, 0, 255));
      img.fillRect(rgb,
          x1: 0, y1: 0, x2: 19, y2: 19, color: img.ColorRgb8(255, 0, 0));
      final indexed = img.quantize(rgb, numberOfColors: 4);
      expect(indexed.hasPalette, isTrue);
      final png = Uint8List.fromList(img.encodePng(indexed));
      expect(img.decodePng(png)!.hasPalette, isTrue);
      final out = img.decodeJpg(
        ZPerspectiveWarp.warpBytesSync(png, ZQuadMath.fullImage),
      )!;
      final left = out.getPixel(5, 10), right = out.getPixel(35, 10);
      expect(left.r, greaterThan(200));
      expect(left.b, lessThan(60));
      expect(right.b, greaterThan(200));
      expect(right.r, lessThan(60));
    });

    test('1-bit images are expanded too', () {
      final bw = img.Image(width: 16, height: 8, format: img.Format.uint1);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          bw.setPixelRgb(x, y, 1, 1, 1);
        }
      }
      final out = ZPerspectiveWarp.warpImage(bw, const [
        Offset(0, 0),
        Offset(16, 0),
        Offset(16, 8),
        Offset(0, 8),
      ]);
      expect(out.getPixel(2, 4).r, 255);
      expect(out.getPixel(13, 4).r, 0);
    });

    test('output is capped at 6000 px by default', () {
      expect(ZPerspectiveWarp.defaultMaxOutputSide, 6000);
      final s = ZQuadMath.warpOutputSize(
        const [
          Offset(0, 0),
          Offset(8000, 0),
          Offset(8000, 6000),
          Offset(0, 6000)
        ],
        maxSide: ZPerspectiveWarp.defaultMaxOutputSide,
      );
      expect(s, const Size(6000, 4500));
    });

    test('large sources are scaled down before warping', () {
      final big = img.Image(width: 1600, height: 1200);
      final out = img.decodeJpg(ZPerspectiveWarp.warpBytesSync(
        Uint8List.fromList(img.encodeJpg(big)),
        ZQuadMath.fullImage,
        maxSide: 400,
      ))!;
      expect(out.width, 400);
      expect(out.height, 300);
    });
  });

  test('ZFrameCandidate requires four corners', () {
    expect(
      () => ZFrameCandidate(corners: const [Offset.zero], label: 'x'),
      throwsArgumentError,
    );
  });

  group('nesting', () {
    const outer = [
      Offset(0.1, 0.1),
      Offset(0.9, 0.12),
      Offset(0.88, 0.9),
      Offset(0.12, 0.88),
    ];
    const inner = [
      Offset(0.2, 0.2),
      Offset(0.8, 0.2),
      Offset(0.8, 0.8),
      Offset(0.2, 0.8),
    ];

    test('isInside', () {
      expect(ZQuadMath.isInside(inner, outer), isTrue);
      expect(ZQuadMath.isInside(outer, inner), isFalse);
      expect(ZQuadMath.isInside(outer, outer), isTrue);
      final poking = [const Offset(0.095, 0.2), ...inner.skip(1)];
      expect(ZQuadMath.isInside(poking, outer), isFalse);
      expect(ZQuadMath.isInside(poking, outer, tolerance: 0.01), isTrue);
      expect(ZQuadMath.isInside(inner, ZQuadMath.fullImage), isTrue);
    });

    test('isSame', () {
      expect(ZQuadMath.isSame(inner, List.of(inner)), isTrue);
      expect(ZQuadMath.isSame(inner, outer), isFalse);
      expect(
          ZQuadMath.isSame(
              inner, [inner[0] + const Offset(0.001, 0), ...inner.skip(1)]),
          isFalse);
    });
  });
}
