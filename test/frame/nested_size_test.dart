import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/image_editor.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector;
import 'frame_size_tools_test.dart' show label, sizeButton, sizeTheme;

/// A real photo (iPhone, 9 : 16) of a framed print: black frame, white mat,
/// the "SATURN" poster. Corners read off the app's handles, normalized in
/// the photo; innermost first, like the app's detector returns them.
const saturnArtwork = [
  Offset(0.1794, 0.2856),
  Offset(0.7118, 0.2790),
  Offset(0.7118, 0.7053),
  Offset(0.2059, 0.7036),
];
const saturnNoFrame = [
  Offset(0.1574, 0.2699),
  Offset(0.7426, 0.2657),
  Offset(0.7412, 0.7185),
  Offset(0.1794, 0.7185),
];
const saturnWithFrame = [
  Offset(0.1250, 0.2517),
  Offset(0.7662, 0.2459),
  Offset(0.7632, 0.7318),
  Offset(0.1529, 0.7318),
];

List<ZFrameCandidate> saturn() => [
      ZFrameCandidate(
          label: 'Artwork', corners: saturnArtwork, level: ZFrameLevel.artwork),
      ZFrameCandidate(
          label: 'No frame', corners: saturnNoFrame, level: ZFrameLevel.inner),
      ZFrameCandidate(
          label: 'With frame',
          corners: saturnWithFrame,
          level: ZFrameLevel.frame,
          preselected: true),
    ];

/// A wall-mounted TV photographed with the phone turned (tall, about
/// 16 : 9): no common artwork size has that shape.
const tv = [
  Offset(0.2985, 0.3171),
  Offset(0.7088, 0.3245),
  Offset(0.7088, 0.7227),
  Offset(0.3000, 0.7310),
];

class NestedHarness {
  FrameCropResult? result;
}

Future<NestedHarness> pumpStep(
  WidgetTester tester,
  List<ZFrameCandidate> candidates, {
  ZArtworkSize? known,
  FrameCropResult? previous,
}) async {
  final h = NestedHarness();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: FrameCropView(
        imageBytes: testPng(w: 270, h: 480),
        detector: FakeDetector(candidates),
        theme: sizeTheme,
        sizeTools: true,
        knownSize: known,
        previous: previous,
        onCancel: () {},
        onContinue: (r) => h.result = r,
        warp: (b, c) async => Uint8List.fromList([1]),
      ),
    ));
  });
  await settleAsync(tester);
  return h;
}

/// (height, width) in cm read from the measurement labels.
(double, double) shownCm(WidgetTester t) {
  double cm(String key) => parseCm(label(t, key))!;
  return (cm('z_frame_height_label'), cm('z_frame_width_label'));
}

Future<void> selectChip(WidgetTester tester, int i) async {
  await tester.ensureVisible(find.byKey(Key('z_frame_chip_$i')));
  await tester.pump();
  await tester.tap(find.byKey(Key('z_frame_chip_$i')));
  await tester.pump();
}

/// Opens the size sheet, picks the common size [preset] and confirms.
Future<void> confirmPreset(WidgetTester tester, String preset) async {
  await tester.tap(find.byKey(const Key('z_frame_size')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(Key('z_size_preset_$preset')));
  await tester.tap(find.byKey(Key('z_size_preset_$preset')));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('z_size_confirm')));
  await tester.tap(find.byKey(const Key('z_size_confirm')));
  await tester.pumpAndSettle();
}

Future<FrameCropResult> next(WidgetTester tester, NestedHarness h) async {
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const Key('z_frame_continue')));
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pump();
  return h.result!;
}

