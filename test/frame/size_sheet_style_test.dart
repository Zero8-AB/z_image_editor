import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/z_image_editor.dart';

import 'size_sheet_test.dart' show pumpSheet, tapVisible;

/// The app's form look (rose fields, falu text and selection), as the
/// Monogram app sets it.
const rose = Color(0xFFFCD6D7);
const falu = Color(0xFFB63B3B);
const charcoal = Color(0xFF282525);
const light = Color(0xFFFCFCFC);
const helper = Color(0xFF6F6767);

const roseTheme = ZImageEditorTheme(
  fontFamily: 'Jost',
  sizeFieldColor: rose,
  sizeFieldTextColor: falu,
  sizeFieldFocusColor: falu,
  sizeFieldEstimatedColor: falu,
  sizeLabelColor: charcoal,
  sizeHelperColor: helper,
  sizeOptionColor: rose,
  sizeOptionTextColor: falu,
  sizeOptionSelectedColor: falu,
  sizeOptionSelectedTextColor: light,
  sizeOptionBestFitColor: rose,
);

TextStyle styleOf(WidgetTester t, Finder f) => t.widget<Text>(f).style!;

Finder box(String name) => find.byKey(Key('z_size_box_$name'));

BoxDecoration fieldDecoration(WidgetTester t, String name) => t
    .widget<Container>(
        find.descendant(of: box(name), matching: find.byType(Container)).first)
    .decoration! as BoxDecoration;

BoxDecoration optionDecoration(WidgetTester t, Key key) => t
    .widget<Container>(find
        .descendant(of: find.byKey(key), matching: find.byType(Container))
        .first)
    .decoration! as BoxDecoration;

Color textColorIn(WidgetTester t, Key key, String text) =>
    styleOf(t, find.descendant(of: find.byKey(key), matching: find.text(text)))
        .color!;

