import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';
import 'package:z_image_editor/z_image_editor.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart'
    show FakeDetector, FakeEnhancer, SlowDetector, SlowEnhancer, rect;
import 'frame_step_design_test.dart' show designTheme;

const sizeKey = Key('z_frame_size');
const enhanceKey = Key('z_frame_enhance');
const resetKey = Key('z_frame_reset');
const canvasKey = Key('z_frame_canvas');

class LongEnhancer extends FakeEnhancer {
  LongEnhancer(super.output);
  @override
  String get label => 'Reflections removed from the glass of the frame';
  @override
  String get offLabel => 'Reflections are shown on the glass of the frame';
}

Future<void> pumpStep(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  ZFrameDetector? detector,
  bool noDetector = false,
  ZImageEnhancer? enhancer,
  VoidCallback? onRetake,
  bool sizeTools = true,
  ZFrameCropLabels labels = const ZFrameCropLabels(),
  int w = 300,
  int h = 400,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: FrameCropView(
        imageBytes: testPng(w: w, h: h),
        detector: noDetector
            ? null
            : detector ??
                FakeDetector([
                  rect('Artwork', 0.3),
                  rect('No frame', 0.2),
                  rect('With frame', 0.1),
                ]),
        labels: labels,
        theme: designTheme,
        sizeTools: sizeTools,
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

Rect rectOf(WidgetTester t, Key k) => t.getRect(find.byKey(k));

/// The visible pill inside the tap area of [k].
Finder pillOf(Key k) =>
    find.descendant(of: find.byKey(k), matching: find.byType(Container)).first;

Color? pillColor(WidgetTester t, Key k) =>
    (t.widget<Container>(pillOf(k)).decoration as BoxDecoration?)?.color;

List<Rect> handleRects(WidgetTester t) => [
      for (var i = 0; i < 4; i++)
        t.getRect(find.byKey(Key('z_frame_handle_$i'))),
    ];

void main() {
  group('tool row', () {
    List<Key?> rowKeys(WidgetTester t) => [
          for (final b in t.widgetList<ZToolButton>(find.descendant(
              of: find.byType(FrameToolRow),
              matching: find.byType(ZToolButton))))
            b.key,
        ];

    testWidgets('only Retake, Rotate and Full photo, in that order',
        (tester) async {
      await pumpStep(tester,
          onRetake: () {}, enhancer: FakeEnhancer(testPng()));
      expect(rowKeys(tester), const [
        Key('z_frame_retake'),
        Key('z_frame_rotate'),
        Key('z_frame_full'),
      ]);
      // Spaced evenly: three equal columns, left to right.
      final r = [
        for (final k in rowKeys(tester)) tester.getRect(find.byKey(k!)),
      ];
      expect(r[1].width, moreOrLessEquals(r[0].width, epsilon: 0.01));
      expect(r[2].width, moreOrLessEquals(r[0].width, epsilon: 0.01));
      expect(r[1].left, moreOrLessEquals(r[0].right, epsilon: 0.01));
      expect(r[2].left, moreOrLessEquals(r[1].right, epsilon: 0.01));
    });

    testWidgets('without onRetake: Rotate and Full photo', (tester) async {
      await pumpStep(tester);
      expect(rowKeys(tester), const [
        Key('z_frame_rotate'),
        Key('z_frame_full'),
      ]);
    });
  });

  group('size on the photo', () {
    testWidgets('bottom centre of the canvas, above the chips', (tester) async {
      await pumpStep(tester);
      final canvas = rectOf(tester, canvasKey);
      final tap = rectOf(tester, sizeKey);
      final pill = tester.getRect(pillOf(sizeKey));
      expect(
          find.descendant(
              of: find.byKey(canvasKey), matching: find.byKey(sizeKey)),
          findsOneWidget);
      expect(canvas.contains(tap.topLeft), isTrue);
      expect(
          canvas.contains(tap.bottomRight - const Offset(0.01, 0.01)), isTrue);
      expect(tap.center.dx, moreOrLessEquals(canvas.center.dx, epsilon: 0.5));
      // About 10 px above the canvas bottom, 28–32 px tall, 44 px to tap.
      expect(canvas.bottom - pill.bottom, moreOrLessEquals(10, epsilon: 2));
      expect(pill.height, inInclusiveRange(28, 32));
      expect(tap.height, greaterThanOrEqualTo(44));
      expect(tap.width, greaterThanOrEqualTo(44));
      expect(tap.bottom,
          lessThanOrEqualTo(rectOf(tester, const Key('z_frame_chip_0')).top));
      final text = tester.widget<Text>(find.descendant(
          of: find.byKey(sizeKey), matching: find.byType(Text)));
      expect(text.data, matches(RegExp(r'^≈ \d+ × \d+ cm · Check$')));
      // A pen says it can be changed.
      final icon = tester.widget<ZLineIcon>(find.descendant(
          of: find.byKey(sizeKey), matching: find.byType(ZLineIcon)));
      expect(icon.kind, ZLineIconKind.edit);
      // A dark pill: the panel colour, see-through.
      final c = pillColor(tester, sizeKey)!;
      expect(c.withValues(alpha: 1), designTheme.panelColor);
      expect(c.a, moreOrLessEquals(0.82, epsilon: 0.01));
    });

    testWidgets('a tap opens the size sheet and selects no other outline',
        (tester) async {
      await pumpStep(tester);
      bool selected(int i) =>
          tester.widget<ZChip>(find.byKey(Key('z_frame_chip_$i'))).selected;
      expect(selected(0), isTrue);
      final handles = handleRects(tester);
      await tester.tap(find.byKey(sizeKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('z_size_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('z_size_confirm')));
      await tester.pumpAndSettle();
      // Neither the photo (next outline) nor a handle got the tap.
      expect(selected(0), isTrue);
      expect(handleRects(tester), handles);
      expect(find.byKey(resetKey), findsNothing);
      // Confirmed: lock icon.
      final icon = tester.widget<ZLineIcon>(find.descendant(
          of: find.byKey(sizeKey), matching: find.byType(ZLineIcon)));
      expect(icon.kind, ZLineIconKind.sizeConfirmed);
      expect(icon.color, designTheme.toggleOnColor);
    });

    testWidgets('short of room between the handles: without "· Check"',
        (tester) async {
      // A tall photo on a small phone: the outline's bottom handles are
      // left and right of the label.
      await pumpStep(tester,
          size: const Size(360, 640),
          w: 300,
          h: 600,
          detector: FakeDetector([rect('With frame', 0.04)]));
      String shown() => tester
          .widget<Text>(find.descendant(
              of: find.byKey(sizeKey), matching: find.byType(Text)))
          .data!;
      final pill = tester.widget<ZPhotoPill>(find.byKey(sizeKey));
      expect(pill.label, endsWith(' cm · Check'));
      expect(shown(), pill.label.replaceFirst(' · Check', ''));
      final tap = rectOf(tester, sizeKey);
      for (final h in handleRects(tester)) {
        expect(tap.overlaps(h), isFalse);
      }
      // Accessibility still gets all of it.
      expect(tester.getSemantics(find.byKey(sizeKey)).label, pill.label);
    });

    testWidgets('not shown without sizeTools', (tester) async {
      await pumpStep(tester, sizeTools: false);
      expect(find.byKey(sizeKey), findsNothing);
    });
  });

  group('reflections on the photo', () {
    testWidgets('top right of the canvas, accent-filled when on, toggles',
        (tester) async {
      await pumpStep(tester, enhancer: FakeEnhancer(testPng()));
      final canvas = rectOf(tester, canvasKey);
      final tap = rectOf(tester, enhanceKey);
      final pill = tester.getRect(pillOf(enhanceKey));
      expect(
          find.descendant(
              of: find.byKey(canvasKey), matching: find.byKey(enhanceKey)),
          findsOneWidget);
      expect(pill.top - canvas.top, moreOrLessEquals(10, epsilon: 2));
      expect(canvas.right - pill.right, moreOrLessEquals(10, epsilon: 2));
      expect(pill.height, inInclusiveRange(28, 32));
      expect(tap.height, greaterThanOrEqualTo(44));
      expect(tap.width, greaterThanOrEqualTo(44));
      expect(
          find.descendant(
              of: find.byKey(enhanceKey),
              matching: find.text('No reflections')),
          findsOneWidget);
      expect(pillColor(tester, enhanceKey), designTheme.accentColor);

      await tester.tap(find.byKey(enhanceKey));
      await tester.pump();
      expect(
          find.descendant(
              of: find.byKey(enhanceKey),
              matching: find.text('Reflections shown')),
          findsOneWidget);
      expect(pillColor(tester, enhanceKey), isNot(designTheme.accentColor));
      // Still in the same corner.
      final off = tester.getRect(pillOf(enhanceKey));
      expect(off.top, pill.top);
      expect(off.right, pill.right);

      await tester.tap(find.byKey(enhanceKey));
      await tester.pump();
      expect(pillColor(tester, enhanceKey), designTheme.accentColor);
    });

    testWidgets('while enhancing: shown with a spinner, a tap does nothing',
        (tester) async {
      final slow = SlowEnhancer();
      await pumpStep(tester, enhancer: slow);
      expect(find.byKey(enhanceKey), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(enhanceKey),
              matching: find.byType(CupertinoActivityIndicator)),
          findsOneWidget);
      expect(pillColor(tester, enhanceKey), isNot(designTheme.accentColor));
      await tester.tap(find.byKey(enhanceKey));
      await tester.pump();
      expect(find.text('No reflections'), findsOneWidget);
      slow.completer.complete(null);
      await settleAsync(tester);
      // Nothing to fix: gone.
      expect(find.byKey(enhanceKey), findsNothing);
    });
  });

  group('labels on the photo and the handles', () {
    testWidgets('hidden while detecting', (tester) async {
      final slow = SlowDetector();
      await pumpStep(tester, detector: slow, enhancer: FakeEnhancer(testPng()));
      expect(find.byKey(canvasKey), findsOneWidget);
      expect(find.byKey(sizeKey), findsNothing);
      expect(find.byKey(enhanceKey), findsNothing);
      slow.completer.complete([rect('With frame', 0.1)]);
      await settleAsync(tester);
      expect(find.byKey(sizeKey), findsOneWidget);
      expect(find.byKey(enhanceKey), findsOneWidget);
    });

    testWidgets('hidden while a corner is dragged; the drag goes on',
        (tester) async {
      await pumpStep(tester, enhancer: FakeEnhancer(testPng()));
      final start = tester.getCenter(find.byKey(const Key('z_frame_handle_0')));
      final g = await tester.startGesture(start);
      for (var i = 0; i < 5; i++) {
        await g.moveBy(const Offset(4, 4));
        await tester.pump();
      }
      expect(find.byKey(sizeKey), findsNothing);
      expect(find.byKey(enhanceKey), findsNothing);
      final mid = tester.getCenter(find.byKey(const Key('z_frame_handle_0')));
      expect(mid.dx, greaterThan(start.dx));
      // Still the same drag after the labels went away.
      for (var i = 0; i < 5; i++) {
        await g.moveBy(const Offset(4, 4));
        await tester.pump();
      }
      expect(tester.getCenter(find.byKey(const Key('z_frame_handle_0'))).dx,
          greaterThan(mid.dx + 10));
      await g.up();
      await tester.pump();
      expect(find.byKey(sizeKey), findsOneWidget);
      expect(find.byKey(enhanceKey), findsOneWidget);
    });

    for (final size in const [Size(360, 640), Size(430, 932)]) {
      final s = '${size.width.toInt()}x${size.height.toInt()}';
      // A tall photo without a detector: the outline is the whole photo, so
      // its handles sit in the canvas corners, next to the labels.
      testWidgets('never on a handle\'s drag area (full photo, $s)',
          (tester) async {
        await pumpStep(tester,
            size: size,
            noDetector: true,
            enhancer: FakeEnhancer(testPng(w: 300, h: 900)),
            w: 300,
            h: 900);
        for (final k in const [sizeKey, enhanceKey]) {
          final r = rectOf(tester, k);
          for (final h in handleRects(tester)) {
            expect(r.overlaps(h), isFalse, reason: '$k on a handle');
          }
        }
        // The top-right handle still drags.
        final before =
            tester.getCenter(find.byKey(const Key('z_frame_handle_1')));
        await dragStepwise(tester, before, const Offset(-40, 40));
        final after =
            tester.getCenter(find.byKey(const Key('z_frame_handle_1')));
        expect(after.dx, lessThan(before.dx - 20));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Reset', () {
    testWidgets('absent until a corner is moved, then resets and goes away',
        (tester) async {
      await pumpStep(tester, onRetake: () {});
      expect(find.byKey(resetKey), findsNothing);
      expect(find.text('Reset'), findsNothing);
      final original =
          tester.getCenter(find.byKey(const Key('z_frame_handle_3')));
      // (The chip's width changes with "· edited"; its row must not move.)
      Map<String, Object> bar() => {
            'chips':
                tester.getRect(find.byKey(const Key('z_frame_chip_0'))).top,
            'canvas': rectOf(tester, canvasKey),
            for (final k in [
              'z_frame_retake',
              'z_frame_rotate',
              'z_frame_full'
            ])
              k: tester.getRect(find.byKey(Key(k))),
          };
      final before = bar();
      await dragStepwise(tester, original, const Offset(25, -25));
      expect(tester.getCenter(find.byKey(const Key('z_frame_handle_3'))),
          isNot(original));
      expect(find.byKey(resetKey), findsOneWidget);
      final reset = rectOf(tester, resetKey);
      // A small text button under the tool row: icon and label, muted.
      expect(
          reset.top,
          greaterThanOrEqualTo(
              rectOf(tester, const Key('z_frame_full')).bottom));
      expect(reset.bottom, lessThanOrEqualTo(844));
      expect(reset.height, greaterThanOrEqualTo(44));
      final text = tester.widget<Text>(find.descendant(
          of: find.byKey(resetKey), matching: find.text('Reset')));
      expect(text.style!.color, designTheme.mutedTextColor);
      final icon = tester.widget<ZLineIcon>(find.descendant(
          of: find.byKey(resetKey), matching: find.byType(ZLineIcon)));
      expect(icon.kind, ZLineIconKind.reset);
      expect(icon.color, designTheme.mutedTextColor);
      // It is not one of the tools, and it moved nothing.
      expect(
          find.descendant(
              of: find.byType(FrameToolRow), matching: find.byKey(resetKey)),
          findsNothing);
      expect(bar(), before);

      await tester.tap(find.byKey(resetKey));
      await tester.pump();
      expect(tester.getCenter(find.byKey(const Key('z_frame_handle_3'))),
          original);
      expect(find.byKey(resetKey), findsNothing);
    });
  });

  for (final scale in const [1.0, 1.3]) {
    for (final size in const [Size(360, 640), Size(430, 932)]) {
      final s = '${size.width.toInt()}x${size.height.toInt()} @ ${scale}x';
      for (final long in const [false, true]) {
        testWidgets('nothing overflows${long ? ' with long labels' : ''} ($s)',
            (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final fixed = testPng();
          await pumpStep(tester,
              size: size,
              onRetake: () {},
              enhancer: long ? LongEnhancer(fixed) : FakeEnhancer(fixed),
              labels: long
                  ? const ZFrameCropLabels(
                      sizeCheckSuffix: ' · Check the size of the artwork')
                  : const ZFrameCropLabels());
          // With Reset shown.
          await dragStepwise(
              tester,
              tester.getCenter(find.byKey(const Key('z_frame_handle_3'))),
              const Offset(20, -20));
          expect(tester.takeException(), isNull);
          final canvas = rectOf(tester, canvasKey);
          for (final k in const [sizeKey, enhanceKey]) {
            final tap = rectOf(tester, k);
            final pill = tester.getRect(pillOf(k));
            expect(tap.left, greaterThanOrEqualTo(canvas.left), reason: '$k');
            expect(tap.right, lessThanOrEqualTo(canvas.right), reason: '$k');
            expect(tap.top, greaterThanOrEqualTo(canvas.top), reason: '$k');
            expect(tap.bottom, lessThanOrEqualTo(canvas.bottom), reason: '$k');
            expect(tap.height, greaterThanOrEqualTo(44), reason: '$k');
            // Icon and label stay inside the pill.
            for (final inner in [
              find.descendant(of: find.byKey(k), matching: find.byType(Text)),
              find.descendant(
                  of: find.byKey(k), matching: find.byType(ZLineIcon)),
            ]) {
              final r = tester.getRect(inner);
              expect(r.left, greaterThanOrEqualTo(pill.left - 0.01));
              expect(r.right, lessThanOrEqualTo(pill.right + 0.01));
              expect(r.top, greaterThanOrEqualTo(pill.top - 0.01));
              expect(r.bottom, lessThanOrEqualTo(pill.bottom + 0.01));
            }
            for (final h in handleRects(tester)) {
              expect(tap.overlaps(h), isFalse, reason: '$k on a handle');
            }
          }
          expect(rectOf(tester, sizeKey).overlaps(rectOf(tester, enhanceKey)),
              isFalse);
          // Tools and Reset on screen, each 44 px to tap.
          for (final k in const [
            'z_frame_retake',
            'z_frame_rotate',
            'z_frame_full',
            'z_frame_reset',
          ]) {
            final r = tester.getRect(find.byKey(Key(k)));
            expect(r.left, greaterThanOrEqualTo(0), reason: k);
            expect(r.right, lessThanOrEqualTo(size.width), reason: k);
            expect(r.bottom, lessThanOrEqualTo(size.height), reason: k);
            expect(r.height, greaterThanOrEqualTo(44), reason: k);
            final label = tester.getRect(find.descendant(
                of: find.byKey(Key(k)), matching: find.byType(Text)));
            expect(label.left, greaterThanOrEqualTo(r.left - 0.01), reason: k);
            expect(label.right, lessThanOrEqualTo(r.right + 0.01), reason: k);
          }
        });
      }
    }
  }
}
