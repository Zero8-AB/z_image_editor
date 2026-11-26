import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';
import 'package:z_image_editor/z_image_editor.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector, FakeEnhancer, rect;
import 'frame_step_design_test.dart' show designTheme;

const retakeKey = Key('z_frame_retake');

/// The tool row, left to right (size and reflections are on the photo,
/// Reset is under the row).
const allTools = [
  'z_frame_retake',
  'z_frame_rotate',
  'z_frame_full',
];

Future<void> pumpFrame(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  VoidCallback? onRetake,
  ZImageEnhancer? enhancer,
  ZFrameCropLabels labels = const ZFrameCropLabels(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: FrameCropView(
        imageBytes: testPng(w: 300, h: 300),
        detector: FakeDetector([rect('With frame', 0.1)]),
        labels: labels,
        theme: designTheme,
        sizeTools: true,
        enhancer: enhancer,
        onRetake: onRetake,
        onCancel: () {},
        onContinue: (_) {},
        warp: (b, c) async => Uint8List.fromList([1]),
      ),
    ));
  });
  await settleAsync(tester);
}

void main() {
  testWidgets('Retake tool is shown when onRetake is set', (tester) async {
    await pumpFrame(tester, onRetake: () {});
    expect(find.byKey(retakeKey), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(retakeKey), matching: find.text('Retake')),
        findsOneWidget);
    final icon = tester.widget<ZLineIcon>(find.descendant(
        of: find.byKey(retakeKey), matching: find.byType(ZLineIcon)));
    expect(icon.kind, ZLineIconKind.camera);
  });

  testWidgets('no Retake tool without onRetake', (tester) async {
    await pumpFrame(tester);
    expect(find.byKey(retakeKey), findsNothing);
    expect(find.text('Retake'), findsNothing);
  });

  testWidgets('tapping Retake calls onRetake', (tester) async {
    var retakes = 0;
    await pumpFrame(tester, onRetake: () => retakes++);
    await tester.tap(find.byKey(retakeKey));
    await tester.pump();
    expect(retakes, 1);
  });

  testWidgets('the label comes from ZFrameCropLabels.retakeLabel',
      (tester) async {
    await pumpFrame(tester,
        onRetake: () {}, labels: const ZFrameCropLabels(retakeLabel: 'Ta om'));
    expect(
        find.descendant(
            of: find.byKey(retakeKey), matching: find.text('Ta om')),
        findsOneWidget);
  });

  for (final scale in const [1.0, 1.3]) {
    for (final size in const [Size(360, 640), Size(430, 932)]) {
      final s = '${size.width.toInt()}x${size.height.toInt()} @ ${scale}x';
      testWidgets('tool row with Retake fits ($s)', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpFrame(tester,
            size: size,
            onRetake: () {},
            enhancer: FakeEnhancer(testPng(w: 300, h: 300)));
        expect(tester.takeException(), isNull);
        final rects = [
          for (final k in allTools) tester.getRect(find.byKey(Key(k))),
        ];
        for (var i = 0; i < rects.length; i++) {
          final r = rects[i];
          expect(r.left, greaterThanOrEqualTo(0), reason: allTools[i]);
          expect(r.right, lessThanOrEqualTo(size.width), reason: allTools[i]);
          expect(r.bottom, lessThanOrEqualTo(size.height), reason: allTools[i]);
          expect(r.height, greaterThanOrEqualTo(44), reason: allTools[i]);
          if (i > 0) {
            expect(r.left, greaterThanOrEqualTo(rects[i - 1].right - 0.01),
                reason: '${allTools[i - 1]} vs ${allTools[i]}');
          }
          // The label stays inside its button.
          final label = tester.getRect(find.descendant(
              of: find.byKey(Key(allTools[i])), matching: find.byType(Text)));
          expect(label.left, greaterThanOrEqualTo(r.left - 0.01));
          expect(label.right, lessThanOrEqualTo(r.right + 0.01));
          expect(label.bottom, lessThanOrEqualTo(r.bottom + 0.01));
        }
        // Icons on one line.
        final iconTops = {
          for (final k in allTools)
            tester
                .getRect(find.descendant(
                    of: find.byKey(Key(k)), matching: find.byType(ZLineIcon)))
                .top,
        };
        expect(iconTops, hasLength(1));
      });
    }
  }

  testWidgets('Retake moves no other tool when the size is confirmed',
      (tester) async {
    await pumpFrame(tester, size: const Size(360, 640), onRetake: () {});
    Map<String, Rect> bar() => {
          for (final k in [
            'z_frame_rotate',
            'z_frame_full',
            'z_frame_retake',
          ])
            k: tester.getRect(find.byKey(Key(k))),
        };
    final before = bar();
    await tester.tap(find.byKey(const Key('z_frame_size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('z_size_confirm')));
    await tester.pumpAndSettle();
    expect(bar(), before);
  });
}
