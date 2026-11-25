import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/image_editor.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector;
import 'frame_size_tools_test.dart' show sizeButton, sizeTheme;
import 'nested_size_test.dart';

/// A nearly square frame (216 × 216 px of the 270 × 480 photo) around an
/// upright artwork (108 × 154 px, H : W 1.43), innermost first.
List<ZFrameCandidate> squareFrame() => [
      ZFrameCandidate(
          label: 'Artwork',
          level: ZFrameLevel.artwork,
          corners: const [
            Offset(0.3, 0.34),
            Offset(0.7, 0.34),
            Offset(0.7, 0.66),
            Offset(0.3, 0.66),
          ]),
      ZFrameCandidate(
          label: 'With frame',
          level: ZFrameLevel.frame,
          preselected: true,
          corners: const [
            Offset(0.1, 0.275),
            Offset(0.9, 0.275),
            Offset(0.9, 0.725),
            Offset(0.1, 0.725),
          ]),
    ];

/// The sizes shown on every chip, innermost first.
Future<List<(double, double)>> sizesOfChips(WidgetTester tester, int n) async {
  final out = <(double, double)>[];
  for (var i = 0; i < n; i++) {
    await selectChip(tester, i);
    out.add(shownCm(tester));
  }
  return out;
}

void expectNested(List<(double, double)> sizes, String reason) {
  for (var i = 1; i < sizes.length; i++) {
    expect(sizes[i - 1].$1, lessThanOrEqualTo(sizes[i].$1),
        reason: '$reason: heights $sizes');
    expect(sizes[i - 1].$2, lessThanOrEqualTo(sizes[i].$2),
        reason: '$reason: widths $sizes');
  }
}

