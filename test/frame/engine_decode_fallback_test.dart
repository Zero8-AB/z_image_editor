import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/z_image_editor.dart';

import '../helpers.dart';

/// The start of a HEIC file: an ISO-BMFF "ftyp" box with the heic brand.
Uint8List heicHeader() => Uint8List.fromList([
      0x00, 0x00, 0x00, 0x18, ...'ftypheic'.codeUnits, //
      0x00, 0x00, 0x00, 0x00, ...'mif1heic'.codeUnits,
    ]);

/// A JPEG stored landscape (200 × 100) with EXIF orientation 6 (shown
/// portrait, 100 × 200).
Uint8List rotatedJpeg() {
  final im = img.Image(width: 200, height: 100);
  img.fill(im, color: img.ColorRgb8(200, 60, 60));
  img.fillRect(im,
      x1: 0, y1: 0, x2: 49, y2: 99, color: img.ColorRgb8(20, 20, 220));
  im.exif.imageIfd.orientation = 6;
  return Uint8List.fromList(img.encodeJpg(im));
}

const inset = [
  Offset(0.1, 0.1),
  Offset(0.9, 0.1),
  Offset(0.9, 0.9),
  Offset(0.1, 0.9),
];

/// Makes the `image` package "unable" to read anything, as with HEIC.
void forceEngineDecode() {
  final original = ZPerspectiveWarp.decodesInDart;
  ZPerspectiveWarp.decodesInDart = (_) => false;
  addTearDown(() => ZPerspectiveWarp.decodesInDart = original);
}