void main() {
  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    group('size sheet style @ $s', () {
      testWidgets('headings and labels: 18 px charcoal, no "(cm)", no ×',
          (tester) async {
        await pumpSheet(tester, size, theme: roseTheme);
        for (final text in [
          'Common sizes, height × width (cm)',
          'Dimensions, including frame (cm)',
          'Height',
          'Width',
          'Depth',
        ]) {
          final st = styleOf(tester, find.text(text));
          expect(st.fontSize, 18, reason: text);
          expect(st.color, charcoal, reason: text);
          expect(st.fontFamily, 'Jost', reason: text);
        }
        expect(find.textContaining('(cm)'), findsNWidgets(2));
        expect(find.text('×'), findsNothing);
        expect(find.text('COMMON SIZES, HEIGHT × WIDTH (CM)'), findsNothing);
        final hint =
            styleOf(tester, find.byKey(const Key('z_size_depth_hint')));
        expect(hint.fontSize, 14);
        expect(hint.color, helper);
        expect(find.text('Depth: Default 2 cm · change if needed'),
            findsOneWidget);
      });

      testWidgets('fields: rose, 48 px, falu 18, 16 px apart, no idle border',
          (tester) async {
        await pumpSheet(tester, size, theme: roseTheme);
        for (final name in ['height', 'width', 'depth']) {
          expect(tester.getSize(box(name)).height, 48, reason: name);
          final d = fieldDecoration(tester, name);
          expect(d.color, rose, reason: name);
          expect(d.borderRadius, BorderRadius.circular(4));
          final b = (d.border! as Border).top;
          expect(b.width, 2, reason: name);
          expect(b.color, rose, reason: '$name: idle border is the fill');
          final st = tester
              .widget<TextField>(find.byKey(Key('z_size_field_$name')))
              .style!;
          expect(st.fontSize, 18);
          expect(st.color, falu);
        }
        final h = tester.getRect(box('height'));
        final w = tester.getRect(box('width'));
        final d = tester.getRect(box('depth'));
        expect(w.left - h.right, moreOrLessEquals(16));
        expect(d.left - w.right, moreOrLessEquals(16));
        expect(w.width, moreOrLessEquals(h.width));
        // Text starts 12 px inside the 2 px border.
        final text =
            tester.getRect(find.byKey(const Key('z_size_field_height')));
        expect(text.left - h.left, moreOrLessEquals(14));
      });

      testWidgets(
          'estimated depth: 2 px dashed falu; focus: 2 px solid falu; '
          'the field keeps its size', (tester) async {
        await pumpSheet(tester, size, theme: roseTheme);
        final paintBox = tester.widget<CustomPaint>(box('depth'));
        expect(paintBox.foregroundPainter, isNotNull);
        expect(
            tester.renderObject(box('depth')),
            paints
              ..path(color: falu, strokeWidth: 2, style: PaintingStyle.stroke));
        // Typed values have no dashes.
        expect(tester.widget<CustomPaint>(box('height')).foregroundPainter,
            isNull);
        final before = tester.getSize(box('depth'));
        await tapVisible(tester, find.byKey(const Key('z_size_field_depth')));
        expect(
            tester.widget<CustomPaint>(box('depth')).foregroundPainter, isNull);
        final b = (fieldDecoration(tester, 'depth').border! as Border).top;
        expect(b.color, falu);
        expect(b.width, 2);
        expect(b.style, BorderStyle.solid);
        expect(tester.getSize(box('depth')), before);
        await tapVisible(tester, find.byKey(const Key('z_size_field_height')));
        expect((fieldDecoration(tester, 'height').border! as Border).top.color,
            falu);
        expect((fieldDecoration(tester, 'depth').border! as Border).top.color,
            rose);
      });

      testWidgets(
          'common sizes: 48 px, Jost 16; rose / falu, selected falu / '
          'light with a rose "Best fit"; same border both ways',
          (tester) async {
        await pumpSheet(tester, size, theme: roseTheme);
        const sel = Key('z_size_preset_50 × 40');
        const other = Key('z_size_preset_40 × 30');
        expect(tester.getSize(find.byKey(sel)).height, 48);
        expect(tester.getSize(find.byKey(other)).height, 48);
        final ds = optionDecoration(tester, sel);
        final du = optionDecoration(tester, other);
        expect(ds.color, falu);
        expect(du.color, rose);
        expect(
            (ds.border! as Border).top.width, (du.border! as Border).top.width);
        expect(textColorIn(tester, sel, '50 × 40'), light);
        expect(textColorIn(tester, other, '40 × 30'), falu);
        final best = styleOf(
            tester,
            find.descendant(
                of: find.byKey(sel), matching: find.text('Best fit')));
        expect(best.color, rose);
        expect(best.fontSize, 12);
        final label = styleOf(
            tester,
            find.descendant(
                of: find.byKey(other), matching: find.text('40 × 30')));
        expect(label.fontSize, 16);
        expect(label.fontFamily, 'Jost');
        final weight = styleOf(
                tester,
                find.descendant(
                    of: find.byKey(sel), matching: find.text('50 × 40')))
            .fontWeight;
        expect(label.fontWeight, weight, reason: 'same weight in both states');
        // Picking another swaps the colours only.
        await tapVisible(tester, find.byKey(other));
        expect(optionDecoration(tester, other).color, falu);
        expect(optionDecoration(tester, sel).color, rose);
        expect(textColorIn(tester, other, '40 × 30'), light);
        // "Best fit" stays readable on the rose button.
        expect(textColorIn(tester, sel, 'Best fit'), falu);
      });

      testWidgets(
          'depth chips: pills in Jost 16, rose / falu, selected falu '
          '/ light, side by side', (tester) async {
        await pumpSheet(tester, size, theme: roseTheme);
        const canvas = Key('z_size_depth_Canvas');
        const paper = Key('z_size_depth_Paper');
        // "≈ 2" (the default) shows Canvas 2 as selected.
        expect(optionDecoration(tester, canvas).color, falu);
        expect(textColorIn(tester, canvas, 'Canvas 2'), light);
        expect(optionDecoration(tester, paper).color, rose);
        expect(textColorIn(tester, paper, 'Paper 0.1'), falu);
        expect(
            styleOf(
                    tester,
                    find.descendant(
                        of: find.byKey(paper),
                        matching: find.text('Paper 0.1')))
                .fontSize,
            16);
        expect(optionDecoration(tester, paper).borderRadius,
            BorderRadius.circular(40));
        // Pills are as wide as their label, side by side (wrapping rows),
        // never stretched across the sheet.
        final p = tester.getRect(find.byKey(paper));
        final label = tester.getRect(find.text('Paper 0.1'));
        // 16 px padding and the 1 px border on each side.
        expect(p.width, moreOrLessEquals(label.width + 34));
        final c = tester.getRect(find.byKey(canvas));
        if (p.width + 8 + c.width <= size.width - 48) {
          expect(c.top, p.top);
          expect(c.left, moreOrLessEquals(p.right + 8));
        }
        await tapVisible(tester, find.byKey(paper));
        expect(optionDecoration(tester, paper).color, falu);
        expect(optionDecoration(tester, canvas).color, rose);
      });
    });
  }

  testWidgets('package defaults stay neutral (no rose look by default)',
      (tester) async {
    const t = ZImageEditorTheme();
    expect(t.sizeFieldColor, isNot(rose));
    expect(t.sizeOptionSelectedColor, isNot(falu));
  });
}
