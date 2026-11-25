import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'frame_detector.dart';

/// Something about a photo that makes a retake worthwhile.
enum ZPhotoIssue {
  /// Strong reflection (clipped white blobs) on the artwork.
  glare,

  /// Part of the frame is outside the photo.
  cornersMissing,

  /// The photo is too dark.
  tooDark,

  /// The photo is out of focus or shaken.
  blurry,
}

/// Checks a photo for problems worth a calm hint in the frame step. Runs
/// after frame detection; never blocks the user.
abstract class ZPhotoChecker {
  const ZPhotoChecker();

  /// The single most useful hint for [imageBytes] (with the detector's
  /// [candidates], normalized TL/TR/BR/BL), or null when the photo is fine.
  Future<ZPhotoIssue?> check(
    Uint8List imageBytes,
    List<ZFrameCandidate> candidates,
  );
}

/// Simple whole-photo measurements behind the hints.
class ZPhotoMetrics {
  /// Mean luma (0..255) of the photo.
  final double meanLuma;

  /// 95th percentile luma (0..255) of the photo.
  final double p95Luma;

  /// Share (0..1) of clipped, colourless pixels inside the artwork region.
  final double glareFraction;

  /// Variance of the 3x3 Laplacian of the grey image (focus measure).
  final double laplacianVariance;

  /// 99.5th percentile of |Laplacian|: the strongest edges in the photo.
  final double laplacianP995;

  const ZPhotoMetrics({
    required this.meanLuma,
    required this.p95Luma,
    required this.glareFraction,
    required this.laplacianVariance,
    required this.laplacianP995,
  });

  @override
  String toString() => 'ZPhotoMetrics(mean ${meanLuma.toStringAsFixed(1)}, '
      'p95 ${p95Luma.toStringAsFixed(1)}, '
      'glare ${(glareFraction * 100).toStringAsFixed(2)} %, '
      'lapVar ${laplacianVariance.toStringAsFixed(1)}, '
      'lapP99.5 ${laplacianP995.toStringAsFixed(1)})';
}

/// The default [ZPhotoChecker]: pure Dart measurements on a copy of the
/// photo scaled to [analysisSide] px, no OpenCV.
///
/// Order when several apply (only one hint is shown): glare, corners
/// missing, too dark, blurry.
class ZPhotoQuality extends ZPhotoChecker {
  const ZPhotoQuality();

  /// Longest side the photo is analysed at.
  static const int analysisSide = 512;

  /// Luma at or above which a colourless pixel counts as clipped glare.
  static const int glareLuma = 245;

  /// Max channel spread of a glare pixel (reflections are colourless).
  static const int glareChroma = 30;

  /// Glare share of the artwork region that triggers the hint. Above
  /// [glareMaxFraction] the artwork itself is white (or the photo is
  /// overexposed), which a retake to the side won't change.
  static const double glareMinFraction = 0.015;
  static const double glareMaxFraction = 0.5;

  /// Too dark: mean luma below this and the brightest 5 % below
  /// [darkP95Luma].
  static const double darkMeanLuma = 55;
  static const double darkP95Luma = 130;

  /// Blurry: low Laplacian variance AND no strong edge anywhere (a calm,
  /// flat painting still has the frame's sharp edges).
  static const double blurVariance = 60;
  static const double blurP995 = 40;

  /// A corner closer than this (normalized) to the photo's edge counts as
  /// cut off.
  static const double edgeMargin = 0.004;

  @override
  Future<ZPhotoIssue?> check(
    Uint8List imageBytes,
    List<ZFrameCandidate> candidates,
  ) async {
    final rgba = await _decodeSmall(imageBytes);
    if (rgba == null) return cornersMissing(candidates) ? _corners : null;
    final m = measureRgba(
      rgba.$1,
      rgba.$2,
      rgba.$3,
      region: artworkRegion(candidates),
    );
    return classify(m, candidates: candidates);
  }

  static const _corners = ZPhotoIssue.cornersMissing;

  /// The hint for [m] and [candidates], or null.
  static ZPhotoIssue? classify(
    ZPhotoMetrics m, {
    List<ZFrameCandidate> candidates = const [],
  }) {
    if (isGlare(m)) return ZPhotoIssue.glare;
    if (cornersMissing(candidates)) return ZPhotoIssue.cornersMissing;
    if (isTooDark(m)) return ZPhotoIssue.tooDark;
    if (isBlurry(m)) return ZPhotoIssue.blurry;
    return null;
  }

  static bool isGlare(ZPhotoMetrics m) =>
      m.glareFraction >= glareMinFraction &&
      m.glareFraction <= glareMaxFraction;

  static bool isTooDark(ZPhotoMetrics m) =>
      m.meanLuma < darkMeanLuma && m.p95Luma < darkP95Luma;

  static bool isBlurry(ZPhotoMetrics m) =>
      !isTooDark(m) &&
      m.laplacianVariance < blurVariance &&
      m.laplacianP995 < blurP995;