void main() {
  group('decodesInDart', () {
    test('HEIC goes to the engine, JPEG and PNG to the image package', () {
      expect(ZPerspectiveWarp.decodesInDart(heicHeader()), isFalse);
      expect(ZPerspectiveWarp.decodesInDart(testPng()), isTrue);
      expect(ZPerspectiveWarp.decodesInDart(rotatedJpeg()), isTrue);
    });
  });

  group('warpRgbaSync', () {
    Uint8List rgba(int w, int h, {int alpha = 255}) {
      final b = Uint8List(w * h * 4);
      for (var i = 0; i < b.length; i += 4) {
        b[i] = 120;
        b[i + 1] = 80;
        b[i + 2] = 40;
        b[i + 3] = alpha;
      }
      return b;
    }

    test('opaque pixels give a JPEG of the same size as the Dart path', () {
      final out =
          ZPerspectiveWarp.warpRgbaSync(rgba(300, 400), 300, 400, inset);
      final jpg = img.decodeJpg(out);
      expect(jpg, isNotNull);
      final viaDart =
          img.decodeImage(ZPerspectiveWarp.warpBytesSync(testPng(), inset))!;
      expect([jpg!.width, jpg.height], [viaDart.width, viaDart.height]);
      expect(jpg.getPixel(10, 10).r, closeTo(120, 6));
    });

    test('transparent pixels give a PNG with alpha', () {
      final out = ZPerspectiveWarp.warpRgbaSync(
          rgba(40, 40, alpha: 128), 40, 40, ZQuadMath.fullImage);
      final png = img.decodePng(out)!;
      expect(png.numChannels, 4);
      expect(png.getPixel(5, 5).a, 128);
    });

    test('a short buffer is a FormatException', () {
      expect(() => ZPerspectiveWarp.warpRgbaSync(Uint8List(10), 40, 40, inset),
          throwsFormatException);
    });
  });

  group('warpBytes engine fallback', () {
    testWidgets('bytes the image package cannot read are warped via the engine',
        (tester) async {
      forceEngineDecode();
      final out = await tester
          .runAsync(() => ZPerspectiveWarp.warpBytes(testPng(), inset));
      final viaDart =
          img.decodeImage(ZPerspectiveWarp.warpBytesSync(testPng(), inset))!;
      final decoded = img.decodeJpg(out!)!;
      expect([decoded.width, decoded.height], [viaDart.width, viaDart.height]);
      // Same content: the dark inner rectangle in the middle.
      final mid = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
      expect(mid.r, lessThan(40));
    });

    testWidgets('the engine applies EXIF orientation like the Dart path',
        (tester) async {
      final jpeg = rotatedJpeg();
      final viaDart = img.decodeImage(
          ZPerspectiveWarp.warpBytesSync(jpeg, ZQuadMath.fullImage))!;
      expect([viaDart.width, viaDart.height], [100, 200]);
      forceEngineDecode();
      final out = await tester.runAsync(
          () => ZPerspectiveWarp.warpBytes(jpeg, ZQuadMath.fullImage));
      final viaEngine = img.decodeImage(out!)!;
      expect([viaEngine.width, viaEngine.height], [100, 200]);
      // The blue band (stored on the left) is on top after turning.
      expect(viaEngine.getPixel(50, 10).b, greaterThan(150));
      expect(viaEngine.getPixel(50, 190).r, greaterThan(150));
    });

    testWidgets('the engine output is capped like the Dart path',
        (tester) async {
      forceEngineDecode();
      final out = await tester.runAsync(() => ZPerspectiveWarp.warpBytes(
          testPng(w: 600, h: 800), ZQuadMath.fullImage,
          maxSide: 200));
      final decoded = img.decodeImage(out!)!;
      expect(decoded.height, 200);
      expect(decoded.width, 150);
    });

    testWidgets('undecodable bytes still throw a FormatException',
        (tester) async {
      Object? error;
      await tester.runAsync(() async {
        try {
          await ZPerspectiveWarp.warpBytes(heicHeader(), inset);
        } catch (e) {
          error = e;
        }
      });
      expect(error, isA<FormatException>());
    });
  });

  group('frame step Next', () {
    Future<FrameCropResult?> pumpAndNext(
      WidgetTester tester, {
      Uint8List? bytes,
      ZFrameCropLabels labels = const ZFrameCropLabels(),
    }) async {
      FrameCropResult? result;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: FrameCropView(
            imageBytes: bytes ?? testPng(),
            labels: labels,
            previous: const FrameCropResult(
              outputBytes: null,
              corners: inset,
              candidates: [],
            ),
            onCancel: () {},
            onContinue: (r) => result = r,
          ),
        ));
      });
      await settleAsync(tester, 5);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('z_frame_continue')));
        for (var i = 0; i < 50 && result == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pump();
      return result;
    }

    testWidgets(
        'a photo only the engine can read (HEIC) is warped, not an error',
        (tester) async {
      forceEngineDecode();
      final result = await pumpAndNext(tester);
      expect(find.text('Failed to process image'), findsNothing);
      expect(result, isNotNull);
      final out = img.decodeImage(result!.outputBytes!);
      expect(out, isNotNull);
      expect(out!.width, greaterThan(0));
    });

    testWidgets('the error dialog uses the labels', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: FrameCropView(
            imageBytes: testPng(),
            labels: const ZFrameCropLabels(
              processErrorTitle: 'Oops',
              processErrorMessage: 'Could not crop',
              processErrorOk: 'Close',
            ),
            previous: const FrameCropResult(
              outputBytes: null,
              corners: inset,
              candidates: [],
            ),
            onCancel: () {},
            onContinue: (_) {},
            warp: (b, c) async => throw const FormatException('bad'),
          ),
        ));
      });
      await settleAsync(tester, 5);
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      // The header spinner keeps animating while the dialog is open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Oops'), findsOneWidget);
      expect(find.text('Could not crop'), findsOneWidget);
      expect(find.text('Failed to process image'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Oops'), findsNothing);
    });

    test('default labels keep the English text', () {
      const l = ZFrameCropLabels();
      expect(l.processErrorTitle, 'Error');
      expect(l.processErrorMessage, 'Failed to process image');
      expect(l.processErrorOk, 'OK');
    });
  });
}
