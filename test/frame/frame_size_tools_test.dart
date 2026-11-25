import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/image_editor.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector, rect;

const sizeTheme = ZImageEditorTheme(
  showMeasurements: true,
  primaryButtonTextColor: Color(0xFFFDFDFB),
  textColor: Color(0xFFFDFDFB),
);

class SizeHarness {
  FrameCropResult? result;
}

/// 300 x 400 test photo; the candidate covers 80 % of it: 240 x 320 px,
/// i.e. H : W = 4 : 3 -> best fit 40 x 30 cm.
Future<SizeHarness> pumpSizeStep(
  WidgetTester tester,
  Size size, {
  ZArtworkSize? known,
  List<ZFrameCandidate>? candidates,
}) async {
  final h = SizeHarness();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: FrameCropView(
        imageBytes: testPng(w: 300, h: 400),
        detector: FakeDetector(candidates ?? [rect('With frame', 0.1)]),
        theme: sizeTheme,
        sizeTools: true,
        knownSize: known,
        onCancel: () {},
        onContinue: (r) => h.result = r,
        warp: (b, c) async => Uint8List.fromList([1]),
      ),
    ));
  });
  await settleAsync(tester);
  return h;
}

ZToolButton sizeButton(WidgetTester t) =>
    t.widget<ZToolButton>(find.byKey(const Key('z_frame_size')));

String label(WidgetTester t, String key) => t
    .widget<Text>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)))
    .data!;

