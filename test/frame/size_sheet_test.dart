import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/z_image_editor.dart';

import 'frame_step_design_test.dart' show designTheme;

class SheetHarness {
  ZArtworkSize? confirmed;
  bool kept = false;
}

Future<SheetHarness> pumpSheet(
  WidgetTester tester,
  Size size, {
  double? aspect = 1.25,
  ZArtworkSize? initial,
  double keyboard = 0,
  ZImageEditorTheme theme = designTheme,
}) async {
  final h = SheetHarness();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF1C1A1A),
      resizeToAvoidBottomInset: false,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height - 56),
          child: ZArtworkSizeSheet(
            theme: theme,
            estimatedAspectHW: aspect,
            initial: initial,
            onConfirm: (s) => h.confirmed = s,
            onKeepEstimate: () => h.kept = true,
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  return h;
}

String fieldText(WidgetTester t, String name) =>
    t.widget<TextField>(find.byKey(Key('z_size_field_$name'))).controller!.text;

Future<void> tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
}

void main() {
  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    group('size sheet @ $s', () {
      testWidgets('best fit: estimated shape, presets, 50 × 40 pre-filled',
          (tester) async {
        await pumpSheet(tester, size);
        expect(find.text('Real size of the artwork'), findsOneWidget);
        expect(find.textContaining('about 5 : 4 (H : W)', findRichText: true),
            findsOneWidget);
        expect(find.text('Best fit'), findsOneWidget);
        expect(fieldText(tester, 'height'), '50');
        expect(fieldText(tester, 'width'), '40');
        expect(fieldText(tester, 'depth'), '≈ 2');
        expect(find.text('Confirm 50 × 40 × 2 cm'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('each common size fills height and width', (tester) async {
        await pumpSheet(tester, size);
        for (final label in [
          '40 × 30',
          '50 × 40',
          '70 × 50',
          '100 × 70',
          'A3 · 42 × 30',
          'A4 · 30 × 21',
        ]) {
          await tapVisible(tester, find.byKey(Key('z_size_preset_$label')));
          final hw = label.split(' · ').last.split(' × ');
          expect(fieldText(tester, 'height'), hw[0], reason: label);
          expect(fieldText(tester, 'width'), hw[1], reason: label);
          expect(
              find.text('Confirm ${hw[0]} × ${hw[1]} × 2 cm'), findsOneWidget);
        }
      });

      testWidgets('each depth chip sets the depth', (tester) async {
        await pumpSheet(tester, size);
        for (final (label, cm) in const [
          ('Paper 0.1', '0.1'),
          ('Canvas 2', '2'),
          ('Deep canvas 4', '4'),
          ('Framed 3', '3'),
        ]) {
          await tapVisible(
              tester,
              find.byKey(Key(
                  'z_size_depth_${label.split(' ').first == 'Deep' ? 'Deep canvas' : label.split(' ').first}')));
          expect(fieldText(tester, 'depth'), cm, reason: label);
          expect(find.text('Confirm 50 × 40 × $cm cm'), findsOneWidget);
        }
      });

      testWidgets('typing a side fills in the other (≈) from the shape',
          (tester) async {
        await pumpSheet(tester, size, aspect: 0.25);
        expect(find.byKey(const Key('z_size_presets')), findsNothing);
        expect(find.textContaining('wide, about 1 : 4', findRichText: true),
            findsOneWidget);
        expect(find.text('How sizes are suggested'), findsOneWidget);
        await tester
            .ensureVisible(find.byKey(const Key('z_size_field_height')));
        await tester.enterText(
            find.byKey(const Key('z_size_field_height')), '50');
        await tester.pump();
        expect(fieldText(tester, 'width'), '≈ 200');
        expect(find.text('Confirm 50 × 200 × 2 cm'), findsOneWidget);
        // Typing the width instead fills the height.
        await tester.enterText(
            find.byKey(const Key('z_size_field_height')), '');
        await tester.enterText(
            find.byKey(const Key('z_size_field_width')), '120');
        await tester.pump();
        expect(fieldText(tester, 'height'), '≈ 30');
      });

      testWidgets('typed depth replaces the default', (tester) async {
        await pumpSheet(tester, size);
        await tester.ensureVisible(find.byKey(const Key('z_size_field_depth')));
        await tester.enterText(
            find.byKey(const Key('z_size_field_depth')), '5');
        await tester.pump();
        expect(find.text('Confirm 50 × 40 × 5 cm'), findsOneWidget);
      });

      testWidgets('Confirm returns the size; disabled without both sides',
          (tester) async {
        final h = await pumpSheet(tester, size, aspect: null);
        expect(find.text('Confirm'), findsOneWidget);
        await tester.tap(find.byKey(const Key('z_size_confirm')));
        expect(h.confirmed, isNull);
        await tester.enterText(
            find.byKey(const Key('z_size_field_height')), '60');
        await tester.enterText(
            find.byKey(const Key('z_size_field_width')), '45');
        await tester.pump();
        await tester.tap(find.byKey(const Key('z_size_confirm')));
        expect(h.confirmed,
            const ZArtworkSize(heightCm: 60, widthCm: 45, depthCm: 2));
      });

      testWidgets('"I don’t know, keep the estimated shape"', (tester) async {
        final h = await pumpSheet(tester, size);
        await tester.tap(find.byKey(const Key('z_size_keep')));
        expect(h.kept, isTrue);
        expect(h.confirmed, isNull);
      });

      testWidgets('keyboard open: Confirm pinned above it, no "I don’t know"',
          (tester) async {
        await pumpSheet(tester, size, keyboard: 290);
        expect(find.byKey(const Key('z_size_keep')), findsNothing);
        final confirm = tester.getRect(find.byKey(const Key('z_size_confirm')));
        expect(confirm.bottom, lessThanOrEqualTo(size.height - 290));
        expect(find.text('Real size of the artwork'), findsOneWidget);
      });

      testWidgets('known size: fields filled, depth kept', (tester) async {
        await pumpSheet(tester, size,
            initial: const ZArtworkSize(heightCm: 61, widthCm: 46, depthCm: 3));
        expect(fieldText(tester, 'height'), '61');
        expect(fieldText(tester, 'depth'), '3');
        expect(find.text('Confirm 61 × 46 × 3 cm'), findsOneWidget);
      });
    });
  }

  testWidgets('the sheet scrolls on a small phone', (tester) async {
    await pumpSheet(tester, const Size(360, 640));
    final scroll = tester.state<ScrollableState>(find
        .descendant(
            of: find.byKey(const Key('z_size_scroll')),
            matching: find.byType(Scrollable))
        .first);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('showZArtworkSizeSheet resolves to the confirmed size',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ZArtworkSize? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showZArtworkSizeSheet(
            context,
            theme: designTheme,
            estimatedAspectHW: 1.25,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('z_size_confirm')));
    await tester.pumpAndSettle();
    expect(result, const ZArtworkSize(heightCm: 50, widthCm: 40, depthCm: 2));
  });
}
