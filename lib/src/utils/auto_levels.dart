import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// One-tap "Auto" colour fix for photographed artwork. Gentle by design:
///
/// - one gain and offset for all three channels, from luma, so hues are
///   kept;
/// - the white point (99.5th percentile of luma) is lifted to at least
///   [whiteTarget], by at most [maxWhiteLift]: whites are only ever lifted,
///   never darkened (dark artworks without a white, top below
///   [minWhiteTop], are not given one);
/// - the black point is lowered by [blackShare] of its lift above
///   [blackFloor], at most [maxBlackCut] levels, and at most
///   [maxBlackCutAtWhite] when the top is already at [whiteTopAt] or more;
/// - no extra contrast;
/// - white balance only from a real neutral white (at least
///   [neutralShare] of the pixels, channel spread at most
///   [neutralSpread]), at half strength ([balanceStrength]) and at most
///   [maxBalance] per channel.
///
/// It never switches itself on: a histogram cannot tell a hazy photo from a
/// pale drawing on paper. [hazy] is always false.
///
/// The fix is a per-channel affine map (`out = gain * in + offset`), so it
/// is a colour matrix: the live preview, the loupe and the export apply the
/// same numbers (WYSIWYG).
class ZAutoLevels {
  /// Gains for R, G, B.
  final List<double> gain;

  /// Offsets (0..255 scale) for R, G, B.
  final List<double> offset;

  /// Always false from [analyzeRgba]: Auto is never turned on by the
  /// editor, only by the user.
  @Deprecated('Auto never turns itself on; always false from analyzeRgba.')
  final bool hazy;

  const ZAutoLevels({
    required this.gain,
    required this.offset,
    @Deprecated('Auto never turns itself on.') this.hazy = false,
  });

  /// Longest side the photo is analysed at.
  static const int analysisSide = 256;

  /// Ignored share at the top of the luma histogram (white point at the
  /// 99.5th percentile).
  static const double clip = 0.005;

  /// Share at the bottom of the luma histogram for the black point (1st
  /// percentile).
  static const double blackClip = 0.01;

  /// The white point is lifted to at least this.
  static const double whiteTarget = 235;

  /// Largest lift of the white point (`whiteTarget / top`).
  static const double maxWhiteLift = 1.25;

  /// Below this top (a dark artwork) no white is invented.
  static const double minWhiteTop = 150;

  /// The black cut starts above this level.
  static const double blackFloor = 20;

  /// Share of the black lift (above [blackFloor]) that is removed.
  static const double blackShare = 0.6;

  /// Largest black cut (levels): haze and pale paper look the same in a
  /// histogram.
  static const double maxBlackCut = 24;

  /// Largest black cut when the top is already at [whiteTopAt] or more.
  static const double maxBlackCutAtWhite = 8;

  /// A top at this level or more is already white.
  static const double whiteTopAt = 245;

  /// Largest overall gain.
  static const double maxGain = 1.45;

  /// Largest white-balance correction per channel (±).
  static const double maxBalance = 0.06;

  /// Strength of the white balance (half way to neutral).
  static const double balanceStrength = 0.5;

  /// The neutral white must cover at least this share of the pixels.
  static const double neutralShare = 0.03;

  /// Largest channel spread (max − min) of a neutral white pixel.
  static const double neutralSpread = 28;

  /// A neutral white pixel has at least this luma.
  static const double neutralMinLuma = 170;

  /// No extra contrast (was 1.06).
  @Deprecated('Auto adds no contrast; always 1.')
  static const double contrast = 1;

  /// No longer used: Auto never turns itself on.
  @Deprecated('Auto never turns itself on.')
  static const double hazyBlack = 28;

  /// No longer used: Auto never turns itself on.
  @Deprecated('Auto never turns itself on.')
  static const double hazyRange = 200;

  /// No longer used: Auto never turns itself on.
  @Deprecated('Auto never turns itself on.')
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
    final lumaHist = List<int>.filled(256, 0);
    // Transparent pixels (outside a round frame) don't count.
    var counted = 0;
    for (var i = 0; i < n; i++) {
      final o = i * 4;
      if (rgba[o + 3] < 128) continue;
      counted++;
      lumaHist[_luma(rgba[o], rgba[o + 1], rgba[o + 2])]++;
    }
    if (counted == 0) {
      return const ZAutoLevels(gain: [1, 1, 1], offset: [0, 0, 0]);
    }

    // 1. One gain and offset for all channels, from luma.
    final lo = _percentile(lumaHist, counted, blackClip).toDouble();
    final hi = _percentile(lumaHist, counted, 1 - clip).toDouble();
    // A near-black photo has no top to lift; a gain from it would black
    // out the few bright pixels.
    if (hi < 1) return const ZAutoLevels(gain: [1, 1, 1], offset: [0, 0, 0]);
    // White point: lift the top to whiteTarget (never down), at most
    // maxWhiteLift; dark artworks keep their top.
    final targetHi = hi >= minWhiteTop ? math.max(hi, whiteTarget) : hi;
    final whiteLift = math.min(targetHi / hi, maxWhiteLift);
    // Black point: part of the lift above blackFloor, capped.
    var black =
        math.min(blackShare * math.max(lo - blackFloor, 0), maxBlackCut);
    if (hi >= whiteTopAt) black = math.min(black, maxBlackCutAtWhite);
    // out = g * (v - black), with hi going to hi * whiteLift.
    final g = math.min(hi * whiteLift / math.max(hi - black, 1), maxGain);
    final gain = [g, g, g];
    final offset = [-black * g, -black * g, -black * g];

    // 2. White balance only from a real neutral white (mat, paper, wall),
    // half strength, capped.
    final lumaP90 = _percentile(lumaHist, counted, 0.9);
    final sum = [0.0, 0.0, 0.0];
    var count = 0;
    for (var i = 0; i < n; i++) {
      final o = i * 4;
      if (rgba[o + 3] < 128) continue;
      final r = rgba[o], gr = rgba[o + 1], b = rgba[o + 2];
      final y = _luma(r, gr, b);
      if (y < lumaP90 || y < neutralMinLuma || y >= 254) continue;
      final top = math.max(r, math.max(gr, b));
      final bottom = math.min(r, math.min(gr, b));
      if (top - bottom > neutralSpread) continue;
      sum[0] += r;
      sum[1] += gr;
      sum[2] += b;
      count++;
    }
    if (count >= counted * neutralShare) {
      final m = [for (final s in sum) s / count];
      final mean = (m[0] + m[1] + m[2]) / 3;
      for (var c = 0; c < 3; c++) {
        final k = (1 + balanceStrength * (mean / m[c] - 1))
            .clamp(1 - maxBalance, 1 + maxBalance);
        gain[c] *= k;
        offset[c] *= k;
      }
    }
    return ZAutoLevels(gain: gain, offset: offset);
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

  static int _luma(int r, int g, int b) =>
      (299 * r + 587 * g + 114 * b) ~/ 1000;

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
