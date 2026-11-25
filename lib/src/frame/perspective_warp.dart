import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import '../utils/image_format_sniffer.dart';
import 'quad_math.dart';

/// Formats the `image` package decodes (by magic bytes).
const Set<String> _dartFormats = {'jpg', 'png', 'gif', 'webp', 'bmp', 'tiff'};

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
  /// With [ellipse] only the ellipse inscribed in the output is kept (a
  /// round or oval frame): outside it is transparent (PNG), or
  /// [outsideFill] (0xAARRGGBB, opaque; JPEG unless the source has alpha)
  /// when the result can't keep transparency.
  ///
  /// Formats the `image` package can't read (HEIC/HEIF, AVIF, …) are
  /// decoded by the engine codec instead, on the calling isolate (see
  /// [decodeWithEngine]); the warp itself still runs in the background.
  ///
  /// Throws a [FormatException] when [bytes] cannot be decoded.
  static Future<Uint8List> warpBytes(
    Uint8List bytes,
    List<Offset> corners, {
    int jpegQuality = 95,
    int? maxSide = defaultMaxOutputSide,
    double? aspectWH,
    bool ellipse = false,
    int? outsideFill,
  }) async {
    final flat = <double>[
      for (final c in corners) ...[c.dx, c.dy]
    ];
    Object? dartError;
    StackTrace? dartStack;
    if (decodesInDart(bytes)) {
      try {
        return await compute(
          _warpEntry,
          _WarpJob(bytes, null, 0, 0, flat, jpegQuality, maxSide, aspectWH,
              ellipse, outsideFill),
          debugLabel: 'z_image_editor frame warp',
        );
      } catch (e, st) {
        // A file the `image` package rejects may still be readable by the
        // engine (it is what showed the photo): try that before failing.
        dartError = e;
        dartStack = st;
      }
    }
    final ZRgbaPixels pixels;
    try {
      pixels = await decodeWithEngine(
        bytes,
        maxSide: maxSide == null ? null : (maxSide * 1.25).round(),
      );
    } catch (_) {
      if (dartError != null) Error.throwWithStackTrace(dartError, dartStack!);
      throw const FormatException('Could not decode the image');
    }
    return compute(
      _warpEntry,
      _WarpJob(null, pixels.rgba, pixels.width, pixels.height, flat,
          jpegQuality, maxSide, aspectWH, ellipse, outsideFill),
      debugLabel: 'z_image_editor frame warp',
    );
  }

  /// Whether [warpBytes] decodes [bytes] with the `image` package (by
  /// magic bytes: JPEG, PNG, GIF, WebP, BMP, TIFF). Anything else goes to
  /// the engine codec. Also used by the editor's pixel fallback export.
  /// Replaceable, e.g. in tests to force the engine path.
  static bool Function(Uint8List bytes) decodesInDart = _sniffDartFormat;

  static bool _sniffDartFormat(Uint8List bytes) =>
      _dartFormats.contains(imageExtensionFromBytes(bytes));

  /// Decodes [bytes] with the engine codec (the one that displays the
  /// photo, so EXIF orientation and coordinates match what the outline was
  /// drawn on) into straight (non-premultiplied) RGBA, the longer side
  /// scaled down to at most [maxSide].
  ///
  /// Must run on an isolate with the engine (the UI isolate). Throws when
  /// the engine can't decode [bytes].
  static Future<ZRgbaPixels> decodeWithEngine(
    Uint8List bytes, {
    int? maxSide,
  }) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (w, h) {
        final longest = math.max(w, h);
        if (maxSide == null || longest <= maxSide) {
          return ui.TargetImageSize(width: w);
        }
        return ui.TargetImageSize(width: math.max(1, w * maxSide ~/ longest));
      },
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (data == null) {
          throw const FormatException('Could not read the image pixels');
        }
        return ZRgbaPixels(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          image.width,
          image.height,
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Synchronous core of [warpBytes]; exposed for tests.
  static Uint8List warpBytesSync(
    Uint8List bytes,
    List<Offset> corners, {
    int jpegQuality = 95,
    int? maxSide = defaultMaxOutputSide,
    double? aspectWH,
    bool ellipse = false,
    int? outsideFill,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode the image');
    }
    return _warpDecoded(
      img.bakeOrientation(decoded),
      corners,
      jpegQuality: jpegQuality,
      maxSide: maxSide,
      aspectWH: aspectWH,
      ellipse: ellipse,
      outsideFill: outsideFill,
    );
  }

  /// Like [warpBytesSync] for already decoded, upright pixels ([rgba]:
  /// straight RGBA, [width] × [height], e.g. from [decodeWithEngine]).
  /// Fully opaque pixels give a JPEG, otherwise a PNG.
  static Uint8List warpRgbaSync(
    Uint8List rgba,
    int width,
    int height,
    List<Offset> corners, {
    int jpegQuality = 95,
    int? maxSide = defaultMaxOutputSide,
    double? aspectWH,
    bool ellipse = false,
    int? outsideFill,
  }) {
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
      throw const FormatException('Invalid pixel buffer');
    }
    var opaque = true;
    for (var i = 3; i < width * height * 4; i += 4) {
      if (rgba[i] != 255) {
        opaque = false;
        break;
      }
    }
    var src = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    if (opaque) src = src.convert(numChannels: 3);
    return _warpDecoded(
      src,
      corners,
      jpegQuality: jpegQuality,
      maxSide: maxSide,
      aspectWH: aspectWH,
      ellipse: ellipse,
      outsideFill: outsideFill,
    );
  }

  static Uint8List _warpDecoded(
    img.Image src,
    List<Offset> corners, {
    required int jpegQuality,
    required int? maxSide,
    required double? aspectWH,
    required bool ellipse,
    required int? outsideFill,
  }) {
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
    var out = warpImage(src, pixelQuad, maxSide: maxSide, aspectWH: aspectWH);
    if (ellipse) out = maskEllipse(out, outsideFill: outsideFill);
    return out.numChannels == 4
        ? img.encodePng(out)
        : img.encodeJpg(out, quality: jpegQuality);
  }

  /// Keeps the ellipse inscribed in [image]; outside it becomes
  /// transparent (the result has 4 channels) or [outsideFill]
  /// (0xAARRGGBB, treated as opaque). The edge is anti-aliased over about
  /// one pixel.
  static img.Image maskEllipse(img.Image image, {int? outsideFill}) {
    final fill = outsideFill;
    final channels = fill == null ? 4 : image.numChannels;
    final src =
        image.numChannels == channels && image.format == img.Format.uint8
            ? image
            : image.convert(
                format: img.Format.uint8,
                numChannels: channels,
                alpha: channels == 4 ? 255 : null,
              );
    var bytes = src.getBytes(
      order: channels == 4 ? img.ChannelOrder.rgba : img.ChannelOrder.rgb,
    );
    if (bytes.offsetInBytes != 0 ||
        bytes.buffer.lengthInBytes != bytes.length) {
      bytes = Uint8List.fromList(bytes);
    }
    final w = src.width, h = src.height;
    final rx = w / 2, ry = h / 2;
    final fr = fill == null ? 0 : (fill >> 16) & 0xFF;
    final fg = fill == null ? 0 : (fill >> 8) & 0xFF;
    final fb = fill == null ? 0 : fill & 0xFF;
    // Distance to the edge in pixels ≈ (1 − r) · min radius.
    final scale = math.min(rx, ry);
    var o = 0;
    for (var y = 0; y < h; y++) {
      final dy = (y + 0.5 - ry) / ry;
      for (var x = 0; x < w; x++) {
        final dx = (x + 0.5 - rx) / rx;
        final r = math.sqrt(dx * dx + dy * dy);
        final cover = ((1 - r) * scale + 0.5).clamp(0.0, 1.0);
        if (cover < 1) {
          if (fill == null) {
            bytes[o + 3] = (bytes[o + 3] * cover).round();
            if (cover == 0) bytes[o] = bytes[o + 1] = bytes[o + 2] = 0;
          } else {
            bytes[o] = (bytes[o] * cover + fr * (1 - cover)).round();
            bytes[o + 1] = (bytes[o + 1] * cover + fg * (1 - cover)).round();
            bytes[o + 2] = (bytes[o + 2] * cover + fb * (1 - cover)).round();
          }
        }
        o += channels;
      }
    }
    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: bytes.buffer,
      numChannels: channels,
    );
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

