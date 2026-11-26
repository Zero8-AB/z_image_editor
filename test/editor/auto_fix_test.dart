import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:z_image_editor/image_editor.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';
import 'package:z_image_editor/src/utils/image_processing.dart';
import 'package:z_image_editor/src/widgets/image_canvas.dart';

import '../helpers.dart';

/// A washed-out photo of an artwork: lifted blacks (70), dull whites (200),
/// a slightly blue white mat around dark stripes.
Uint8List hazyPng({int w = 240, int h = 320}) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final mat = x < 30 || x >= w - 30 || y < 30 || y >= h - 30;
      if (mat) {
        im.setPixelRgb(x, y, 190, 194, 206);
      } else {
        final dark = (x ~/ 6).isEven;
        im.setPixelRgb(x, y, dark ? 70 : 170, dark ? 72 : 160, dark ? 78 : 120);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

(Uint8List, int, int) rgbaOf(Uint8List png) {
  final im = img.decodePng(png)!;
  return (
    im.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba),
    im.width,
    im.height
  );
}

const autoTheme = ZImageEditorTheme(
  toolRowTabs: true,
  chipHeight: 40,
  chipTapHeight: 44,
  chipSelectedColor: Color(0xFFCE5151),
  chipSelectedTextColor: Color(0xFFFDFDFB),
  textColor: Color(0xFFFDFDFB),
  primaryButtonTextColor: Color(0xFFFDFDFB),
);

Future<void> pumpAutoEditor(
  WidgetTester tester,
  Size size,
  Uint8List bytes, {
  void Function(List<File>)? onSave,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: ZImageEditor(
        imageBytesList: [bytes],
        enableAutoFix: true,
        theme: autoTheme,
        onSaveAll: onSave ?? (_) {},
        onCancel: () {},
      ),
    ));
  });
  await settleAsync(tester, 30);
}

