import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';
import 'package:z_image_editor/z_image_editor.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector, rect;
import 'frame_step_design_test.dart' show designTheme;

ZFrameCandidate oval(String label, double inset,
        {ZFrameShape shape = ZFrameShape.round, bool pre = false}) =>
    ZFrameCandidate(
      label: label,
      corners: rect(label, inset).corners,
      shape: shape,
      preselected: pre,
    );

class Run {
  FrameCropResult? result;
}

Future<Run> pumpRound(
  WidgetTester tester,
  Size size,
  List<ZFrameCandidate> found, {
  bool sizeTools = false,
}) async {
  final run = Run();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: FrameCropView(
        imageBytes: testPng(w: 300, h: 300),
        detector: FakeDetector(found),
        labels: const ZFrameCropLabels(title: 'Choose what to keep'),
        theme: designTheme,
        sizeTools: sizeTools,
        onCancel: () {},
        onContinue: (r) => run.result = r,
        warp: (b, c) async => Uint8List.fromList([1]),
      ),
    ));
  });
  await settleAsync(tester);
  return run;
}

/// Round frame (outer), round mat opening, rectangular artwork.
final roundLevels = [
  rect('Artwork', 0.3),
  oval('No frame', 0.2),
  oval('With frame', 0.1, pre: true),
];

String shapeText(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('z_frame_shape_text'))).data!;

Future<void> tapWrongAndPick(WidgetTester tester, ZFrameShape s) async {
  await tester.tap(find.byKey(const Key('z_frame_shape_wrong')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('z_frame_shape_menu')), findsOneWidget);
  await tester.tap(find.byKey(Key('z_frame_shape_${s.name}')));
  await tester.pumpAndSettle();
}

