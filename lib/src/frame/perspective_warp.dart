import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import 'quad_math.dart';

/// Perspective-rectifies a quad of an encoded image at full resolution.
///
/// Pure Dart (the `image` package), so it works on every platform including
/// web. On native platforms the work runs in a background isolate.
class ZPerspectiveWarp {
  ZPerspectiveWarp._();

  /// Default cap on the output's longer side. A 48 MP photo straightened at
  /// full size needs hundreds of MB; 6000 px keeps more detail than the
  /// upload pipeline uses while bounding memory.
  static const int defaultMaxOutputSide = 6000;

  /// Decodes [bytes], applies EXIF orientation, rectifies the quad given by
  /// normalized [corners] (TL, TR, BR, BL) and re-encodes the result
  /// (JPEG, or PNG when the source has an alpha channel).
  ///
  /// Throws a [FormatException] when [bytes] cannot be decoded.
  static Future<Uint8List> warpBytes(
    Uint8List bytes,
    List<Offset> corners, {
    int jpegQuality = 95,
    int? maxSide = defaultMaxOutputSide,
    double? aspectWH,
  }) {
    final flat = <double>[
      for (final c in corners) ...[c.dx, c.dy]
    ];
    return compute(
      _warpEntry,
      _WarpJob(bytes, flat, jpegQuality, maxSide, aspectWH),
      debugLabel: 'z_image_editor frame warp',
    );
  }

  /// Synchronous core of [warpBytes]; exposed for tests.
  static Uint8List warpBytesSync(
    Uint8List bytes,
    List<Offset> corners, {
    int jpegQuality = 95,
    int? maxSide = defaultMaxOutputSide,
    double? aspectWH,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode the image');
    }
    var src = img.bakeOrientation(decoded);
    // Very large sources (e.g. 48 MP) are scaled down first so the warp's
    // working copies stay bounded; the output is capped at [maxSide] anyway.
    final longest = src.width > src.height ? src.width : src.height;
    if (maxSide != null && longest > maxSide * 1.25) {
      final s = maxSide * 1.25 / longest;
      src = img.copyResize(
        src,
        width: (src.width * s).round(),
        height: (src.height * s).round(),
        interpolation: img.Interpolation.average,
      );
    }
    final pixelQuad = [
      for (final c in corners) Offset(c.dx * src.width, c.dy * src.height),
    ];
    final out = warpImage(src, pixelQuad, maxSide: maxSide, aspectWH: aspectWH);
    return out.numChannels == 4
        ? img.encodePng(out)
        : img.encodeJpg(out, quality: jpegQuality);
  }

  /// Rectifies [pixelQuad] (TL, TR, BR, BL in pixels of [src]) into a new
  /// upright image sized by [ZQuadMath.warpOutputSize]. Bilinear sampling
  /// through a true homography (straight lines stay straight, foreshortening
  /// is corrected).
  static img.Image warpImage(
    img.Image src,
    List<Offset> pixelQuad, {
    int? maxSide,
    double? aspectWH,
  }) {
    final channels = src.hasAlpha ? 4 : 3;
    // Palette (indexed, incl. 1/2/4-bit) and non-8-bit images are expanded
    // to plain 8-bit RGB(A) first: their raw bytes are indices or packed.
    final rgb = (!src.hasPalette &&
            src.format == img.Format.uint8 &&
            src.numChannels == channels)
        ? src
        : src.convert(
            format: img.Format.uint8,
            numChannels: channels,
            alpha: channels == 4 ? 255 : null,
          );
    final srcBytes = rgb.getBytes(
      order: channels == 4 ? img.ChannelOrder.rgba : img.ChannelOrder.rgb,
    );
    final sw = rgb.width, sh = rgb.height;

    final size = ZQuadMath.warpOutputSize(
      pixelQuad,
      maxSide: maxSide,
      aspectWH: aspectWH,
    );
    final ow = size.width.toInt(), oh = size.height.toInt();
    final m = ZQuadMath.squareToQuad(pixelQuad);
    final a = m[0], b = m[1], c = m[2], d = m[3], e = m[4], f = m[5];
    final g = m[6], h = m[7];

    final out = Uint8List(ow * oh * channels);
    final maxX = sw - 1, maxY = sh - 1;
    final stride = sw * channels;
    var o = 0;
    for (var j = 0; j < oh; j++) {
      final v = (j + 0.5) / oh;
      for (var i = 0; i < ow; i++) {
        final u = (i + 0.5) / ow;
        final w = g * u + h * v + 1;
        // Pixel centres: sample position minus 0.5.
        var x = (a * u + b * v + c) / w - 0.5;
        var y = (d * u + e * v + f) / w - 0.5;
        if (x < 0) x = 0;
        if (y < 0) y = 0;
        if (x > maxX) x = maxX.toDouble();
        if (y > maxY) y = maxY.toDouble();
        final x0 = x.floor(), y0 = y.floor();
        final x1 = math.min(x0 + 1, maxX), y1 = math.min(y0 + 1, maxY);
        final fx = x - x0, fy = y - y0;
        final p00 = y0 * stride + x0 * channels;
        final p10 = y0 * stride + x1 * channels;
        final p01 = y1 * stride + x0 * channels;
        final p11 = y1 * stride + x1 * channels;
        for (var k = 0; k < channels; k++) {
          final top =
              srcBytes[p00 + k] + (srcBytes[p10 + k] - srcBytes[p00 + k]) * fx;
          final bottom =
              srcBytes[p01 + k] + (srcBytes[p11 + k] - srcBytes[p01 + k]) * fx;
          out[o++] = (top + (bottom - top) * fy).round();
        }
      }
    }
    return img.Image.fromBytes(
      width: ow,
      height: oh,
      bytes: out.buffer,
      numChannels: channels,
    );
  }
}

class _WarpJob {
  final Uint8List bytes;
  final List<double> corners;
  final int jpegQuality;
  final int? maxSide;
  final double? aspectWH;
  const _WarpJob(
    this.bytes,
    this.corners,
    this.jpegQuality,
    this.maxSide,
    this.aspectWH,
  );
}

Uint8List _warpEntry(_WarpJob job) {
  final corners = [
    for (var i = 0; i < 4; i++)
      Offset(job.corners[i * 2], job.corners[i * 2 + 1]),
  ];
  return ZPerspectiveWarp.warpBytesSync(
    job.bytes,
    corners,
    jpegQuality: job.jpegQuality,
    maxSide: job.maxSide,
    aspectWH: job.aspectWH,
  );
}