/// Decoded straight RGBA pixels (see [ZPerspectiveWarp.decodeWithEngine]).
class ZRgbaPixels {
  final Uint8List rgba;
  final int width;
  final int height;
  const ZRgbaPixels(this.rgba, this.width, this.height);
}

/// Either encoded [bytes] or decoded [rgba] of [width] × [height].
class _WarpJob {
  final Uint8List? bytes;
  final Uint8List? rgba;
  final int width;
  final int height;
  final List<double> corners;
  final int jpegQuality;
  final int? maxSide;
  final double? aspectWH;
  final bool ellipse;
  final int? outsideFill;
  const _WarpJob(
    this.bytes,
    this.rgba,
    this.width,
    this.height,
    this.corners,
    this.jpegQuality,
    this.maxSide,
    this.aspectWH,
    this.ellipse,
    this.outsideFill,
  );
}

Uint8List _warpEntry(_WarpJob job) {
  final corners = [
    for (var i = 0; i < 4; i++)
      Offset(job.corners[i * 2], job.corners[i * 2 + 1]),
  ];
  final bytes = job.bytes;
  if (bytes == null) {
    return ZPerspectiveWarp.warpRgbaSync(
      job.rgba!,
      job.width,
      job.height,
      corners,
      jpegQuality: job.jpegQuality,
      maxSide: job.maxSide,
      aspectWH: job.aspectWH,
      ellipse: job.ellipse,
      outsideFill: job.outsideFill,
    );
  }
  return ZPerspectiveWarp.warpBytesSync(
    bytes,
    corners,
    jpegQuality: job.jpegQuality,
    maxSide: job.maxSide,
    aspectWH: job.aspectWH,
    ellipse: job.ellipse,
    outsideFill: job.outsideFill,
  );
}