void main() {
  group('nested levels (Saturn print)', () {
    testWidgets('an inner level is never larger than the level around it',
        (tester) async {
      await pumpStep(tester, saturn());
      // Opens on "With frame", snapped to a common size.
      expect(sizeButton(tester).label, '≈ 70 × 50 cm · Check');
      final frame = shownCm(tester);
      await selectChip(tester, 1);
      final noFrame = shownCm(tester);
      await selectChip(tester, 0);
      final artwork = shownCm(tester);

      expect(noFrame.$1, lessThan(frame.$1));
      expect(noFrame.$2, lessThan(frame.$2));
      expect(artwork.$1, lessThan(noFrame.$1));
      expect(artwork.$2, lessThan(noFrame.$2));
    });

    testWidgets('inner levels are measured against the frame', (tester) async {
      await pumpStep(tester, saturn());
      await selectChip(tester, 1);
      // The mat window is ~92 % of the frame both ways.
      expect(shownCm(tester).$1, closeTo(65, 1.5));
      expect(shownCm(tester).$2, closeTo(46, 1.5));
      await selectChip(tester, 0);
      // The print is ~87 % of the frame's height and ~83 % of its width.
      expect(shownCm(tester).$1, closeTo(61, 1.5));
      expect(shownCm(tester).$2, closeTo(41.5, 1.5));
      // Still an estimate.
      expect(sizeButton(tester).label, startsWith('≈ '));
      expect(sizeButton(tester).label, endsWith(' cm · Check'));
      expect(sizeButton(tester).icon, isNot(ZLineIconKind.sizeConfirmed));
    });

    testWidgets('Next reports the inner level’s own size, as an estimate',
        (tester) async {
      final h = await pumpStep(tester, saturn());
      await selectChip(tester, 0);
      final shown = shownCm(tester);
      final r = await next(tester, h);
      expect(r.shownSize!.source, ZSizeSource.estimated);
      expect(r.shownSize!.heightCm, shown.$1);
      expect(r.shownSize!.widthCm, shown.$2);
      expect(r.shownSize!.heightCm, lessThan(70));
      expect(r.size, isNull);
    });

    testWidgets(
        'a size confirmed for the frame scales the inner levels, '
        'and stays exact for the frame', (tester) async {
      final h = await pumpStep(tester, saturn());
      await confirmPreset(tester, '100 × 70');
      expect(sizeButton(tester).label, '100 × 70 cm');

      await selectChip(tester, 0);
      // Not the frame's 100 × 70, and not exact.
      expect(sizeButton(tester).label, startsWith('≈ '));
      final artwork = shownCm(tester);
      expect(artwork.$1, closeTo(100 * 0.87, 2.5));
      expect(artwork.$2, closeTo(70 * 0.83, 2.5));

      await selectChip(tester, 2);
      expect(sizeButton(tester).label, '100 × 70 cm');

      // Next on the artwork: the estimate is shown, nothing is "confirmed"
      // for this outline.
      await selectChip(tester, 0);
      final r = await next(tester, h);
      expect(r.size, isNull);
      expect(r.shownSize!.source, ZSizeSource.estimated);
      expect(r.shownSize!.heightCm, artwork.$1);
    });

    testWidgets('a size confirmed for the artwork scales the frame up',
        (tester) async {
      await pumpStep(tester, saturn());
      await selectChip(tester, 0);
      await confirmPreset(tester, '70 × 50');
      expect(sizeButton(tester).label, '70 × 50 cm');
      await selectChip(tester, 2);
      expect(sizeButton(tester).label, startsWith('≈ '));
      final frame = shownCm(tester);
      expect(frame.$1, greaterThan(70));
      expect(frame.$2, greaterThan(50));
      expect(frame.$1, closeTo(70 / 0.87, 2.5));
    });

    testWidgets(
        'a measured size belongs to the pre-selected outline; '
        'inner levels are scaled from it', (tester) async {
      await pumpStep(tester, saturn(),
          known: const ZArtworkSize(
              heightCm: 71.2, widthCm: 51.3, source: ZSizeSource.measured));
      expect(sizeButton(tester).label, '71.2 × 51.3 cm');
      await selectChip(tester, 0);
      expect(sizeButton(tester).label, startsWith('≈ '));
      expect(shownCm(tester).$1, lessThan(71.2));
      expect(shownCm(tester).$2, lessThan(51.3));
    });

    testWidgets('reopening keeps which outline the size belongs to',
        (tester) async {
      final h = await pumpStep(tester, saturn());
      await confirmPreset(tester, '70 × 50');
      expect(sizeButton(tester).label, '70 × 50 cm');
      final r = await next(tester, h);
      expect(r.size!.source, ZSizeSource.confirmed);

      await tester.pumpWidget(const SizedBox());
      await pumpStep(tester, saturn(), previous: r);
      expect(sizeButton(tester).label, '70 × 50 cm');
      await selectChip(tester, 0);
      expect(sizeButton(tester).label, startsWith('≈ '));
      expect(shownCm(tester).$1, lessThan(70));
    });

    testWidgets(
        'Next on another outline: the confirmed size is kept for its own '
        'outline when the step is reopened', (tester) async {
      final h = await pumpStep(tester, saturn());
      await confirmPreset(tester, '100 × 70');
      await selectChip(tester, 0);
      final artwork = sizeButton(tester).label;
      final r = await next(tester, h);
      expect(r.size, isNull);
      expect(r.anchorSize!.hwText, '100 × 70');

      await tester.pumpWidget(const SizedBox());
      await pumpStep(tester, saturn(), previous: r);
      expect(sizeButton(tester).label, artwork);
      await selectChip(tester, 2);
      expect(sizeButton(tester).label, '100 × 70 cm');
    });
  });

  group('nested levels: outlines, turns and the sheet', () {
    String field(WidgetTester t, String name) => t
        .widget<EditableText>(find.descendant(
            of: find.byKey(Key('z_size_field_$name')),
            matching: find.byType(EditableText)))
        .controller
        .text;

    testWidgets('the sheet opens with the inner level’s own estimate',
        (tester) async {
      await pumpStep(tester, saturn());
      await selectChip(tester, 0);
      final shown = shownCm(tester);
      await tester.tap(find.byKey(const Key('z_frame_size')));
      await tester.pumpAndSettle();
      // Not the 100 × 70 its shape alone would snap to.
      expect(field(tester, 'height'), '≈ ${formatCm(shown.$1)}');
      expect(field(tester, 'width'), '≈ ${formatCm(shown.$2)}');
      await tester.ensureVisible(find.byKey(const Key('z_size_confirm')));
      await tester.tap(find.byKey(const Key('z_size_confirm')));
      await tester.pumpAndSettle();
      expect(sizeButton(tester).label,
          '${formatCm(shown.$1)} × ${formatCm(shown.$2)} cm');
    });

    testWidgets('the outermost outline opens the sheet on its common size',
        (tester) async {
      await pumpStep(tester, saturn());
      await tester.tap(find.byKey(const Key('z_frame_size')));
      await tester.pumpAndSettle();
      expect(field(tester, 'height'), '70');
      expect(field(tester, 'width'), '50');
    });

    testWidgets('turning the photo keeps the levels in order', (tester) async {
      await pumpStep(tester, saturn());
      await tester.tap(find.byKey(const Key('z_frame_rotate')));
      await tester.pump();
      // Now wide: 50 high, 70 wide.
      expect(sizeButton(tester).label, '≈ 50 × 70 cm · Check');
      await selectChip(tester, 0);
      final artwork = shownCm(tester);
      expect(artwork.$1, closeTo(41.5, 1.5));
      expect(artwork.$2, closeTo(61, 1.5));
    });

    testWidgets('a confirmed size follows its outline through a turn',
        (tester) async {
      await pumpStep(tester, saturn());
      await confirmPreset(tester, '70 × 50');
      await tester.tap(find.byKey(const Key('z_frame_rotate')));
      await tester.pump();
      // Still the frame's size (as before this change).
      expect(sizeButton(tester).label, '70 × 50 cm');
      await selectChip(tester, 0);
      expect(sizeButton(tester).label, startsWith('≈ '));
      await tester.tap(find.byKey(const Key('z_frame_reset')));
      await tester.pump();
      expect(sizeButton(tester).label, '70 × 50 cm');
    });

    testWidgets('dragging the confirmed outline keeps its size exact',
        (tester) async {
      await pumpStep(tester, saturn());
      await confirmPreset(tester, '70 × 50');
      final handle =
          tester.getCenter(find.byKey(const Key('z_frame_handle_0')));
      await dragStepwise(tester, handle, const Offset(6, 6));
      expect(sizeButton(tester).label, '70 × 50 cm');
      // The artwork is then measured against the dragged frame.
      await selectChip(tester, 0);
      expect(sizeButton(tester).label, startsWith('≈ '));
      expect(shownCm(tester).$1, lessThan(70));
    });

    testWidgets('a hand-dragged outline inside the frame is sized from it',
        (tester) async {
      await pumpStep(tester, saturn());
      // Drag the artwork's top-left corner: still inside the frame.
      await selectChip(tester, 0);
      final before = shownCm(tester);
      final handle =
          tester.getCenter(find.byKey(const Key('z_frame_handle_0')));
      await dragStepwise(tester, handle, const Offset(20, 30));
      final after = shownCm(tester);
      expect(after.$1, lessThan(before.$1));
      expect(after.$2, lessThan(before.$2));
    });

    testWidgets('the full photo is not a level: its own estimate',
        (tester) async {
      await pumpStep(tester, saturn());
      await confirmPreset(tester, '70 × 50');
      await tester.tap(find.byKey(const Key('z_frame_full')));
      await tester.pump();
      // 270 × 480 px: about 16 : 9, no common size.
      expect(sizeButton(tester).label, '≈ 60 × 35 cm · Check');
    });

    testWidgets(
        'a size from the artwork’s details is not tied to an outline: exact '
        'wherever its shape fits', (tester) async {
      await pumpStep(tester, saturn(),
          known: const ZArtworkSize(
              heightCm: 70, widthCm: 50, source: ZSizeSource.details));
      expect(sizeButton(tester).label, '70 × 50 cm');
      await selectChip(tester, 0);
      // Equal, never larger: the details may describe either level.
      expect(sizeButton(tester).label, '70 × 50 cm');
    });

    testWidgets('a round opening inside a frame gets one diameter',
        (tester) async {
      await pumpStep(tester, [
        ZFrameCandidate(
            label: 'Artwork',
            shape: ZFrameShape.round,
            corners: const [
              Offset(0.3, 0.38),
              Offset(0.7, 0.38),
              Offset(0.7, 0.61),
              Offset(0.3, 0.61),
            ]),
        saturn().last,
      ]);
      await selectChip(tester, 0);
      final (h, w) = shownCm(tester);
      expect(h, w);
      expect(h, lessThan(50));
      expect(h, greaterThan(25));
    });

    testWidgets('one outline only: its common size, as before', (tester) async {
      await pumpStep(tester, [saturn().last]);
      expect(sizeButton(tester).label, '≈ 70 × 50 cm · Check');
    });
  });

  group('no common size has the shape (TV, 16 : 9)', () {
    testWidgets('an approximate size is still shown, with lines',
        (tester) async {
      final h = await pumpStep(tester, [
        ZFrameCandidate(label: 'Artwork', corners: tv),
      ]);
      final text = sizeButton(tester).label;
      expect(text, isNot('Size · Check'));
      expect(text, startsWith('≈ '));
      expect(text, endsWith(' cm · Check'));
      expect(find.byKey(const Key('z_frame_height_line')), findsOneWidget);
      final (hCm, wCm) = shownCm(tester);
      // The photo's own shape (about 16 : 9, tall), not a common size's.
      expect(hCm / wCm, closeTo(16 / 9, 0.12));
      // A medium-sized artwork: as large as the typical 50 × 40.
      expect(hCm * wCm, closeTo(2000, 300));
      final r = await next(tester, h);
      expect(r.shownSize!.source, ZSizeSource.estimated);
      expect(r.shownSize!.heightCm, hCm);
    });
  });
}
