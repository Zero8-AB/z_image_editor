import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// One-tap "Auto" colour fix for photographed artwork: per-channel black /
/// white stretch, white balance from the brightest neutral area (the white
/// mat or paper) and a mild contrast boost.
///
/// The fix is a per-channel affine map (`out = gain * in + offset`), so it
/// is a colour matrix: the live preview, the loupe and the export apply the
/// same numbers (WYSIWYG).
class ZAutoLevels {
  /// Gains for R, G, B.
  final List<double> gain;

  /// Offsets (0..255 scale) for R, G, B.
  final List<double> offset;

  /// Whether the photo looked hazy (washed out); the editor then turns Auto
  /// on by itself.
  final bool hazy;

  const ZAutoLevels({
    required this.gain,
    required this.offset,
    this.hazy = false,
  });

  /// Longest side the photo is analysed at.
  static const int analysisSide = 256;

  /// Ignored share at each end of a channel's histogram.
  static const double clip = 0.005;

  /// Largest stretch (keeps noise in dark photos in check).
  static const double maxGain = 2.5;

  /// Largest white-balance correction per channel (±).
  static const double maxBalance = 0.15;

  /// Mild contrast added after the stretch.
  static const double contrast = 1.06;

  /// Hazy: the darkest tones are lifted (1st percentile luma at least this)
  /// and the tonal range is short (99th − 1st percentile below
  /// [hazyRange]).
  static const double hazyBlack = 28;
  static const double hazyRange = 200;

  /// Hazy as well: the white mat / paper is visibly tinted (a white-balance
  /// correction of at least this much on a channel).
  static const double matCast = 0.06;

  /// The 6 numbers stored in the editor state: gains then offsets.
  List<double> get values => [...gain, ...offset];

  /// From [values] (see [values]).
  static ZAutoLevels fromValues(List<double> v) =>
      ZAutoLevels(gain: v.sublist(0, 3), offset: v.sublist(3, 6));

  /// Whether the fix changes anything visible.
  bool get isNoop {
    for (var c = 0; c < 3; c++) {
      if ((gain[c] - 1).abs() > 0.02 || offset[c].abs() > 2) return false;
    }
    return true;
  }

  /// Applies the fix to one 0..255 channel value.
  double apply(int channel, double v) =>
      (gain[channel] * v + offset[channel]).clamp(0, 255).toDouble();

  /// Analyses an RGBA image of [width] x [height].
  static ZAutoLevels analyzeRgba(Uint8List rgba, int width, int height) {
    final n = width * height;
    final hist = [
      List<int>.filled(256, 0),
      List<int>.filled(256, 0),
      List<int>.filled(256, 0),
    ];
    final lumaHist = List<int>.filled(256, 0);
    for (var i = 0; i < n; i++) {
      final o = i * 4;
      final r = rgba[o], g = rgba[o + 1], b = rgba[o + 2];
      hist[0][r]++;
      hist[1][g]++;
      hist[2][b]++;
      lumaHist[(299 * r + 587 * g + 114 * b) ~/ 1000]++;
    }

    // 1. Per-channel stretch of [lo, hi] to [0, 255].
    final g1 = List<double>.filled(3, 1), o1 = List<double>.filled(3, 0);
    for (var c = 0; c < 3; c++) {
      final lo = _percentile(hist[c], n, clip).toDouble();
      final hi = _percentile(hist[c], n, 1 - clip).toDouble();
      final range = math.max(hi - lo, 255 / maxGain);
      g1[c] = 255 / range;
      o1[c] = -lo * g1[c];
    }

    // 2. White balance: the brightest, nearly neutral pixels (white mat,
    // paper) should come out neutral after the stretch.
    final lumaP90 = _percentile(lumaHist, n, 0.9);
    final sum = [0.0, 0.0, 0.0];
    var count = 0;
    for (var i = 0; i < n; i++) {
      final o = i * 4;
      final r = rgba[o], g = rgba[o + 1], b = rgba[o + 2];
      final y = (299 * r + 587 * g + 114 * b) ~/ 1000;
      if (y < lumaP90 || y >= 254) continue;
      final hi = math.max(r, math.max(g, b)), lo = math.min(r, math.min(g, b));
      if (hi - lo > 40) continue;
      sum[0] += r;
      sum[1] += g;
      sum[2] += b;
      count++;
    }
    final k = [1.0, 1.0, 1.0];
    var tinted = false;
    if (count >= n * 0.01) {
      final m = [
        for (var c = 0; c < 3; c++) g1[c] * sum[c] / count + o1[c],
      ];
      final target = (m[0] + m[1] + m[2]) / 3;
      for (var c = 0; c < 3; c++) {
        if (m[c] > 1) {
          k[c] = (target / m[c]).clamp(1 - maxBalance, 1 + maxBalance);
          if ((k[c] - 1).abs() >= matCast) tinted = true;
        }
      }
    }

    // 3. Mild contrast around the middle.
    final gain = [
      for (var c = 0; c < 3; c++) contrast * k[c] * g1[c],
    ];
    final offset = [
      for (var c = 0; c < 3; c++)
        contrast * k[c] * o1[c] + (1 - contrast) * 127.5,
    ];

    final p1 = _percentile(lumaHist, n, 0.01);
    final p99 = _percentile(lumaHist, n, 0.99);
    final fix = ZAutoLevels(gain: gain, offset: offset);
    final lifted = p1 >= hazyBlack && p99 - p1 < hazyRange;
    final hazy = !fix.isNoop && (lifted || tinted);
    return ZAutoLevels(gain: gain, offset: offset, hazy: hazy);
  }

  /// Analyses encoded image [bytes] (decoded small by the engine); null if
  /// they can't be decoded.
  static Future<ZAutoLevels?> fromBytes(Uint8List bytes) async {
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
      final result =
          analyzeRgba(data!.buffer.asUint8List(), image.width, image.height);
      image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      return result;
    } catch (_) {
      return null;
    }
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
}
