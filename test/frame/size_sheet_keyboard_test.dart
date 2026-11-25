import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/z_image_editor.dart';

import 'frame_step_design_test.dart' show designTheme;
import 'size_sheet_test.dart' show fieldText, pumpSheet, tapVisible;

/// Opens the sheet the way the frame step does (modal bottom sheet).
Future<void> openSheet(WidgetTester tester, Size size,
    {double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => showZArtworkSizeSheet(
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
}

Finder field(String name) => find.byKey(Key('z_size_field_$name'));

EditableTextState editable(WidgetTester t, String name) => t.state(
    find.descendant(of: field(name), matching: find.byType(EditableText)));

Element fieldElement(WidgetTester t, String name) => t.element(field(name));

Rect rectOf(WidgetTester t, Finder f) => t.getRect(f);

const presetLabels = [
  '50 × 40',
  '40 × 30',
  '70 × 50',
  '100 × 70',
  'A3 · 42 × 30',
  'A4 · 30 × 21',
];
const depthKeys = ['Paper', 'Canvas', 'Deep canvas', 'Framed'];

Map<String, Rect> buttonRects(WidgetTester t) => {
      for (final l in presetLabels)
        'p $l': t.getRect(find.byKey(Key('z_size_preset_$l'))),
      for (final d in depthKeys)
        'd $d': t.getRect(find.byKey(Key('z_size_depth_$d'))),
      // The label inside each button too: a bolder or wider label, or a
      // thicker border, moved the text even when the button stayed put.
      for (final l in presetLabels)
        't $l': t.getRect(find
            .descendant(
                of: find.byKey(Key('z_size_preset_$l')),
                matching: find.byType(Text))
            .first),
      for (final d in depthKeys)
        't $d': t.getRect(find.descendant(
            of: find.byKey(Key('z_size_depth_$d')),
            matching: find.byType(Text))),
    };

void main() {
  for (final (size, keyboard) in const [
    (Size(360, 640), 260.0),
    (Size(390, 844), 336.0),
    (Size(430, 932), 346.0),
  ]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    group('keyboard @ $s', () {
      for (final name in const ['height', 'width', 'depth']) {
        testWidgets(
            'tapping $name keeps focus and the same field when the '
            'keyboard opens; typing updates Confirm', (tester) async {
          await openSheet(tester, size);
          await tester.ensureVisible(field(name));
          await tester.pumpAndSettle();
          await tester.tap(field(name));
          await tester.pump();
          final state = editable(tester, name);
          final element = fieldElement(tester, name);
          expect(state.widget.focusNode.hasFocus, isTrue);

          // The keyboard slides in over a few frames.
          for (final inset in [keyboard / 3, keyboard * 2 / 3, keyboard]) {
            tester.view.viewInsets = FakeViewPadding(bottom: inset);
            await tester.pump(const Duration(milliseconds: 16));
            expect(editable(tester, name), same(state), reason: '$inset');
            expect(state.widget.focusNode.hasFocus, isTrue,
                reason: 'focus lost at inset $inset');
          }
          await tester.pumpAndSettle();
          expect(identical(fieldElement(tester, name), element), isTrue);
          expect(editable(tester, name), same(state));
          expect(state.widget.focusNode.hasFocus, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);

          // The field is scrolled into view and Confirm sits above the
          // keyboard.
          final confirm =
              rectOf(tester, find.byKey(const Key('z_size_confirm')));
          final f = rectOf(tester, field(name));
          expect(confirm.bottom, lessThanOrEqualTo(size.height - keyboard));
          expect(f.bottom, lessThanOrEqualTo(confirm.top));
          expect(f.top, greaterThanOrEqualTo(0));

          tester.testTextInput.enterText('55');
          await tester.pump();
          expect(editable(tester, name), same(state));
          expect(state.widget.focusNode.hasFocus, isTrue);
          final expected = switch (name) {
            'height' => 'Confirm 55 × 40 × 2 cm',
            'width' => 'Confirm 50 × 55 × 2 cm',
            _ => 'Confirm 50 × 40 × 55 cm',
          };
          expect(find.text(expected), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('text scale 1.3: focus survives the keyboard',
          (tester) async {
        await openSheet(tester, size, textScale: 1.3);
        await tester.ensureVisible(field('width'));
        await tester.pumpAndSettle();
        await tester.tap(field('width'));
        await tester.pump();
        final state = editable(tester, 'width');
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
        expect(editable(tester, 'width'), same(state));
        expect(state.widget.focusNode.hasFocus, isTrue);
        final confirm = rectOf(tester, find.byKey(const Key('z_size_confirm')));
        expect(confirm.bottom, lessThanOrEqualTo(size.height - keyboard));
        expect(rectOf(tester, field('width')).bottom,
            lessThanOrEqualTo(confirm.top));
        expect(tester.takeException(), isNull);
      });

      testWidgets('tapping an estimated depth (≈ 2) keeps focus',
          (tester) async {
        await openSheet(tester, size);
        expect(fieldText(tester, 'depth'), '≈ 2');
        await tester.ensureVisible(field('depth'));
        await tester.pumpAndSettle();
        await tester.tap(field('depth'));
        await tester.pump();
        final state = editable(tester, 'depth');
        expect(fieldText(tester, 'depth'), '2');
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
        expect(editable(tester, 'depth'), same(state));
        expect(state.widget.focusNode.hasFocus, isTrue);
      });
    });
  }

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    group('presets stay put @ $s', () {
      testWidgets('selecting a common size or a depth moves nothing',
          (tester) async {
        await pumpSheet(tester, size);
        final before = buttonRects(tester);
        for (final l in presetLabels) {
          await tapVisible(tester, find.byKey(Key('z_size_preset_$l')));
          // tapVisible may scroll: compare positions relative to the grid.
        }
        await tester.drag(
            find.byKey(const Key('z_size_scroll')), const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(buttonRects(tester), before);
        for (final d in depthKeys) {
          await tapVisible(tester, find.byKey(Key('z_size_depth_$d')));
          await tester.drag(
              find.byKey(const Key('z_size_scroll')), const Offset(0, 2000));
          await tester.pumpAndSettle();
          final after = buttonRects(tester);
          for (final k in before.keys) {
            expect(after[k], before[k], reason: '$k after depth $d');
          }
        }
      });

      testWidgets('typing a value that clears the selection moves nothing',
          (tester) async {
        await pumpSheet(tester, size);
        final before = buttonRects(tester);
        await tester.ensureVisible(field('height'));
        await tester.enterText(field('height'), '63');
        await tester.enterText(field('depth'), '7');
        await tester.pump();
        await tester.drag(
            find.byKey(const Key('z_size_scroll')), const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(buttonRects(tester), before);
      });
    });

    group('manual entry and presets @ $s', () {
      bool presetSelected(WidgetTester t, String l) => t
          .widget<Semantics>(find
              .descendant(
                  of: find.byKey(Key('z_size_preset_$l')),
                  matching: find.byType(Semantics))
              .first)
          .properties
          .selected!;
      bool depthSelected(WidgetTester t, String d) => t
          .widget<Semantics>(find
              .descendant(
                  of: find.byKey(Key('z_size_depth_$d')),
                  matching: find.byType(Semantics))
              .first)
          .properties
          .selected!;

      testWidgets('typing clears / re-selects the preset; tapping fills',
          (tester) async {
        await pumpSheet(tester, size);
        expect(presetSelected(tester, '50 × 40'), isTrue);
        await tester.ensureVisible(field('height'));
        await tester.enterText(field('height'), '63');
        await tester.enterText(field('width'), '47');
        await tester.pump();
        for (final l in presetLabels) {
          expect(presetSelected(tester, l), isFalse, reason: l);
        }
        expect(find.text('Confirm 63 × 47 × 2 cm'), findsOneWidget);

        // Typing a common size's numbers selects it.
        await tester.enterText(field('height'), '70');
        await tester.enterText(field('width'), '50');
        await tester.pump();
        expect(presetSelected(tester, '70 × 50'), isTrue);
        expect(find.text('Confirm 70 × 50 × 2 cm'), findsOneWidget);

        // Tapping a preset fills both fields and selects only it.
        await tapVisible(
            tester, find.byKey(const Key('z_size_preset_A3 · 42 × 30')));
        expect(fieldText(tester, 'height'), '42');
        expect(fieldText(tester, 'width'), '30');
        expect(presetSelected(tester, 'A3 · 42 × 30'), isTrue);
        expect(presetSelected(tester, '70 × 50'), isFalse);
        expect(find.text('Confirm 42 × 30 × 2 cm'), findsOneWidget);
      });

      testWidgets('a typed depth deselects the chip; a chip fills the depth',
          (tester) async {
        await pumpSheet(tester, size);
        expect(depthSelected(tester, 'Canvas'), isTrue);
        await tester.ensureVisible(field('depth'));
        await tester.enterText(field('depth'), '5');
        await tester.pump();
        for (final d in depthKeys) {
          expect(depthSelected(tester, d), isFalse, reason: d);
        }
        expect(find.text('Confirm 50 × 40 × 5 cm'), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('z_size_depth_Framed')));
        expect(fieldText(tester, 'depth'), '3');
        expect(depthSelected(tester, 'Framed'), isTrue);
        expect(find.text('Confirm 50 × 40 × 3 cm'), findsOneWidget);
        await tester.enterText(field('depth'), '4');
        await tester.pump();
        expect(depthSelected(tester, 'Deep canvas'), isTrue);
        expect(depthSelected(tester, 'Framed'), isFalse);
      });
    });
  }
}
