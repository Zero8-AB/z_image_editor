import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Geometry helpers for the perspective ("frame") crop.
///
/// A quad is always a list of four points in the order top-left, top-right,
/// bottom-right, bottom-left. Pure Dart, no Flutter widgets: safe to use in
/// isolates and on every platform.
class ZQuadMath {
  ZQuadMath._();

  /// The whole image in normalized coordinates.
  static const List<Offset> fullImage = [
    Offset(0, 0),
    Offset(1, 0),
    Offset(1, 1),
    Offset(0, 1),
  ];

  /// Orders four arbitrary points as top-left, top-right, bottom-right,
  /// bottom-left.
  ///
  /// Points are sorted by angle around their centroid (which is robust for
  /// any convex quad, also strongly rotated ones), then rotated so the point
  /// with the smallest x + y comes first.
  static List<Offset> orderCorners(List<Offset> points) {
    if (points.length != 4) {
      throw ArgumentError.value(points.length, 'points', 'need 4 points');
    }
    final cx = points.fold<double>(0, (s, p) => s + p.dx) / 4;
    final cy = points.fold<double>(0, (s, p) => s + p.dy) / 4;
    // Screen coordinates (y down): increasing atan2 = clockwise on screen.
    final sorted = [...points]
      ..sort((a, b) => math.atan2(a.dy - cy, a.dx - cx).compareTo(
            math.atan2(b.dy - cy, b.dx - cx),
          ));
    var start = 0;
    for (var i = 1; i < 4; i++) {
      final p = sorted[i];
      final s = sorted[start];
      if (p.dx + p.dy < s.dx + s.dy) start = i;
    }
    return [for (var i = 0; i < 4; i++) sorted[(start + i) % 4]];
  }

  /// Signed-area-free polygon area (shoelace), always >= 0.
  static double area(List<Offset> q) {
    var a = 0.0;
    for (var i = 0; i < q.length; i++) {
      final p = q[i];
      final n = q[(i + 1) % q.length];
      a += p.dx * n.dy - n.dx * p.dy;
    }
    return a.abs() / 2;
  }

