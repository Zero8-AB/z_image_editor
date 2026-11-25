import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';
import 'package:z_image_editor/z_image_editor.dart';

import 'round_frame_test.dart' show pumpRound, roundLevels, shapeText;

const phones = [
  Size(360, 640),
  Size(375, 667),
  Size(390, 844),
  Size(412, 915),
  Size(430, 932),
];

Finder chip(int i) => find.byKey(Key('z_frame_chip_$i'));

/// The visible pill of chip [i] (inside its 44 px tap area).
Rect chipPill(WidgetTester t, int i) => t.getRect(
    find.descendant(of: chip(i), matching: find.byType(Container)).first);

const toolKeys = [
  'z_frame_size',
  'z_frame_rotate',
  'z_frame_full',
  'z_frame_reset'
];

Map<String, Rect> barRects(WidgetTester t) => {
      for (var i = 0; i < 3; i++) 'chip $i': t.getRect(chip(i)),
      for (var i = 0; i < 3; i++) 'chip pill $i': chipPill(t, i),
      for (final k in toolKeys) k: t.getRect(find.byKey(Key(k))),
      for (final k in toolKeys)
        '$k icon': t.getRect(find.descendant(
            of: find.byKey(Key(k)), matching: find.byType(ZLineIcon))),
    };

Future<void> setTextScale(WidgetTester tester, double scale) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  for (final scale in const [1.0, 1.3]) {
    for (final size in phones) {
      final s = '${size.width.toInt()}x${size.height.toInt()} @ ${scale}x';
      testWidgets('shape pill and chips never overlap ($s)', (tester) async {
        await setTextScale(tester, scale);
        await pumpRound(tester, size, roundLevels, sizeTools: true);
        expect(tester.takeException(), isNull);
        final label =
            tester.getRect(find.byKey(const Key('z_frame_shape_label')));
        final pill =
            tester.getRect(find.byKey(const Key('z_frame_shape_pill')));
        expect(label.height, greaterThanOrEqualTo(44));
        for (var i = 0; i < 3; i++) {
          final tap = tester.getRect(chip(i));
          final p = chipPill(tester, i);
          // Neither the visible pills nor the tap areas touch.
          expect(pill.overlaps(p), isFalse, reason: 'pill vs chip $i');
          expect(label.overlaps(tap), isFalse, reason: 'tap areas, chip $i');
          expect(p.top - pill.bottom, greaterThanOrEqualTo(8));
        }
        // Everything stays above the tool row and on screen.
        final tools = tester.getRect(find.byKey(const Key('z_frame_rotate')));
        expect(tester.getRect(chip(0)).bottom, lessThanOrEqualTo(tools.top));
        expect(pill.left, greaterThanOrEqualTo(0));
        expect(pill.right, lessThanOrEqualTo(size.width));
        // Tapping the chip under the pill selects it (hit-test goes to the
        // chip, not the pill).
        await tester.tap(chip(0));
        await tester.pump();
        expect(shapeText(tester), 'Rectangle');
      });
    }
  }

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    group('Wrong? responds every time @ $s', () {
      Future<void> openMenuOnFirstTap(
          WidgetTester tester, Finder target) async {
        await tester.tap(target);
        await tester.pump();
        // Only the sheet's own slide-in, no extra pumps or settling.
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const Key('z_frame_shape_menu')), findsOneWidget);
      }

      Future<void> pick(WidgetTester tester, ZFrameShape s) async {
        await tester.tap(find.byKey(Key('z_frame_shape_${s.name}')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('z_frame_shape_menu')), findsNothing);
      }

      testWidgets('Wrong? → pick → Wrong? again opens on the first tap',
          (tester) async {
        await pumpRound(tester, size, roundLevels, sizeTools: true);
        final wrong = find.byKey(const Key('z_frame_shape_wrong'));
        await openMenuOnFirstTap(tester, wrong);
        await pick(tester, ZFrameShape.rectangle);
        expect(shapeText(tester), 'Rectangle');
        await openMenuOnFirstTap(tester, wrong);
        await pick(tester, ZFrameShape.oval);
        expect(shapeText(tester), 'Oval frame found');
        // A tap on the label text (not on "Wrong?") opens it too.
        await openMenuOnFirstTap(
            tester, find.byKey(const Key('z_frame_shape_text')));
        await pick(tester, ZFrameShape.round);
        expect(shapeText(tester), 'Round frame found');
      });

      testWidgets('after confirming the size, Wrong? opens on the first tap',
          (tester) async {
        await pumpRound(tester, size, roundLevels, sizeTools: true);
        await tester.tap(find.byKey(const Key('z_frame_size')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('z_size_confirm')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('z_size_sheet')), findsNothing);
        await openMenuOnFirstTap(
            tester, find.byKey(const Key('z_frame_shape_wrong')));
        await pick(tester, ZFrameShape.oval);
        await openMenuOnFirstTap(
            tester, find.byKey(const Key('z_frame_shape_wrong')));
      });

      testWidgets('a tap while the last menu still slides away opens it',
          (tester) async {
        await pumpRound(tester, size, roundLevels, sizeTools: true);
        final wrong = find.byKey(const Key('z_frame_shape_wrong'));
        await openMenuOnFirstTap(tester, wrong);
        await tester.tap(find.byKey(const Key('z_frame_shape_oval')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(wrong, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('z_frame_shape_menu')), findsOneWidget);
        expect(shapeText(tester), 'Oval frame found');
      });
    });

    group('bottom bar stays put @ $s', () {
      testWidgets('selecting chips and changing shapes moves no chip or tool',
          (tester) async {
        await pumpRound(tester, size, roundLevels, sizeTools: true);
        final before = barRects(tester);
        for (final i in [0, 1, 2, 0]) {
          await tester.tap(chip(i));
          await tester.pump();
          final after = barRects(tester);
          for (final k in before.keys) {
            expect(after[k], before[k], reason: '$k after chip $i');
          }
        }
      });

      testWidgets(
          '"≈ 50 × 50 cm · Check" fits in two lines; confirming the size '
          'moves no other button', (tester) async {
        await pumpRound(tester, size, roundLevels, sizeTools: true);
        expect(tester.takeException(), isNull);
        final label = find.descendant(
            of: find.byKey(const Key('z_frame_size')),
            matching: find.byType(Text));
        expect(tester.widget<Text>(label).data, '≈ 50 × 50 cm\n· Check');
        final button = tester.getRect(find.byKey(const Key('z_frame_size')));
        final text = tester.getRect(label);
        expect(text.top, greaterThanOrEqualTo(button.top));
        expect(text.bottom, lessThanOrEqualTo(button.bottom + 0.01));
        final before = barRects(tester);
        // Icons on one line.
        final iconTops = {
          for (final k in toolKeys) before['$k icon']!.top,
        };
        expect(iconTops, hasLength(1));
        await tester.tap(find.byKey(const Key('z_frame_size')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('z_size_confirm')));
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(label).data, '50 × 50 cm');
        final after = barRects(tester);
        for (final k in before.keys) {
          expect(after[k], before[k], reason: k);
        }
      });
    });
  }
}