void main() {
  group('geometry', () {
    test('the inscribed ellipse touches every side at its middle', () {
      const q = [
        Offset(0, 0),
        Offset(100, 0),
        Offset(100, 60),
        Offset(0, 60),
      ];
      final touch = ZQuadMath.ellipseTouchPoints(q);
      expect(touch[0], const Offset(50, 0));
      expect(touch[1], const Offset(100, 30));
      expect(touch[2], const Offset(50, 60));
      expect(touch[3], const Offset(0, 30));
      for (final p in ZQuadMath.inscribedEllipse(q)) {
        final dx = (p.dx - 50) / 50, dy = (p.dy - 30) / 30;
        expect(dx * dx + dy * dy, closeTo(1, 1e-9));
      }
    });

    test('mask: transparent outside the ellipse, untouched inside', () {
      final im = img.Image(width: 40, height: 40);
      img.fill(im, color: img.ColorRgb8(10, 20, 30));
      final out = ZPerspectiveWarp.maskEllipse(im);
      expect(out.numChannels, 4);
      expect(out.getPixel(0, 0).a, 0);
      expect(out.getPixel(20, 20).a, 255);
      expect(out.getPixel(20, 20).r, 10);
    });

    test('mask with a fill colour: no alpha, #F5F0F0 outside', () {
      final im = img.Image(width: 40, height: 40);
      img.fill(im, color: img.ColorRgb8(10, 20, 30));
      final out = ZPerspectiveWarp.maskEllipse(im, outsideFill: 0xFFF5F0F0);
      expect(out.numChannels, 3);
      final c = out.getPixel(0, 0);
      expect([c.r, c.g, c.b], [0xF5, 0xF0, 0xF0]);
      expect(out.getPixel(20, 20).r, 10);
    });

    test('warp of a round outline: square PNG with a transparent outside', () {
      final bytes = ZPerspectiveWarp.warpBytesSync(
        testPng(w: 200, h: 160),
        rect('x', 0.1).corners,
        aspectWH: 1,
        ellipse: true,
      );
      final out = img.decodePng(bytes)!;
      expect(out.width, out.height);
      expect(out.numChannels, 4);
      expect(out.getPixel(0, 0).a, 0);
      expect(out.getPixel(out.width ~/ 2, out.height ~/ 2).a, 255);
    });

    test('warp with a fill: JPEG, filled corners', () {
      final bytes = ZPerspectiveWarp.warpBytesSync(
        testPng(w: 200, h: 160),
        rect('x', 0.1).corners,
        aspectWH: 1,
        ellipse: true,
        outsideFill: 0xFFF5F0F0,
      );
      expect(bytes[0], 0xFF); // JPEG SOI
      final out = img.decodeJpg(bytes)!;
      expect(out.getPixel(1, 1).r, greaterThan(230));
    });
  });

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    group('round frames @ ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('round outer frame: label, ellipse handles, no shape buttons',
          (tester) async {
        await pumpRound(tester, size, roundLevels);
        expect(find.byKey(const Key('z_frame_shape_label')), findsOneWidget);
        expect(shapeText(tester), 'Round frame found');
        expect(find.text('Wrong?'), findsOneWidget);
        // No shape buttons in the tool row / chips.
        expect(find.text('Round'), findsNothing);
        expect(find.text('Oval'), findsNothing);
        // Handles sit on the ellipse's top / right / bottom / left.
        final canvas = tester.getRect(find.byKey(const Key('z_frame_canvas')));
        final top = tester.getCenter(find.byKey(const Key('z_frame_handle_0')));
        final right =
            tester.getCenter(find.byKey(const Key('z_frame_handle_1')));
        expect(top.dx, closeTo(canvas.center.dx, 1));
        expect(right.dy, closeTo(canvas.center.dy, 1));
        // Wrong? is inside the label, whose whole 44 px row is the target.
        expect(
            tester.getSize(find.byKey(const Key('z_frame_shape_label'))).height,
            greaterThanOrEqualTo(44));
        expect(
            find.descendant(
                of: find.byKey(const Key('z_frame_shape_label')),
                matching: find.byKey(const Key('z_frame_shape_wrong'))),
            findsOneWidget);
      });

      testWidgets('only rectangles: no shape label', (tester) async {
        await pumpRound(tester, size, [rect('Artwork', 0.2)]);
        expect(find.byKey(const Key('z_frame_shape_label')), findsNothing);
      });

      testWidgets('Wrong? → Oval changes the label, the result and Reset',
          (tester) async {
        final run = await pumpRound(tester, size, roundLevels);
        expect(find.byKey(const Key('z_frame_reset')), findsNothing);
        await tapWrongAndPick(tester, ZFrameShape.oval);
        expect(shapeText(tester), 'Oval frame found');
        expect(find.byKey(const Key('z_frame_reset')), findsOneWidget);
        await tester.tap(find.byKey(const Key('z_frame_continue')));
        await settleAsync(tester);
        expect(run.result!.shape, ZFrameShape.oval);
        expect(run.result!.shapeOverrides, {2: ZFrameShape.oval});
      });

      testWidgets('Wrong? → Rectangle: plain outline, label stays to undo',
          (tester) async {
        final run = await pumpRound(tester, size, roundLevels);
        await tapWrongAndPick(tester, ZFrameShape.rectangle);
        expect(shapeText(tester), 'Rectangle');
        // Corner handles again (top-left at the outline corner).
        final canvas = tester.getRect(find.byKey(const Key('z_frame_canvas')));
        final tl = tester.getCenter(find.byKey(const Key('z_frame_handle_0')));
        expect(tl.dx, lessThan(canvas.center.dx - 40));
        await tester.tap(find.byKey(const Key('z_frame_reset')));
        await tester.pump();
        expect(shapeText(tester), 'Round frame found');
        await tester.tap(find.byKey(const Key('z_frame_continue')));
        await settleAsync(tester);
        expect(run.result!.shape, ZFrameShape.round);
        expect(run.result!.shapeOverrides, isEmpty);
      });

      testWidgets('dismissing the menu changes nothing', (tester) async {
        await pumpRound(tester, size, roundLevels);
        await tester.tap(find.byKey(const Key('z_frame_shape_wrong')));
        await tester.pumpAndSettle();
        // The current shape is ticked.
        expect(
            find.descendant(
                of: find.byKey(const Key('z_frame_shape_round')),
                matching: find.byIcon(Icons.check)),
            findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('z_frame_shape_menu')), findsNothing);
        expect(shapeText(tester), 'Round frame found');
      });

      testWidgets('each level keeps its own shape', (tester) async {
        final run = await pumpRound(tester, size, roundLevels);
        await tester.tap(find.byKey(const Key('z_frame_chip_0')));
        await tester.pump();
        expect(shapeText(tester), 'Rectangle');
        await tester.tap(find.byKey(const Key('z_frame_chip_1')));
        await tester.pump();
        expect(shapeText(tester), 'Round frame found');
        await tester.tap(find.byKey(const Key('z_frame_continue')));
        await settleAsync(tester);
        expect(run.result!.shape, ZFrameShape.round);
        expect(run.result!.baseCandidate, 1);
      });

      testWidgets('dragging the top handle moves the top side, with magnifier',
          (tester) async {
        final run = await pumpRound(tester, size, roundLevels);
        final h = tester.getCenter(find.byKey(const Key('z_frame_handle_0')));
        final g = await tester.startGesture(h);
        for (var i = 0; i < 6; i++) {
          await g.moveBy(const Offset(0, 4));
          await tester.pump();
        }
        expect(find.byKey(const Key('z_frame_loupe')), findsOneWidget);
        await g.up();
        await tester.pump();
        expect(find.byKey(const Key('z_frame_loupe')), findsNothing);
        expect(find.text('With frame · edited'), findsOneWidget);
        await tester.tap(find.byKey(const Key('z_frame_continue')));
        await settleAsync(tester);
        final c = run.result!.corners;
        // Top-left and top-right moved down together, the bottom did not.
        expect(c[0].dy, greaterThan(0.11));
        expect(c[1].dy, closeTo(c[0].dy, 1e-6));
        expect(c[2].dy, closeTo(0.9, 1e-6));
        expect(run.result!.shape, ZFrameShape.round);
      });

      testWidgets('a round frame is measured as a circle', (tester) async {
        final run = await pumpRound(
            tester,
            size,
            [
              oval('With frame', 0.1, pre: true),
            ],
            sizeTools: true);
        final label = tester
            .widget<ZPhotoPill>(find.byKey(const Key('z_frame_size')))
            .label;
        final m = RegExp(r"([\d.,]+) × ([\d.,]+)").firstMatch(label);
        expect(m, isNotNull, reason: label);
        m!;
        expect(m.group(1), m.group(2));
        await tester.tap(find.byKey(const Key('z_frame_continue')));
        await settleAsync(tester);
        expect(run.result!.outputAspectWH, 1);
      });

      testWidgets('an oval frame shows "Oval frame found"', (tester) async {
        await pumpRound(tester, size, [
          oval('With frame', 0.1, shape: ZFrameShape.oval, pre: true),
        ]);
        expect(shapeText(tester), 'Oval frame found');
      });
    });
  }

  group('editor', () {
    Future<FrameCropView> stepOf(
        WidgetTester tester, ImageOutputFormat format) async {
      await pumpEditor(
        tester,
        ZImageEditor(
          imageBytesList: [testPng()],
          frameDetector: FakeDetector(roundLevels),
          outputFormat: format,
          theme: designTheme,
          onSaveAll: (_) {},
          onCancel: () {},
        ),
      );
      return tester.widget<FrameCropView>(find.byType(FrameCropView));
    }

    testWidgets('PNG / auto output keeps the outside transparent',
        (tester) async {
      expect(
          (await stepOf(tester, ImageOutputFormat.auto)).outsideFill, isNull);
    });

    testWidgets('JPEG output fills the outside with #F5F0F0', (tester) async {
      expect((await stepOf(tester, ImageOutputFormat.jpeg)).outsideFill,
          const Color(0xFFF5F0F0));
    });
  });
}
