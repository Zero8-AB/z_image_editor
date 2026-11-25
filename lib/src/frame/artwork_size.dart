import 'dart:math' as math;

/// Where an artwork size comes from.
enum ZSizeSource {
  /// Guessed from the photo's shape and the common sizes (shown with ≈).
  estimated,

  /// Typed or picked by the user in the size sheet.
  confirmed,

  /// Measured by the phone (depth sensor).
  measured,

  /// Known from the artwork's details (form fields).
  details,
}

/// Real size of an artwork in centimetres: always height × width × depth.
class ZArtworkSize {
  final double heightCm;
  final double widthCm;

  /// Null = not given (the size sheet defaults to 2 cm).
  final double? depthCm;
  final ZSizeSource source;

  const ZArtworkSize({
    required this.heightCm,
    required this.widthCm,
    this.depthCm,
    this.source = ZSizeSource.confirmed,
  });

  /// Whether the numbers are known (not a guess): no "≈".
  bool get isExact => source != ZSizeSource.estimated;

  /// Height / width.
  double get aspectHW => heightCm / widthCm;

  ZArtworkSize copyWith({
    double? heightCm,
    double? widthCm,
    double? depthCm,
    ZSizeSource? source,
  }) =>
      ZArtworkSize(
        heightCm: heightCm ?? this.heightCm,
        widthCm: widthCm ?? this.widthCm,
        depthCm: depthCm ?? this.depthCm,
        source: source ?? this.source,
      );

  /// "50 × 40" (no unit), numbers without trailing ".0".
  String get hwText => '${formatCm(heightCm)} × ${formatCm(widthCm)}';

  @override
  bool operator ==(Object other) =>
      other is ZArtworkSize &&
      other.heightCm == heightCm &&
      other.widthCm == widthCm &&
      other.depthCm == depthCm &&
      other.source == source;

  @override
  int get hashCode => Object.hash(heightCm, widthCm, depthCm, source);

  @override
  String toString() => 'ZArtworkSize($hwText × ${depthCm ?? '-'} cm, $source)';
}

/// "50", "0.1", "42.5" (one decimal at most, no trailing zero).
String formatCm(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
}

/// Parses "50", "50,5", "≈ 2", " 40 cm"; null when empty/invalid/<= 0.
double? parseCm(String text) {
  final t =
      text.replaceAll('≈', '').replaceAll('cm', '').replaceAll(',', '.').trim();
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  return v == null || v <= 0 ? null : v;
}

/// A common artwork / paper size, height × width in portrait orientation.
class ZCommonSize {
  final String? name;
  final double heightCm;
  final double widthCm;

  const ZCommonSize(this.heightCm, this.widthCm, [this.name]);

  /// The same size turned to landscape (wide art).
  ZCommonSize get landscape => ZCommonSize(widthCm, heightCm, name);

  double get aspectHW => heightCm / widthCm;

  /// "50 × 40", "A3 · 42 × 30".
  String get label =>
      '${name == null ? '' : '$name · '}${formatCm(heightCm)} × ${formatCm(widthCm)}';
}

/// Common sizes and how they are matched to a photo's shape.
class ZCommonSizes {
  ZCommonSizes._();

  static const portrait = [
    ZCommonSize(40, 30),
    ZCommonSize(50, 40),
    ZCommonSize(70, 50),
    ZCommonSize(100, 70),
    ZCommonSize(42, 30, 'A3'),
    ZCommonSize(30, 21, 'A4'),
  ];

  /// How close (relative) a size's shape must be to count as a match.
  static const double tolerance = 0.05;

  /// The list oriented like the artwork: portrait sizes for upright art
  /// (H ≥ W), landscape for wide art.
  static List<ZCommonSize> forAspect(double aspectHW) =>
      aspectHW >= 1 ? portrait : [for (final s in portrait) s.landscape];

  /// Relative shape difference (0 = same shape).
  static double shapeDiff(double a, double b) =>
      (math.log(a) - math.log(b)).abs();

  /// The best-matching common size for [aspectHW], or null when no size
  /// is within [tolerance].
  static ZCommonSize? bestFit(double aspectHW) {
    ZCommonSize? best;
    var bestDiff = double.infinity;
    for (final s in forAspect(aspectHW)) {
      final d = shapeDiff(s.aspectHW, aspectHW);
      if (d < bestDiff - 1e-9) {
        best = s;
        bestDiff = d;
      }
    }
    return bestDiff <= tolerance ? best : null;
  }

  /// "about 5 : 4", "wide, about 1 : 4" — the shape as small whole numbers
  /// (H : W).
  static String ratioText(double aspectHW) {
    var bestP = 1, bestQ = 1;
    var bestErr = double.infinity;
    for (var q = 1; q <= 10; q++) {
      final p = (aspectHW * q).round();
      if (p < 1 || p > 10) continue;
      final err = shapeDiff(p / q, aspectHW);
      if (err < bestErr - 1e-9) {
        bestErr = err;
        bestP = p;
        bestQ = q;
      }
    }
    final g = _gcd(bestP, bestQ);
    final text = 'about ${bestP ~/ g} : ${bestQ ~/ g}';
    if (aspectHW < 0.6) return 'wide, $text';
    if (aspectHW > 1.7) return 'tall, $text';
    return text;
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
}

/// Depth quick picks (cm).
class ZDepthPreset {
  final String label;
  final double cm;
  const ZDepthPreset(this.label, this.cm);

  static const all = [
    ZDepthPreset('Paper', 0.1),
    ZDepthPreset('Canvas', 2),
    ZDepthPreset('Deep canvas', 4),
    ZDepthPreset('Framed', 3),
  ];

  /// Default depth when nothing is known.
  static const double defaultCm = 2;
}
