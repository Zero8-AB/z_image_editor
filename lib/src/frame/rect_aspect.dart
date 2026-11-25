import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:image/image.dart' as img;

/// Recovers the real width : height of a photographed rectangle from its
/// four image corners (Zhang & He, "Whiteboard scanning and image
/// enhancement", 2007): the quad is the image of a rectangle under a
/// pinhole camera with square pixels and the principal point at the image
/// centre. With the focal length known (EXIF), the ratio is exact; without
/// it the focal length is solved from the quad itself (needs real
/// perspective), else a typical phone lens is assumed.
class ZRectAspect {
  ZRectAspect._();

  /// Typical phone main camera, 35 mm-equivalent focal length.
  static const double fallbackFocal35mm = 26;

  /// Width / height of the rectangle whose image is [quad] (TL, TR, BR, BL
  /// in pixels of an image of [imageSize]). [focalPx] is the focal length in
  /// the same pixels; null = solve it, then fall back to
  /// [fallbackFocal35mm].
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
    if (f == null && perspective) {
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
        final f35 = solved * 36 / math.max(imageSize.width, imageSize.height);
        if (f35 >= 13 && f35 <= 120) f = solved;
      }
    }
    f ??= fallbackFocal35mm * math.max(imageSize.width, imageSize.height) / 36;

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
      return f35 * math.max(imageSize.width, imageSize.height) / 36;
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
