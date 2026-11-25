import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';
import 'package:z_image_editor/z_image_editor.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector, FakeEnhancer, rect;

/// The approved Monogram look, as the app passes it.
const designTheme = ZImageEditorTheme(
  backgroundColor: Color(0xFF1C1A1A),
  panelColor: Color(0xFF1C1A1A),
  textColor: Color(0xFFFDFDFB),
  disabledColor: Color(0xFF646464),
  accentColor: Color(0xFFCE5151),
  toggleOnColor: Color(0xFFE06A6A),
  showTitle: true,
  primaryButtonColor: Color(0xFFCE5151),
  primaryButtonRadius: 4,
  primaryButtonHeight: 44,
  cancelButtonColor: null,
  chipHeight: 40,
  chipFontSize: 16,
  chipSelectedColor: Color(0xFFCE5151),
  chipSelectedTextColor: Color(0xFFFDFDFB),
  chipBorderColor: Color(0x59FDFDFB),
  quadColor: Color(0xFFCE5151),
  quadStrokeWidth: 2,
  showGrid: false,
  dimOpacity: 0.5,
  handleRingColor: Color(0xFFCE5151),
  alternativeOutlineColor: Color(0x59FDFDFB),
  toolIconSize: 24,
  toolLabelFontSize: 12,
  loupeCrosshairColor: Color(0xFFCE5151),
);

const labels = ZFrameCropLabels(title: 'Choose what to keep');

final candidates = [
  rect('Artwork', 0.3),
  rect('No frame', 0.2),
  ZFrameCandidate(
    label: 'With frame',
    corners: rect('x', 0.1).corners,
    preselected: true,
  ),
];

class Shot {
  FrameCropResult? result;
  bool cancelled = false;
}

Future<Shot> pumpDesign(
  WidgetTester tester,
  Size size, {
  ZImageEnhancer? enhancer,
}) async {
  final shot = Shot();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: FrameCropView(
        imageBytes: testPng(w: 300, h: 400),
        detector: FakeDetector(candidates),
        enhancer: enhancer,
        labels: labels,
        theme: designTheme,
        onCancel: () => shot.cancelled = true,
        onContinue: (r) => shot.result = r,
        warp: (b, c) async => Uint8List.fromList([1]),
      ),
    ));
  });
  await settleAsync(tester);
  return shot;
}

ZChip chip(WidgetTester t, int i) =>
    t.widget<ZChip>(find.byKey(Key('z_frame_chip_$i')));
ZToolButton tool(WidgetTester t, String key) =>
    t.widget<ZToolButton>(find.byKey(Key(key)));