Future<void> openAdjust(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('z_editor_tab_adjust')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

ImageEditorState editorState(WidgetTester tester) =>
    tester.widget<ImageCanvas>(find.byType(ImageCanvas)).controller.state;

void main() {
  group('ZAutoLevels', () {
    test('a hazy photo: gently lifted, never flagged to turn on', () {
      final (rgba, w, h) = rgbaOf(hazyPng());
      final a = ZAutoLevels.analyzeRgba(rgba, w, h);
      // ignore: deprecated_member_use_from_same_package
      expect(a.hazy, isFalse);
      expect(a.isNoop, isFalse);
      // The darkest stripe gets darker (black cut ≤ 24 levels), the mat
      // lighter and a little more neutral (half strength, ≤ 6 %).
      expect(a.apply(0, 70), inInclusiveRange(55, 68));
      final mat = [a.apply(0, 190), a.apply(1, 194), a.apply(2, 206)];
      expect(mat.reduce((x, y) => x < y ? x : y), greaterThan(225));
      final spread = mat.reduce((x, y) => x > y ? x : y) -
          mat.reduce((x, y) => x < y ? x : y);
      expect(spread, lessThan(16 * 1.25),
          reason: 'white balance from the mat: $mat');
    });

    test('a photo with full range is not flagged', () {
      final (rgba, w, h) = rgbaOf(testPng());
      // ignore: deprecated_member_use_from_same_package
      expect(ZAutoLevels.analyzeRgba(rgba, w, h).hazy, isFalse);
    });

    Uint8List rgbaFill(int n, List<int> Function(int i) px) {
      final out = Uint8List(4 * n);
      for (var i = 0; i < n; i++) {
        final p = px(i);
        out[i * 4] = p[0];
        out[i * 4 + 1] = p[1];
        out[i * 4 + 2] = p[2];
        out[i * 4 + 3] = 255;
      }
      return out;
    }

    test('a warm neutral mat is balanced gently, never flagged', () {
      // Full range 0..255 neutral ramp, plus a large yellowish mat.
      final rgba = rgbaFill(1000, (i) {
        if (i < 300) return [240, 236, 212];
        final v = (i - 300) * 255 ~/ 699;
        return [v, v, v];
      });
      final a = ZAutoLevels.analyzeRgba(rgba, 40, 25);
      // ignore: deprecated_member_use_from_same_package
      expect(a.hazy, isFalse);
      // The mat comes out more neutral, but only half way.
      final mat = [a.apply(0, 240), a.apply(1, 236), a.apply(2, 212)];
      expect(mat[0] - mat[2], lessThan(28 - 10));
      expect(mat[0] - mat[2], greaterThan(5));
      for (var c = 0; c < 3; c++) {
        expect(a.gain[c], inInclusiveRange(0.94, 1.06));
      }
    });

    test('values round-trip; stretch is capped', () {
      const a = ZAutoLevels(gain: [1.2, 1.1, 1.0], offset: [-10, -5, 0]);
      expect(ZAutoLevels.fromValues(a.values).gain, a.gain);
      expect(ZAutoLevels.fromValues(a.values).offset, a.offset);
      // A nearly flat image can't be stretched more than maxGain.
      final flat = Uint8List(4 * 100);
      for (var i = 0; i < 100; i++) {
        flat[i * 4] = flat[i * 4 + 1] = flat[i * 4 + 2] = 120 + i % 3;
        flat[i * 4 + 3] = 255;
      }
      final f = ZAutoLevels.analyzeRgba(flat, 10, 10);
      for (final g in f.gain) {
        expect(
            g,
            lessThanOrEqualTo(
                ZAutoLevels.maxGain * (1 + ZAutoLevels.maxBalance)));
      }
    });

    test('the matrix applies Auto first, then the sliders', () {
      const auto = [1.5, 1.2, 0.9, -40.0, -10.0, 5.0];
      final m = ColorFilterMatrix.combinedMatrix(
          brightness: 10, contrast: 1.2, saturation: 0.8, auto: auto);
      final u = ColorFilterMatrix.combinedMatrix(
          brightness: 10, contrast: 1.2, saturation: 0.8);
      const px = [100.0, 150.0, 200.0];
      final a = [for (var c = 0; c < 3; c++) auto[c] * px[c] + auto[3 + c]];
      for (var row = 0; row < 3; row++) {
        final seq = u[row * 5] * a[0] +
            u[row * 5 + 1] * a[1] +
            u[row * 5 + 2] * a[2] +
            u[row * 5 + 4];
        final one = m[row * 5] * px[0] +
            m[row * 5 + 1] * px[1] +
            m[row * 5 + 2] * px[2] +
            m[row * 5 + 4];
        expect(one, closeTo(seq, 1e-9));
      }
    });

    test('Auto is baked into the export (WYSIWYG)', () async {
      final c = ImageEditorController();
      c.initialize(imageBytes: Uint8List(1));
      c.setDisplaySize(const Size(400, 600));
      c.setImageSize(const Size(40, 40));
      final im = img.Image(width: 40, height: 40);
      img.fill(im, color: img.ColorRgb8(100, 100, 100));
      final bytes = Uint8List.fromList(img.encodePng(im));
      final state = c.state.copyWith(autoLevels: [2.0, 1.0, 0.5, -50, 0, 10]);
      expect(state.hasChanges, isTrue);
      final out =
          await ImageProcessing.processImageToBytes(bytes: bytes, state: state);
      final p = img.decodePng(out)!.getPixel(20, 20);
      expect(p.r, inInclusiveRange(148, 152)); // 2 * 100 - 50
      expect(p.g, inInclusiveRange(98, 102));
      expect(p.b, inInclusiveRange(58, 62)); // 0.5 * 100 + 10
    });

    test('controller: Auto on/off is undoable; the automatic setting is not',
        () {
      final c = ImageEditorController();
      c.initialize(imageBytes: Uint8List(1));
      c.setAutoLevels(const [1, 1, 1, 0, 0, 0], undoable: false);
      expect(c.canUndo, isFalse);
      c.setAutoLevels(null);
      expect(c.state.autoLevels, isNull);
      c.undo();
      expect(c.state.autoLevels, isNotNull);
    });
  });

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    group('Auto in the editor @ $s', () {
      testWidgets('hazy photo: Auto first and off, no "hazy" caption',
          (tester) async {
        await pumpAutoEditor(tester, size, hazyPng());
        await openAdjust(tester);
        final chips = ['auto', 'brightness', 'contrast', 'saturation']
            .map((k) => tester.getCenter(find.byKey(Key('z_adjust_$k'))).dx)
            .toList();
        for (var i = 1; i < chips.length; i++) {
          expect(chips[i], greaterThan(chips[i - 1]));
        }
        expect(find.text('Auto'), findsOneWidget);
        expect(find.text('Colour'), findsOneWidget);
        // Auto never turns itself on.
        expect(editorState(tester).autoLevels, isNull);
        expect(find.textContaining('hazy'), findsNothing);
        expect(find.byKey(const Key('z_compare')), findsNothing);
        expect(find.byKey(const Key('z_adjust_compare_hint')), findsNothing);
        // The user turns it on: Before/After compare.
        await tester.tap(find.byKey(const Key('z_adjust_auto')));
        await tester.pump();
        expect(editorState(tester).autoLevels, isNotNull);
        expect(find.text('Drag to compare.'), findsOneWidget);
        expect(find.textContaining('hazy'), findsNothing);
        expect(find.byKey(const Key('z_compare')), findsOneWidget);
        expect(find.text('Before'), findsOneWidget);
        expect(find.text('After'), findsOneWidget);
        expect(tester.getSize(find.byKey(const Key('z_adjust_auto'))).height,
            greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
      });

      testWidgets('dragging moves the compare line', (tester) async {
        await pumpAutoEditor(tester, size, hazyPng());
        await openAdjust(tester);
        await tester.tap(find.byKey(const Key('z_adjust_auto')));
        await tester.pump();
        final line = find.byKey(const Key('z_compare_line'));
        final x0 = tester.getCenter(line).dx;
        await dragStepwise(
            tester, tester.getCenter(line), const Offset(-60, 0));
        await tester.pump();
        expect(tester.getCenter(line).dx, lessThan(x0 - 40));
        await dragStepwise(
            tester, tester.getCenter(line), const Offset(500, 0));
        await tester.pump();
        // Clamped to the photo.
        expect(tester.getCenter(line).dx, lessThanOrEqualTo(size.width));
      });

      testWidgets('one tap turns Auto on, another turns it off again',
          (tester) async {
        await pumpAutoEditor(tester, size, hazyPng());
        await openAdjust(tester);
        expect(editorState(tester).autoLevels, isNull);
        await tester.tap(find.byKey(const Key('z_adjust_auto')));
        await tester.pump();
        expect(editorState(tester).autoLevels, isNotNull);
        expect(find.byKey(const Key('z_compare')), findsOneWidget);
        expect(find.text('Drag to compare.'), findsOneWidget);
        await tester.tap(find.byKey(const Key('z_adjust_auto')));
        await tester.pump();
        expect(editorState(tester).autoLevels, isNull);
        expect(find.byKey(const Key('z_compare')), findsNothing);
        expect(find.byKey(const Key('z_adjust_compare_hint')), findsNothing);
      });

      testWidgets('Brightness / Contrast / Colour show the ruler, no compare',
          (tester) async {
        await pumpAutoEditor(tester, size, hazyPng());
        await openAdjust(tester);
        await tester.tap(find.byKey(const Key('z_adjust_auto')));
        await tester.pump();
        for (final k in ['brightness', 'contrast', 'saturation']) {
          // The pill row scrolls when it doesn't fit.
          await tester.ensureVisible(find.byKey(Key('z_adjust_$k')));
          await tester.pump();
          await tester.tap(find.byKey(Key('z_adjust_$k')));
          await tester.pump();
          expect(tester.widget<ZChip>(find.byKey(Key('z_adjust_$k'))).selected,
              isTrue,
              reason: k);
          expect(find.byKey(const Key('z_adjust_ruler')), findsOneWidget);
          expect(find.byKey(const Key('z_compare')), findsNothing);
        }
        // The ruler changes the selected value; Auto stays on.
        await dragStepwise(
            tester,
            tester.getCenter(find.byKey(const Key('z_adjust_ruler'))),
            const Offset(-40, 0));
        expect(editorState(tester).saturation, isNot(1.0));
        expect(editorState(tester).autoLevels, isNotNull);
        // Double tap on the ruler resets the value.
        await tester.tap(find.byKey(const Key('z_adjust_ruler')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(const Key('z_adjust_ruler')));
        await tester.pump(const Duration(seconds: 1));
        expect(editorState(tester).saturation, 1.0);
      });

      testWidgets('a dark photo Auto would not change: no Auto chip, off',
          (tester) async {
        // Top at 90 (no white to lift), blacks at 20: nothing to do.
        await pumpAutoEditor(tester, size, testPng());
        await openAdjust(tester);
        expect(find.byKey(const Key('z_adjust_auto')), findsNothing);
        expect(editorState(tester).autoLevels, isNull);
        expect(find.byKey(const Key('z_compare')), findsNothing);
      });
    });
  }

  testWidgets('Save exports with Auto applied (turned on by the user)',
      (tester) async {
    List<File>? saved;
    await pumpAutoEditor(tester, const Size(390, 844), hazyPng(),
        onSave: (f) => saved = f);
    expect(editorState(tester).autoLevels, isNull);
    await openAdjust(tester);
    await tester.tap(find.byKey(const Key('z_adjust_auto')));
    await tester.pump();
    expect(editorState(tester).autoLevels, isNotNull);
    await tester.runAsync(() async {
      await tester.tap(find.text('Done'));
      for (var i = 0; i < 50 && saved == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await tester.pump();
      }
    });
    expect(saved, isNotNull);
    final out = img.decodeImage(saved!.first.readAsBytesSync())!;
    // The washed-out stripe (70) is darker (gentle black cut).
    var darkest = 255;
    for (final p in out) {
      if (p.r < darkest) darkest = p.r.toInt();
    }
    expect(darkest, lessThan(68));
  });
}