  /// Whether the quad (in TL, TR, BR, BL order) is strictly convex and
  /// non-degenerate (no three points collinear, no self-intersection).
  ///
  /// With [clockwiseOnly] the quad must also keep the on-screen (y-down)
  /// clockwise TL → TR → BR → BL winding, which rejects mirrored quads such as
  /// a top-left corner dragged past the top-right one.
  static bool isConvex(
    List<Offset> q, {
    double epsilon = 1e-9,
    bool clockwiseOnly = false,
  }) {
    if (q.length != 4) return false;
    var sign = 0;
    for (var i = 0; i < 4; i++) {
      final a = q[i];
      final b = q[(i + 1) % 4];
      final c = q[(i + 2) % 4];
      final cross =
          (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
      if (cross.abs() <= epsilon) return false;
      final s = cross > 0 ? 1 : -1;
      if (sign == 0) {
        sign = s;
      } else if (s != sign) {
        return false;
      }
    }
    return !clockwiseOnly || sign > 0;
  }

  /// Converts normalized corners to pixel coordinates of an image of [size].
  static List<Offset> denormalize(List<Offset> q, Size size) =>
      [for (final p in q) Offset(p.dx * size.width, p.dy * size.height)];

  /// Converts pixel corners of an image of [size] to normalized corners.
  static List<Offset> normalize(List<Offset> q, Size size) =>
      [for (final p in q) Offset(p.dx / size.width, p.dy / size.height)];

  /// Clamps a normalized point into the image.
  static Offset clampUnit(Offset p) =>
      Offset(p.dx.clamp(0.0, 1.0), p.dy.clamp(0.0, 1.0));

  /// Whether [q] is (within [tolerance], normalized) the whole image.
  static bool isFullImage(List<Offset> q, {double tolerance = 0.002}) {
    for (var i = 0; i < 4; i++) {
      if ((q[i] - fullImage[i]).distance > tolerance) return false;
    }
    return true;
  }

  /// Output size of the rectified image for a pixel-space quad: the longer of
  /// each pair of opposite edges, so no side is downsampled.
  ///
  /// When [maxSide] is given the result is scaled down (keeping the aspect
  /// ratio) so neither side exceeds it.
  ///
  /// With [aspectWH] (the real width / height, e.g. from the artwork's size
  /// or a perspective estimate) the output keeps the longer of the measured
  /// sides and takes the other from that ratio, so the result is not
  /// stretched.
  static Size warpOutputSize(
    List<Offset> pixelQuad, {
    int? maxSide,
    double? aspectWH,
  }) {
    final q = pixelQuad;
    var w = math.max((q[1] - q[0]).distance, (q[2] - q[3]).distance);
    var h = math.max((q[3] - q[0]).distance, (q[2] - q[1]).distance);
    if (aspectWH != null && aspectWH > 0 && aspectWH.isFinite) {
      if (w >= h) {
        h = w / aspectWH;
      } else {
        w = h * aspectWH;
      }
    }
    w = math.max(1, w.roundToDouble());
    h = math.max(1, h.roundToDouble());
    if (maxSide != null && math.max(w, h) > maxSide) {
      final s = maxSide / math.max(w, h);
      w = math.max(1, (w * s).roundToDouble());
      h = math.max(1, (h * s).roundToDouble());
    }
    return Size(w, h);
  }

  /// Projective transform taking the unit square (0,0),(1,0),(1,1),(0,1) to
  /// the quad [q] (TL, TR, BR, BL), as 8 coefficients `[a,b,c,d,e,f,g,h]`:
  ///
  ///     x = (a·u + b·v + c) / (g·u + h·v + 1)
  ///     y = (d·u + e·v + f) / (g·u + h·v + 1)
  ///
  /// (Heckbert, "Fundamentals of Texture Mapping", 1989.)
  static List<double> squareToQuad(List<Offset> q) {
    final x0 = q[0].dx, y0 = q[0].dy;
    final x1 = q[1].dx, y1 = q[1].dy;
    final x2 = q[2].dx, y2 = q[2].dy;
    final x3 = q[3].dx, y3 = q[3].dy;
    final dx3 = x0 - x1 + x2 - x3;
    final dy3 = y0 - y1 + y2 - y3;
    if (dx3.abs() < 1e-12 && dy3.abs() < 1e-12) {
      // Parallelogram: affine.
      return [x1 - x0, x2 - x1, x0, y1 - y0, y2 - y1, y0, 0, 0];
    }
    final dx1 = x1 - x2, dx2 = x3 - x2;
    final dy1 = y1 - y2, dy2 = y3 - y2;
    final det = dx1 * dy2 - dx2 * dy1;
    final g = (dx3 * dy2 - dx2 * dy3) / det;
    final h = (dx1 * dy3 - dx3 * dy1) / det;
    return [
      x1 - x0 + g * x1,
      x3 - x0 + h * x3,
      x0,
      y1 - y0 + g * y1,
      y3 - y0 + h * y3,
      y0,
      g,
      h,
    ];
  }

  /// Applies [squareToQuad] coefficients to (u, v).
  static Offset applySquareToQuad(List<double> m, double u, double v) {
    final w = m[6] * u + m[7] * v + 1;
    return Offset(
      (m[0] * u + m[1] * v + m[2]) / w,
      (m[3] * u + m[4] * v + m[5]) / w,
    );
  }

  /// Maps a normalized point of an image to the same pixel's normalized
  /// position after turning the image [quarterTurns] × 90° clockwise.
  static Offset rotatePoint(Offset p, int quarterTurns) {
    var q = p;
    for (var i = 0; i < quarterTurns % 4; i++) {
      q = Offset(1 - q.dy, q.dx);
    }
    return q;
  }

  /// Inverse of [rotatePoint].
  static Offset unrotatePoint(Offset p, int quarterTurns) {
    var q = p;
    for (var i = 0; i < quarterTurns % 4; i++) {
      q = Offset(q.dy, 1 - q.dx);
    }
    return q;
  }

  /// Turns a normalized quad with its image and re-orders it so index 0 is
  /// again the top-left corner on screen.
  static List<Offset> rotateQuad(List<Offset> q, int quarterTurns) =>
      orderCorners([for (final p in q) rotatePoint(p, quarterTurns)]);

  /// Points of the ellipse inscribed in quad [q] (TL, TR, BR, BL): the
  /// unit square's inscribed circle taken through [squareToQuad], so it
  /// touches every side and becomes a circle (in a square output) or an
  /// axis-aligned ellipse when the quad is rectified.
  static List<Offset> inscribedEllipse(List<Offset> q, {int segments = 72}) {
    final m = squareToQuad(q);
    return [
      for (var i = 0; i < segments; i++)
        applySquareToQuad(
          m,
          0.5 + 0.5 * math.cos(2 * math.pi * i / segments),
          0.5 + 0.5 * math.sin(2 * math.pi * i / segments),
        ),
    ];
  }

  /// Where the inscribed ellipse touches the sides of [q]: top, right,
  /// bottom, left (the handles of a round outline).
  static List<Offset> ellipseTouchPoints(List<Offset> q) {
    final m = squareToQuad(q);
    return [
      applySquareToQuad(m, 0.5, 0),
      applySquareToQuad(m, 1, 0.5),
      applySquareToQuad(m, 0.5, 1),
      applySquareToQuad(m, 0, 0.5),
    ];
  }
}