void main() {
  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';

    group('frame step design @ $s', () {
      testWidgets('title, chips in order, With frame pre-selected',
          (tester) async {
        await pumpDesign(tester, size);
        expect(find.text('Choose what to keep'), findsOneWidget);
        expect(chip(tester, 0).label, 'Artwork');
        expect(chip(tester, 1).label, 'No frame');
        expect(chip(tester, 2).label, 'With frame');
        expect(chip(tester, 2).selected, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('each chip selects its outline', (tester) async {
        await pumpDesign(tester, size);
        for (final i in [0, 1, 2]) {
          await tester.ensureVisible(find.byKey(Key('z_frame_chip_$i')));
          await tester.tap(find.byKey(Key('z_frame_chip_$i')));
          await tester.pump();
          for (final j in [0, 1, 2]) {
            expect(chip(tester, j).selected, i == j, reason: 'tap $i');
          }
        }
      });

      testWidgets('chips have a 44 px tap area and a 40 px pill',
          (tester) async {
        await pumpDesign(tester, size);
        final box = tester.getSize(find.byKey(const Key('z_frame_chip_0')));
        expect(box.height, greaterThanOrEqualTo(44));
      });

      testWidgets('edited chip reads "Artwork · edited"', (tester) async {
        await pumpDesign(tester, size);
        await tester.ensureVisible(find.byKey(const Key('z_frame_chip_0')));
        await tester.tap(find.byKey(const Key('z_frame_chip_0')));
        await tester.pump();
        final h = tester.getCenter(find.byKey(const Key('z_frame_handle_0')));
        await dragStepwise(tester, h, const Offset(10, 10));
        expect(find.text('Artwork · edited'), findsOneWidget);
      });

      testWidgets('tool row: Rotate, Full photo, Reset (greyed when clean)',
          (tester) async {
        await pumpDesign(tester, size);
        expect(find.text('Rotate'), findsOneWidget);
        expect(find.text('Full photo'), findsOneWidget);
        expect(tool(tester, 'z_frame_reset').onTap, isNull);
        await tester.tap(find.byKey(const Key('z_frame_rotate')));
        await tester.pump();
        expect(tool(tester, 'z_frame_reset').onTap, isNotNull);
        await tester.tap(find.byKey(const Key('z_frame_reset')));
        await tester.pump();
        expect(tool(tester, 'z_frame_reset').onTap, isNull);
        await tester.tap(find.byKey(const Key('z_frame_full')));
        await tester.pump();
        expect(tool(tester, 'z_frame_full').active, isTrue);
        for (var i = 0; i < 3; i++) {
          expect(chip(tester, i).selected, isFalse);
        }
      });

      testWidgets('No reflections toggle is red when on, tap compares',
          (tester) async {
        await pumpDesign(tester, size,
            enhancer: FakeEnhancer(testPng(w: 300, h: 400)));
        final on = tool(tester, 'z_frame_enhance');
        expect(on.active, isTrue);
        expect(on.label, 'No reflections');
        await tester.tap(find.byKey(const Key('z_frame_enhance')));
        await tester.pump();
        expect(tool(tester, 'z_frame_enhance').label, 'Reflections shown');
        expect(tool(tester, 'z_frame_enhance').active, isFalse);
      });

      testWidgets('tool buttons are at least 44 px tall', (tester) async {
        await pumpDesign(tester, size);
        for (final k in ['z_frame_rotate', 'z_frame_full', 'z_frame_reset']) {
          expect(tester.getSize(find.byKey(Key(k))).height,
              greaterThanOrEqualTo(44));
        }
      });

      testWidgets('Next and Cancel', (tester) async {
        final shot = await pumpDesign(tester, size);
        await tester.tap(find.byKey(const Key('z_frame_cancel')));
        expect(shot.cancelled, isTrue);
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('z_frame_continue')));
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
        expect(shot.result, isNotNull);
        expect(shot.result!.baseCandidate, 2);
      });

      testWidgets('corner drag shows the magnifier with a red crosshair',
          (tester) async {
        await pumpDesign(tester, size);
        final g = await tester.startGesture(
            tester.getCenter(find.byKey(const Key('z_frame_handle_1'))));
        await g.moveBy(const Offset(-8, 6));
        await tester.pump();
        final loupe =
            tester.widget<CustomPaint>(find.byKey(const Key('z_frame_loupe')));
        expect((loupe.painter! as FrameLoupePainter).theme.loupeCrosshairColor,
            const Color(0xFFCE5151));
        await g.up();
        await tester.pump();
        expect(find.byKey(const Key('z_frame_loupe')), findsNothing);
      });

      testWidgets('tap on the photo cycles the outlines', (tester) async {
        await pumpDesign(tester, size);
        await tester
            .tapAt(tester.getCenter(find.byKey(const Key('z_frame_photo'))));
        await tester.pump();
        // From With frame (last) the cycle goes to the full photo.
        expect(tool(tester, 'z_frame_full').active, isTrue);
        await tester
            .tapAt(tester.getCenter(find.byKey(const Key('z_frame_photo'))));
        await tester.pump();
        expect(chip(tester, 0).selected, isTrue);
      });

      testWidgets('selected outline is red, others dashed; handles ringed',
          (tester) async {
        await pumpDesign(tester, size);
        final paint = tester.widget<CustomPaint>(find.descendant(
            of: find.byKey(const Key('z_frame_photo')),
            matching: find.byType(CustomPaint)));
        final p = paint.painter! as FrameQuadPainter;
        expect(p.theme.quadColor, const Color(0xFFCE5151));
        expect(p.theme.quadStrokeWidth, 2);
        expect(p.alternatives, hasLength(2));
        final handle = tester.widget<Container>(find.descendant(
            of: find.byKey(const Key('z_frame_handle_0')),
            matching: find.byType(Container)));
        final deco = handle.decoration! as BoxDecoration;
        expect((deco.border! as Border).top.color, const Color(0xFFCE5151));
        expect(handle.constraints?.maxWidth ?? 18, 18);
      });
    });
  }
}