  /// Whether the outermost candidate touches the photo's edge.
  static bool cornersMissing(List<ZFrameCandidate> candidates) {
    if (candidates.isEmpty) return false;
    final outer = candidates.reduce(
      (a, b) => _area(a.corners) >= _area(b.corners) ? a : b,
    );
    // The whole photo as a "candidate" is no evidence of anything.
    final touching = outer.corners.where(_onEdge).length;
    return touching > 0 && touching < 4;
  }

  static bool _onEdge(ui.Offset p) =>
      p.dx <= edgeMargin ||
      p.dy <= edgeMargin ||
      p.dx >= 1 - edgeMargin ||
      p.dy >= 1 - edgeMargin;

  /// The region checked for glare: the outermost candidate's bounds, else
  /// the middle 80 % of the photo (normalized).
  static ui.Rect artworkRegion(List<ZFrameCandidate> candidates) {
    if (candidates.isEmpty) return const ui.Rect.fromLTRB(0.1, 0.1, 0.9, 0.9);
    final outer = candidates.reduce(
      (a, b) => _area(a.corners) >= _area(b.corners) ? a : b,
    );
    var l = 1.0, t = 1.0, r = 0.0, b = 0.0;
    for (final p in outer.corners) {
      l = math.min(l, p.dx);
      t = math.min(t, p.dy);
      r = math.max(r, p.dx);
      b = math.max(b, p.dy);
    }
    return ui.Rect.fromLTRB(l, t, r, b);
  }

  static double _area(List<ui.Offset> q) {
    var s = 0.0;
    for (var i = 0; i < q.length; i++) {
      final a = q[i], b = q[(i + 1) % q.length];
      s += a.dx * b.dy - b.dx * a.dy;
    }
    return s.abs() / 2;
  }

  /// Measures an RGBA photo of [width] x [height]; [region] (normalized)
  /// limits the glare count to the artwork.
  static ZPhotoMetrics measureRgba(
    Uint8List rgba,
    int width,
    int height, {
    ui.Rect region = const ui.Rect.fromLTRB(0, 0, 1, 1),
  }) {
    final n = width * height;
    final luma = Uint8List(n);
    final hist = List<int>.filled(256, 0);
    var sum = 0.0;
    var glare = 0, regionCount = 0;
    final rl = (region.left * width).floor(),
        rt = (region.top * height).floor(),
        rr = (region.right * width).ceil(),
        rb = (region.bottom * height).ceil();
    for (var y = 0; y < height; y++) {
      final inY = y >= rt && y < rb;
      for (var x = 0; x < width; x++) {
        final i = y * width + x, o = i * 4;
        final r = rgba[o], g = rgba[o + 1], b = rgba[o + 2];
        final yv = (299 * r + 587 * g + 114 * b) ~/ 1000;
        luma[i] = yv;
        hist[yv]++;
        sum += yv;
        if (inY && x >= rl && x < rr) {
          regionCount++;
          if (yv >= glareLuma) {
            final hi = math.max(r, math.max(g, b));
            final lo = math.min(r, math.min(g, b));
            if (hi - lo <= glareChroma) glare++;
          }
        }
      }
    }

    // Laplacian (4-neighbour) on the grey image.
    final lapHist = List<int>.filled(1021, 0);
    var lapSum = 0.0, lapSq = 0.0;
    var count = 0;
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final i = y * width + x;
        final v = luma[i - 1] +
            luma[i + 1] +
            luma[i - width] +
            luma[i + width] -
            4 * luma[i];
        lapSum += v;
        lapSq += v * v;
        lapHist[v.abs()]++;
        count++;
      }
    }
    final lapMean = count == 0 ? 0.0 : lapSum / count;
    final lapVar = count == 0 ? 0.0 : lapSq / count - lapMean * lapMean;

    return ZPhotoMetrics(
      meanLuma: n == 0 ? 0 : sum / n,
      p95Luma: _percentile(hist, n, 0.95).toDouble(),
      glareFraction: regionCount == 0 ? 0 : glare / regionCount,
      laplacianVariance: lapVar,
      laplacianP995: _percentile(lapHist, count, 0.995).toDouble(),
    );
  }

  static int _percentile(List<int> hist, int total, double q) {
    if (total == 0) return 0;
    final target = q * total;
    var acc = 0;
    for (var i = 0; i < hist.length; i++) {
      acc += hist[i];
      if (acc >= target) return i;
    }
    return hist.length - 1;
  }

  /// Decodes [bytes] scaled to at most [analysisSide] px; RGBA, w, h.
  static Future<(Uint8List, int, int)?> _decodeSmall(Uint8List bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width, h = descriptor.height;
      final scale = analysisSide / math.max(w, h);
      final codec = await descriptor.instantiateCodec(
        targetWidth: scale < 1 ? math.max(1, (w * scale).round()) : null,
        targetHeight: scale < 1 ? math.max(1, (h * scale).round()) : null,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final out = (data!.buffer.asUint8List(), image.width, image.height);
      image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      return out;
    } catch (_) {
      return null;
    }
  }
}
