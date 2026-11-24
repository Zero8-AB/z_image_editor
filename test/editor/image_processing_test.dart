import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:z_image_editor/image_editor.dart';
import 'package:z_image_editor/src/utils/image_processing.dart';

/// Applies a 4x5 colour matrix (as used by ColorFilter.matrix) to an RGBA
/// pixel given in 0..255.
List<double> applyMatrix(List<double> m, List<double> rgba) => [
      for (var row = 0; row < 4; row++)
        m[row * 5] * rgba[0] +
            m[row * 5 + 1] * rgba[1] +
            m[row * 5 + 2] * rgba[2] +
            m[row * 5 + 3] * rgba[3] +
            m[row * 5 + 4],
    ];

List<double> matrixOf(ColorFilter f) {
  // ColorFilter.matrix keeps its matrix in toString(); parse it back.
  final s = f.toString();
  final inner = s.substring(s.indexOf('[') + 1, s.indexOf(']'));
  return inner.split(',').map((e) => double.parse(e.trim())).toList();
}

Uint8List solidPng(int w, int h, int r, int g, int b) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(im));
}

/// Left half red, right half blue.
Uint8List splitPng(int w, int h) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(0, 0, 255));
  img.fillRect(im,
      x1: 0, y1: 0, x2: w ~/ 2 - 1, y2: h - 1, color: img.ColorRgb8(255, 0, 0));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ColorFilterMatrix', () {
    const grey = [128.0, 128.0, 128.0, 255.0];
    const red = [200.0, 40.0, 40.0, 255.0];

    test('neutral values give the identity', () {
      final m = matrixOf(ColorFilterMatrix.combined(
          brightness: 0, contrast: 1, saturation: 1));
      final out = applyMatrix(m, red);
      for (var i = 0; i < 4; i++) {
        expect(out[i], closeTo(red[i], 1e-6));
      }
    });

    test('brightness adds value/100*255 to every channel', () {
      final m = matrixOf(ColorFilterMatrix.brightness(20));
      final out = applyMatrix(m, grey);
      expect(out[0], closeTo(128 + 51, 1e-6));
      expect(out[3], 255);
    });

    test('contrast pivots around mid grey', () {
      final m = matrixOf(ColorFilterMatrix.contrast(1.5));
      expect(applyMatrix(m, const [127.5, 127.5, 127.5, 255])[0],
          closeTo(127.5, 1e-6));
      expect(applyMatrix(m, const [200, 200, 200, 255])[0],
          closeTo(127.5 + 72.5 * 1.5, 1e-6));
    });

    test('saturation 0 turns colours grey (luma weights sum to 1)', () {
      final m = matrixOf(ColorFilterMatrix.saturation(0));
      final out = applyMatrix(m, red);
      expect(out[0], closeTo(out[1], 1e-6));
      expect(out[1], closeTo(out[2], 1e-6));
      final w = applyMatrix(m, const [255, 255, 255, 255]);
      expect(w[0], closeTo(255, 1e-6));
    });

    test('combined equals saturation, then contrast, then brightness', () {
      for (final params in const [
        [25.0, 1.3, 0.6],
        [-40.0, 0.7, 1.8],
        [0.0, 2.0, 0.0],
      ]) {
        final comb = matrixOf(ColorFilterMatrix.combined(
            brightness: params[0], contrast: params[1], saturation: params[2]));
        var seq =
            applyMatrix(matrixOf(ColorFilterMatrix.saturation(params[2])), red);
        seq = applyMatrix(matrixOf(ColorFilterMatrix.contrast(params[1])), seq);
        seq =
            applyMatrix(matrixOf(ColorFilterMatrix.brightness(params[0])), seq);
        final one = applyMatrix(comb, red);
        for (var i = 0; i < 4; i++) {
          expect(one[i], closeTo(seq[i], 1e-6), reason: '$params ch $i');
        }
      }
    });
  });

  group('export (WYSIWYG renderer)', () {
    const vp = Size(400, 600);

    ImageEditorState stateFor(Size image, {CropRect? crop, double rot = 0}) {
      final c = ImageEditorController();
      c.initialize(imageBytes: Uint8List(1));
      c.setDisplaySize(vp);
      c.setImageSize(image);
      if (crop != null) c.setCropRect(crop);
      return c.state.copyWith(rotation: rot);
    }

    test('uncropped export keeps the native resolution', () async {
      final bytes = splitPng(300, 200);
      final out = await ImageProcessing.processImageToBytes(
        bytes: bytes,
        state: stateFor(const Size(300, 200)),
      );
      final decoded = img.decodePng(out)!;
      expect(decoded.width, 300);
      expect(decoded.height, 200);
      expect(decoded.getPixel(10, 100).r, greaterThan(200));
      expect(decoded.getPixel(290, 100).b, greaterThan(200));
    });

    test('crop to the left half exports only red, at native scale', () async {
      final bytes = splitPng(300, 200);
      final full = stateFor(const Size(300, 200)).cropRect!;
      final state = stateFor(
        const Size(300, 200),
        crop: CropRect(
          left: full.left,
          top: full.top,
          width: full.width / 2,
          height: full.height,
        ),
      );
      final out =
          await ImageProcessing.processImageToBytes(bytes: bytes, state: state);
      final decoded = img.decodePng(out)!;
      expect(decoded.width, 150);
      expect(decoded.height, 200);
      expect(decoded.getPixel(140, 100).r, greaterThan(200));
      expect(decoded.getPixel(140, 100).b, lessThan(60));
    });

    test('horizontal flip swaps the halves', () async {
      final bytes = splitPng(300, 200);
      final state =
          stateFor(const Size(300, 200)).copyWith(flipHorizontal: true);
      final out =
          await ImageProcessing.processImageToBytes(bytes: bytes, state: state);
      final decoded = img.decodePng(out)!;
      expect(decoded.getPixel(10, 100).b, greaterThan(200));
      expect(decoded.getPixel(290, 100).r, greaterThan(200));
    });

    test('brightness is baked into the export', () async {
      final bytes = solidPng(50, 50, 100, 100, 100);
      final state =
          stateFor(const Size(50, 50)).copyWith(brightness: 20); // +51
      final out =
          await ImageProcessing.processImageToBytes(bytes: bytes, state: state);
      final p = img.decodePng(out)!.getPixel(25, 25);
      expect(p.r, inInclusiveRange(149, 153));
    });

    test('jpeg / original formats', () async {
      final jpg =
          Uint8List.fromList(img.encodeJpg(img.decodePng(splitPng(120, 80))!));
      final state = stateFor(const Size(120, 80)).copyWith(brightness: 5);
      final asJpeg = await ImageProcessing.processImageToBytes(
          bytes: jpg, state: state, outputFormat: ImageOutputFormat.jpeg);
      expect(asJpeg.sublist(0, 2), [0xFF, 0xD8]);
      final original = await ImageProcessing.processImageToBytes(
          bytes: jpg, state: state, outputFormat: ImageOutputFormat.original);
      expect(original.sublist(0, 2), [0xFF, 0xD8]);
      final png = await ImageProcessing.processImageToBytes(
          bytes: jpg, state: state, outputFormat: ImageOutputFormat.auto);
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
    });
  });

  group('export (pixel fallback, no display size)', () {
    test('brightness +20 brightens by about 51, not to white', () async {
      final bytes = solidPng(20, 20, 100, 100, 100);
      const state = ImageEditorState(brightness: 20);
      final out =
          await ImageProcessing.processImageToBytes(bytes: bytes, state: state);
      final p = img.decodePng(out)!.getPixel(5, 5);
      expect(p.r, inInclusiveRange(140, 160));
    });

    test('brightness -20 darkens by about 51, not to black', () async {
      final bytes = solidPng(20, 20, 100, 100, 100);
      const state = ImageEditorState(brightness: -20);
      final out =
          await ImageProcessing.processImageToBytes(bytes: bytes, state: state);
      final p = img.decodePng(out)!.getPixel(5, 5);
      expect(p.r, inInclusiveRange(40, 60));
    });

    test('matches the live-preview colour matrix for all three sliders',
        () async {
      final bytes = solidPng(20, 20, 200, 40, 40);
      const state =
          ImageEditorState(brightness: 10, contrast: 1.2, saturation: 0.5);
      final out =
          await ImageProcessing.processImageToBytes(bytes: bytes, state: state);
      final p = img.decodePng(out)!.getPixel(5, 5);
      final m = matrixOf(ColorFilterMatrix.combined(
          brightness: 10, contrast: 1.2, saturation: 0.5));
      final want = applyMatrix(m, const [200, 40, 40, 255]);
      expect(p.r, closeTo(want[0].clamp(0, 255), 2));
      expect(p.g, closeTo(want[1].clamp(0, 255), 2));
      expect(p.b, closeTo(want[2].clamp(0, 255), 2));
    });

    test('rotates by 90°', () async {
      final bytes = splitPng(30, 20);
      const state = ImageEditorState(rotation: 90);
      final out =
          await ImageProcessing.processImageToBytes(bytes: bytes, state: state);
      final d = img.decodePng(out)!;
      expect(d.width, 20);
      expect(d.height, 30);
    });
  });

  test('ui codec is available in tests', () async {
    final codec = await ui.instantiateImageCodec(solidPng(2, 2, 0, 0, 0));
    expect((await codec.getNextFrame()).image.width, 2);
  });
}