void main() {
  testWidgets(
      'a size from the details that fits the artwork only: the frame is '
      'not smaller than the artwork', (tester) async {
    await pumpStep(tester, squareFrame(),
        known: const ZArtworkSize(
            heightCm: 100, widthCm: 70, source: ZSizeSource.details));
    final sizes = await sizesOfChips(tester, 2);
    expect(sizes.first, (100, 70));
    expectNested(sizes, 'details 100 × 70');
    // The frame is scaled from the artwork, as an estimate.
    await selectChip(tester, 1);
    expect(sizeButton(tester).label, startsWith('≈ '));
  });

  group('an inner outline is never larger than the one around it', () {
    const sources = <String, ZArtworkSize?>{
      'estimate': null,
      'details 70 × 50':
          ZArtworkSize(heightCm: 70, widthCm: 50, source: ZSizeSource.details),
      'details 100 × 70':
          ZArtworkSize(heightCm: 100, widthCm: 70, source: ZSizeSource.details),
      'details 30 × 30':
          ZArtworkSize(heightCm: 30, widthCm: 30, source: ZSizeSource.details),
      'measured 71.2 × 51.3': ZArtworkSize(
          heightCm: 71.2, widthCm: 51.3, source: ZSizeSource.measured),
      'measured 33 × 33':
          ZArtworkSize(heightCm: 33, widthCm: 33, source: ZSizeSource.measured),
    };
    final scenes = <String, List<ZFrameCandidate> Function()>{
      'Saturn': saturn,
      'square frame': squareFrame,
    };
    for (final scene in scenes.entries) {
      for (final source in sources.entries) {
        testWidgets('${scene.key}, ${source.key}', (tester) async {
          final n = scene.value().length;
          await pumpStep(tester, scene.value(), known: source.value);
          expectNested(await sizesOfChips(tester, n), 'as opened');
          await tester.tap(find.byKey(const Key('z_frame_rotate')));
          await tester.pump();
          expectNested(await sizesOfChips(tester, n), 'turned');
        });
      }
      // Confirmed in the sheet on each outline in turn.
      for (var on = 0; on < scene.value().length; on++) {
        testWidgets('${scene.key}, confirmed on chip $on', (tester) async {
          final n = scene.value().length;
          await pumpStep(tester, scene.value());
          await selectChip(tester, on);
          await tester.tap(find.byKey(const Key('z_frame_size')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('z_size_confirm')));
          await tester.tap(find.byKey(const Key('z_size_confirm')));
          await tester.pumpAndSettle();
          expect(sizeButton(tester).label, isNot(startsWith('≈')));
          expectNested(await sizesOfChips(tester, n), 'confirmed on $on');
          await tester.tap(find.byKey(const Key('z_frame_rotate')));
          await tester.pump();
          expectNested(await sizesOfChips(tester, n), 'turned');
        });
      }
    }
  });

  testWidgets('Reset after dragging the confirmed outline keeps its size',
      (tester) async {
    final h = await pumpStep(tester, saturn());
    await confirmPreset(tester, '70 × 50');
    final handle = tester.getCenter(find.byKey(const Key('z_frame_handle_0')));
    await dragStepwise(tester, handle, const Offset(6, 6));
    expect(sizeButton(tester).label, '70 × 50 cm');
    await tester.tap(find.byKey(const Key('z_frame_reset')));
    await tester.pump();
    expect(sizeButton(tester).label, '70 × 50 cm');
    final r = await next(tester, h);
    expect(r.size!.source, ZSizeSource.confirmed);
  });

  testWidgets(
      'coming back to the confirmed chip after dragging it keeps its size',
      (tester) async {
    await pumpStep(tester, saturn());
    await confirmPreset(tester, '70 × 50');
    final handle = tester.getCenter(find.byKey(const Key('z_frame_handle_0')));
    await dragStepwise(tester, handle, const Offset(6, 6));
    await selectChip(tester, 0);
    await selectChip(tester, 2);
    expect(sizeButton(tester).label, '70 × 50 cm');
  });

  testWidgets('a round inner outline keeps one diameter when it is capped',
      (tester) async {
    // Inside the Saturn frame (≈ 70 × 50): 96 % of its width, 80 % of its
    // height, i.e. about 56 high and 48 wide before it is made round.
    await pumpStep(tester, [
      ZFrameCandidate(
          label: 'Artwork',
          shape: ZFrameShape.round,
          corners: const [
            Offset(0.155, 0.3),
            Offset(0.75, 0.295),
            Offset(0.75, 0.685),
            Offset(0.17, 0.685),
          ]),
      saturn().last,
    ]);
    await selectChip(tester, 0);
    final (h, w) = shownCm(tester);
    expect(h, w);
    expect(h, lessThanOrEqualTo(50));
  });

  testWidgets('a size confirmed on the full photo is no reference',
      (tester) async {
    await pumpStep(tester, saturn());
    await tester.tap(find.byKey(const Key('z_frame_full')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('z_frame_size')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byKey(const Key('z_size_field_height')),
            matching: find.byType(EditableText)),
        '200');
    await tester.enterText(
        find.descendant(
            of: find.byKey(const Key('z_size_field_width')),
            matching: find.byType(EditableText)),
        '112');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('z_size_confirm')));
    await tester.tap(find.byKey(const Key('z_size_confirm')));
    await tester.pumpAndSettle();
    expect(sizeButton(tester).label, '200 × 112 cm');
    await selectChip(tester, 2);
    // The frame's own estimate, not a share of the photo's "size".
    expect(sizeButton(tester).label, '≈ 70 × 50 cm · Check');
    await tester.tap(find.byKey(const Key('z_frame_full')));
    await tester.pump();
    expect(sizeButton(tester).label, '200 × 112 cm');
  });

  group('the sheet says which outline the size is for', () {
    String heading(WidgetTester t) =>
        t.widget<Text>(find.byKey(const Key('z_size_dimensions'))).data!;

    testWidgets('outermost outline: including frame', (tester) async {
      await pumpStep(tester, saturn());
      await tester.tap(find.byKey(const Key('z_frame_size')));
      await tester.pumpAndSettle();
      expect(heading(tester), 'Dimensions, including frame (cm)');
    });

    testWidgets('an outline inside the frame: without frame', (tester) async {
      await pumpStep(tester, saturn());
      await selectChip(tester, 0);
      await tester.tap(find.byKey(const Key('z_frame_size')));
      await tester.pumpAndSettle();
      expect(heading(tester), 'Dimensions, without frame (cm)');
    });

    testWidgets('a single outline: including frame, as before', (tester) async {
      await pumpStep(tester, [saturn().last]);
      await tester.tap(find.byKey(const Key('z_frame_size')));
      await tester.pumpAndSettle();
      expect(heading(tester), 'Dimensions, including frame (cm)');
    });
  });

  group('editor callbacks', () {
    Future<(List<ZArtworkSize>, List<ZArtworkSize>)> pump(
        WidgetTester tester) async {
      final confirmed = <ZArtworkSize>[];
      final shown = <ZArtworkSize>[];
      await pumpEditor(
        tester,
        ZImageEditor(
          imageBytesList: [testPng(w: 270, h: 480)],
          frameDetector: FakeDetector(saturn()),
          enableSizeTools: true,
          enableAutoFix: false,
          theme: sizeTheme,
          onArtworkSizeConfirmed: confirmed.add,
          onArtworkSize: shown.add,
          onSaveAll: (_) {},
          onCancel: () {},
        ),
      );
      return (confirmed, shown);
    }

    testWidgets(
        'confirmed for the frame, Next on the artwork: the confirmed size '
        'is reported, and the artwork’s own size as shown', (tester) async {
      final (confirmed, shown) = await pump(tester);
      await confirmPreset(tester, '70 × 50');
      await selectChip(tester, 0);
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      await settleAsync(tester, 60);
      expect(confirmed,
          [const ZArtworkSize(heightCm: 70, widthCm: 50, depthCm: 2)]);
      expect(shown, hasLength(1));
      expect(shown.single.source, ZSizeSource.estimated);
      expect(shown.single.heightCm, lessThan(70));
    });

    testWidgets('a confirmed size is reported once, not on every Next',
        (tester) async {
      final (confirmed, shown) = await pump(tester);
      await confirmPreset(tester, '70 × 50');
      await selectChip(tester, 0);
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      await settleAsync(tester, 60);
      // ‹ Frame, back on the frame chip, Next again.
      await tester.tap(find.byKey(const Key('z_editor_cancel')));
      await settleAsync(tester);
      await selectChip(tester, 2);
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      await settleAsync(tester, 60);
      expect(confirmed, hasLength(1));
      expect(shown, hasLength(2));
      // A new size is reported again.
      await tester.tap(find.byKey(const Key('z_editor_cancel')));
      await settleAsync(tester);
      await confirmPreset(tester, '100 × 70');
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      await settleAsync(tester, 60);
      expect(confirmed.map((s) => s.hwText), ['70 × 50', '100 × 70']);
    });
  });

  testWidgets('a landscape 16 : 9 screen: "≈ 35 × 60 cm" (height × width)',
      (tester) async {
    await pumpStep(tester, [
      ZFrameCandidate(label: 'Artwork', corners: const [
        Offset(0.1, 0.4),
        Offset(0.9, 0.4),
        Offset(0.9, 0.653),
        Offset(0.1, 0.653),
      ]),
    ]);
    expect(sizeButton(tester).label, '≈ 35 × 60 cm · Check');
  });
}
