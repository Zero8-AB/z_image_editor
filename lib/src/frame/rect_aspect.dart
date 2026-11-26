import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:image/image.dart' as img;

import 'quad_math.dart';

/// Recovers the real width : height of a photographed rectangle from its
/// four image corners (Zhang & He, "Whiteboard scanning and image
/// enhancement", 2007): the quad is the image of a rectangle under a
/// pinhole camera with square pixels and the principal point at the image
/// centre. With the focal length known (EXIF), the ratio is exact; without
/// it a typical phone lens is assumed, unless the quad shows strong
/// perspective both ways and the focal length solved from it is clearly
/// another lens's.
class ZRectAspect {
  ZRectAspect._();

  /// Typical phone main camera, 35 mm-equivalent focal length.
  static const double fallbackFocal35mm = 26;

  /// Diagonal of the 35 mm film frame (36 × 24 mm), in mm: a
  /// "35 mm-equivalent" focal length gives the same angle of view across
  /// the diagonal, whatever the photo's own shape (4 : 3, 16 : 9).
  static const double film35Diagonal = 43.266615305567875;

  /// Focal length in pixels of an image of [imageSize] for a
  /// 35 mm-equivalent focal length of [focal35mm].
  static double focalPxFor(double focal35mm, Size imageSize) =>
      focal35mm *
      math.sqrt(imageSize.width * imageSize.width +
          imageSize.height * imageSize.height) /
      film35Diagonal;

  /// The focal length is only solved from a quad whose two vanishing
  /// points both lie within this many image diagonals of the image
  /// centre. With one of them further away (a photo taken from the side
  /// at the artwork's height, or nearly from the front) the solution is
  /// the product of a huge and a tiny number: a pixel of corner error
  /// moves it from 7 to 115 mm on real photos, and the ratio with it.
  static const double maxVanishingDistance = 8;

  /// A solved focal length in this range (35 mm-equivalent) says "a phone's
  /// main camera" and no more: on real photos the solved value is a few
  /// mm off either way, and [fallbackFocal35mm] gave the better ratio
  /// every time. Outside the range the photo was taken with another lens
  /// (ultra-wide, tele) and the solved value is used.
  static const double phoneLensFrom = 18;
  static const double phoneLensTo = 38;

  /// Width / height of the rectangle whose image is [quad] (TL, TR, BR, BL
  /// in pixels of an image of [imageSize]). [focalPx] is the focal length in
  /// the same pixels; null = solve it, then fall back to
  /// [fallbackFocal35mm] (see [maxVanishingDistance]).
  ///
  /// Returns null for degenerate quads.
  static double? widthOverHeight(
    List<Offset> quad,
    Size imageSize, {
    double? focalPx,
  }) {
    if (quad.length != 4) return null;
    final u0 = imageSize.width / 2, v0 = imageSize.height / 2;
    // Paper order: m1 = TL, m2 = TR, m3 = BL, m4 = BR.
    final m1 = _h(quad[0]),
        m2 = _h(quad[1]),
        m3 = _h(quad[3]),
        m4 = _h(quad[2]);
    final c14 = _cross(m1, m4);
    final d2 = _dot(_cross(m2, m4), m3);
    final d3 = _dot(_cross(m3, m4), m2);
    if (d2.abs() < 1e-9 || d3.abs() < 1e-9) return null;
    final k2 = _dot(c14, m3) / d2;
    final k3 = _dot(c14, m2) / d3;
    final n2 = [k2 * m2[0] - m1[0], k2 * m2[1] - m1[1], k2 * m2[2] - m1[2]];
    final n3 = [k3 * m3[0] - m1[0], k3 * m3[1] - m1[1], k3 * m3[2] - m1[2]];

    // Nearly fronto-parallel: the focal length doesn't matter.
    final perspective = n2[2].abs() > 1e-6 && n3[2].abs() > 1e-6;
    double? f = focalPx;
    final diagonal = math.sqrt(imageSize.width * imageSize.width +
        imageSize.height * imageSize.height);
    bool near(List<double> n) {
      final x = n[0] - u0 * n[2], y = n[1] - v0 * n[2];
      return math.sqrt(x * x + y * y) <=
          maxVanishingDistance * diagonal * n[2].abs();
    }

    if (f == null && perspective && near(n2) && near(n3)) {
      final f2 = -((n2[0] * n3[0] -
                  (n2[0] * n3[2] + n2[2] * n3[0]) * u0 +
                  n2[2] * n3[2] * u0 * u0) +
              (n2[1] * n3[1] -
                  (n2[1] * n3[2] + n2[2] * n3[1]) * v0 +
                  n2[2] * n3[2] * v0 * v0)) /
          (n2[2] * n3[2]);
      // Accept only a plausible solution (35 mm equivalent 13..120 mm).
      if (f2 > 0) {
        final solved = math.sqrt(f2);
        final f35 = solved * film35Diagonal / diagonal;
        final phoneLens = f35 >= phoneLensFrom && f35 <= phoneLensTo;
        if (f35 >= 13 && f35 <= 120 && !phoneLens) f = solved;
      }
    }
    f ??= focalPxFor(fallbackFocal35mm, imageSize);

    double normSq(List<double> n) {
      final x = (n[0] - u0 * n[2]) / f!;
      final y = (n[1] - v0 * n[2]) / f;
      return x * x + y * y + n[2] * n[2];
    }

    final a = normSq(n2), b = normSq(n3);
    if (a <= 0 || b <= 0) return null;
    final r = math.sqrt(a / b);
    return r.isFinite && r > 0 ? r : null;
  }