void main() {
  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    group('size tools @ $s', () {
      testWidgets('estimated: "≈ 40 × 30 cm · Check", dashed icon, ≈ lines',
          (tester) async {
        await pumpSizeStep(tester, size);
        final b = sizeButton(tester);
        expect(b.label, '≈ 40 × 30 cm · Check');
        expect(b.icon, ZLineIconKind.sizeEstimated);
        expect(b.active, isFalse);
        expect(label(tester, 'z_frame_height_label'), '≈ 40 cm');
        expect(label(tester, 'z_frame_width_label'), '≈ 30 cm');
        // Size comes first in the tool row.
        final x = tester.getCenter(find.byKey(const Key('z_frame_size'))).dx;
        expect(
            x,
            lessThan(
                tester.getCenter(find.byKey(const Key('z_frame_rotate'))).dx));
      });

      testWidgets('Size opens the sheet; Confirm locks the size',
          (tester) async {
        await pumpSizeStep(tester, size);
        await tester.tap(find.byKey(const Key('z_frame_size')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('z_size_sheet')), findsOneWidget);
        await tester
            .ensureVisible(find.byKey(const Key('z_size_preset_50 × 40')));
        await tester.tap(find.byKey(const Key('z_size_preset_50 × 40')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('z_size_confirm')));
        await tester.pumpAndSettle();
        final b = sizeButton(tester);
        expect(b.label, '50 × 40 cm');
        expect(b.icon, ZLineIconKind.sizeConfirmed);
        expect(b.active, isTrue);
        expect(label(tester, 'z_frame_height_label'), '50 cm');
        expect(label(tester, 'z_frame_width_label'), '40 cm');
      });

      testWidgets('"I don’t know" keeps the estimate', (tester) async {
        await pumpSizeStep(tester, size);
        await tester.tap(find.byKey(const Key('z_frame_size')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('z_size_keep')));
        await tester.tap(find.byKey(const Key('z_size_keep')));
        await tester.pumpAndSettle();
        expect(sizeButton(tester).label, '≈ 40 × 30 cm · Check');
      });

      testWidgets('known size: no ≈, and Next gives it the real shape',
          (tester) async {
        // A3 (42 × 30, H : W 1.4) is within 12 % of the 4 : 3 outline.
        final h = await pumpSizeStep(tester, size,
            known: const ZArtworkSize(
                heightCm: 42, widthCm: 30, source: ZSizeSource.details));
        expect(sizeButton(tester).label, '42 × 30 cm');
        expect(sizeButton(tester).icon, ZLineIconKind.sizeConfirmed);
        expect(label(tester, 'z_frame_height_label'), '42 cm');
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('z_frame_continue')));
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
        expect(h.result!.outputAspectWH, closeTo(30 / 42, 1e-9));
        expect(h.result!.size!.source, ZSizeSource.details);
      });

      for (final (name, known) in const [
        ('another shape (60 × 30)', ZArtworkSize(heightCm: 60, widthCm: 30)),
        ('height and width swapped (30 × 40)',
            ZArtworkSize(heightCm: 30, widthCm: 40)),
      ]) {
        testWidgets('known size of $name: estimate, "≈ … · Check"',
            (tester) async {
          final h = await pumpSizeStep(tester, size,
              known: ZArtworkSize(
                  heightCm: known.heightCm,
                  widthCm: known.widthCm,
                  source: ZSizeSource.details));
          final b = sizeButton(tester);
          expect(b.label, '≈ 40 × 30 cm · Check');
          expect(b.icon, ZLineIconKind.sizeEstimated);
          expect(b.active, isFalse);
          expect(label(tester, 'z_frame_height_label'), '≈ 40 cm');
          await tester.runAsync(() async {
            await tester.tap(find.byKey(const Key('z_frame_continue')));
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pump();
          // The photo's shape, not the details' size.
          expect(h.result!.outputAspectWH, closeTo(0.75, 0.01));
          expect(h.result!.size, isNull);
        });
      }

      testWidgets('the sheet shows the photo’s estimate after a confirm',
          (tester) async {
        await pumpSizeStep(tester, size);
        await tester.tap(find.byKey(const Key('z_frame_size')));
        await tester.pumpAndSettle();
        await tester
            .ensureVisible(find.byKey(const Key('z_size_preset_50 × 40')));
        await tester.tap(find.byKey(const Key('z_size_preset_50 × 40')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('z_size_confirm')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('z_frame_size')));
        await tester.pumpAndSettle();
        // 4 : 3 from the outline, not 5 : 4 from the confirmed 50 × 40.
        expect(find.textContaining('about 4 : 3 (H : W)', findRichText: true),
            findsOneWidget);
      });

      testWidgets('no matching size: "Size · Check" and no lines',
          (tester) async {
        await pumpSizeStep(tester, size, candidates: [
          ZFrameCandidate(label: 'Wide', corners: const [
            Offset(0.05, 0.45),
            Offset(0.95, 0.45),
            Offset(0.95, 0.55),
            Offset(0.05, 0.55),
          ]),
        ]);
        expect(sizeButton(tester).label, 'Size · Check');
        expect(find.byKey(const Key('z_frame_height_line')), findsNothing);
      });

      testWidgets('lines stay inside the screen for a full-width outline',
          (tester) async {
        await pumpSizeStep(tester, size);
        await tester.tap(find.byKey(const Key('z_frame_full')));
        await tester.pump();
        final canvas = tester.getRect(find.byKey(const Key('z_frame_canvas')));
        final v = tester.getRect(find.byKey(const Key('z_frame_height_line')));
        final w = tester.getRect(find.byKey(const Key('z_frame_width_line')));
        expect(v.right, lessThanOrEqualTo(canvas.right + 0.5));
        expect(w.bottom, lessThanOrEqualTo(canvas.bottom + 0.5));
      });
    });
  }

  testWidgets('without sizeTools there is no Size button and no lines',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: FrameCropView(
          imageBytes: testPng(w: 300, h: 400),
          detector: FakeDetector([rect('With frame', 0.1)]),
          theme: sizeTheme,
          onCancel: () {},
          onContinue: (_) {},
        ),
      ));
    });
    await settleAsync(tester);
    expect(find.byKey(const Key('z_frame_size')), findsNothing);
    expect(find.byKey(const Key('z_frame_height_line')), findsNothing);
  });

  testWidgets('editor reports a confirmed size after Next', (tester) async {
    ZArtworkSize? reported;
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng(w: 300, h: 400)],
        frameDetector: FakeDetector([rect('With frame', 0.1)]),
        enableSizeTools: true,
        theme: sizeTheme,
        onArtworkSizeConfirmed: (s) => reported = s,
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    await tester.tap(find.byKey(const Key('z_frame_size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('z_size_confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('z_frame_continue')));
    await settleAsync(tester, 60);
    expect(reported, const ZArtworkSize(heightCm: 40, widthCm: 30, depthCm: 2));
  });
}