  /// Height and width of [quad] measured on the plane of [reference], a
  /// quad whose real size is [referenceHeight] × [referenceWidth] (both
  /// TL, TR, BR, BL, in the same coordinates, pixels or normalized): the
  /// reference is straightened to its rectangle and [quad] goes through
  /// the same transform, so nested outlines of one object (frame, mat
  /// window, artwork) get sizes that fit each other. Each side is the mean
  /// of the two opposite sides.
  ///
  /// Null for a degenerate [reference], or when [quad] reaches the
  /// reference plane's horizon.
  static ({double height, double width})? sizeOnPlane({
    required List<Offset> reference,
    required double referenceHeight,
    required double referenceWidth,
    required List<Offset> quad,
  }) {
    if (reference.length != 4 || quad.length != 4) return null;
    if (!ZQuadMath.isConvex(reference)) return null;
    // Square → reference, as the matrix [a b c; d e f; g h 1]; its inverse
    // (adjugate, scale-free) takes image points to the unit square.
    final m = ZQuadMath.squareToQuad(reference);
    final a = m[0], b = m[1], c = m[2], d = m[3], e = m[4], f = m[5];
    final g = m[6], h = m[7];
    final inv = [
      e - f * h, c * h - b, b * f - c * e, //
      f * g - d, a - c * g, c * d - a * f, //
      d * h - e * g, b * g - a * h, a * e - b * d, //
    ];
    // The reference's own corners have w of this sign.
    final sign =
        (inv[6] * reference[0].dx + inv[7] * reference[0].dy + inv[8]).sign;
    if (sign == 0) return null;
    final pts = <Offset>[];
    for (final p in quad) {
      final w = inv[6] * p.dx + inv[7] * p.dy + inv[8];
      if (w * sign <= 1e-12) return null;
      pts.add(Offset(
        (inv[0] * p.dx + inv[1] * p.dy + inv[2]) / w * referenceWidth,
        (inv[3] * p.dx + inv[4] * p.dy + inv[5]) / w * referenceHeight,
      ));
    }
    final width = ((pts[1] - pts[0]).distance + (pts[2] - pts[3]).distance) / 2;
    final height =
        ((pts[3] - pts[0]).distance + (pts[2] - pts[1]).distance) / 2;
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return null;
    }
    return (height: height, width: width);
  }

  /// Width / height from the average lengths of opposite sides (no
  /// perspective correction): the last resort.
  static double sideAverage(List<Offset> q) {
    final w = ((q[1] - q[0]).distance + (q[2] - q[3]).distance) / 2;
    final h = ((q[3] - q[0]).distance + (q[2] - q[1]).distance) / 2;
    return h == 0 ? 1 : w / h;
  }

  /// Focal length in pixels of an image of [imageSize] from the EXIF of
  /// [bytes] (FocalLengthIn35mmFilm), or null.
  static double? focalPxFromExif(Uint8List bytes, Size imageSize) {
    try {
      final exif = img.decodeJpgExif(bytes);
      if (exif == null) return null;
      final v = exif.exifIfd['FocalLengthIn35mmFilm'] ??
          exif.exifIfd[0xA405] ??
          exif.imageIfd[0xA405];
      final f35 = v?.toInt();
      if (f35 == null || f35 <= 0) return null;
      return focalPxFor(f35.toDouble(), imageSize);
    } catch (_) {
      return null;
    }
  }

  static List<double> _h(Offset p) => [p.dx, p.dy, 1];
  static List<double> _cross(List<double> a, List<double> b) => [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
      ];
  static double _dot(List<double> a, List<double> b) =>
      a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}
