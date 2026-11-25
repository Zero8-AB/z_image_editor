import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/z_image_editor.dart';

import 'frame_step_design_test.dart' show designTheme;

class TipHarness {
  ZPhotoTipResult? result;
  var opened = false;
}

/// Pumps a page whose button opens the tip sheet with [showZPhotoTipSheet].
Future<TipHarness> pumpTip(
  WidgetTester tester,
  Size size, {
  EdgeInsets padding = EdgeInsets.zero,
  double textScale = 1,
}) async {
  final h = TipHarness();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding =
      FakeViewPadding(top: padding.top, bottom: padding.bottom);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () async {
            h.result = await showZPhotoTipSheet(context, theme: designTheme);
            h.opened = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    group('tip sheet @ $s', () {
      testWidgets('shows the title, the three tips and the actions',
          (tester) async {
        await pumpTip(tester, size);
        expect(find.text('Photograph your artwork'), findsOneWidget);
        for (final t in [
          'Stand slightly to the side',
          'Reflections move off the glass. Monogram straightens the photo afterwards.',
          'No lamp behind you',
          'Turn off lights that shine on the glass. Don’t use the flash.',
          'Show the whole frame',
          'Keep a little wall around it, so all four corners are found.',
          'Take photo',
          'Don’t show this again',
        ]) {
          expect(find.text(t), findsOneWidget, reason: t);
        }
        // 48 px button, 44 px checkbox row, both inside the screen.
        final take = tester.getRect(find.byKey(const Key('z_tip_take_photo')));
        expect(take.height, 48);
        final row = tester.getRect(find.byKey(const Key('z_tip_dont_show')));
        expect(row.height, greaterThanOrEqualTo(44));
        expect(row.bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Take photo closes the sheet: dontShowAgain false',
          (tester) async {
        final h = await pumpTip(tester, size);
        await tester.tap(find.byKey(const Key('z_tip_take_photo')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('z_tip_sheet')), findsNothing);
        expect(h.opened, isTrue);
        expect(h.result!.dontShowAgain, isFalse);
      });

      testWidgets('ticking "Don’t show this again" is returned',
          (tester) async {
        final h = await pumpTip(tester, size);
        final box = find.byKey(const Key('z_tip_checkbox'));
        expect(find.descendant(of: box, matching: find.byIcon(Icons.check)),
            findsNothing);
        await tester.tap(find.byKey(const Key('z_tip_dont_show')));
        await tester.pump();
        expect(find.descendant(of: box, matching: find.byIcon(Icons.check)),
            findsOneWidget);
        // A second tap unticks, a third ticks again.
        await tester.tap(find.text('Don’t show this again'));
        await tester.pump();
        expect(find.descendant(of: box, matching: find.byIcon(Icons.check)),
            findsNothing);
        await tester.tap(find.byKey(const Key('z_tip_checkbox')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('z_tip_take_photo')));
        await tester.pumpAndSettle();
        expect(h.result!.dontShowAgain, isTrue);
      });

      testWidgets('dismissing the sheet gives null (no photo)', (tester) async {
        final h = await pumpTip(tester, size);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('z_tip_sheet')), findsNothing);
        expect(h.opened, isTrue);
        expect(h.result, isNull);
      });
    });
  }

  testWidgets('safe area: content clears the home indicator', (tester) async {
    await pumpTip(tester, const Size(393, 852),
        padding: const EdgeInsets.only(top: 59, bottom: 34));
    final row = tester.getRect(find.byKey(const Key('z_tip_dont_show')));
    expect(row.bottom, lessThanOrEqualTo(852 - 34));
    final sheet = tester.getRect(find.byKey(const Key('z_tip_sheet')));
    expect(sheet.top, greaterThanOrEqualTo(59));
  });

  testWidgets('text scale 1.3 on 360 x 640: scrolls, no overflow',
      (tester) async {
    await pumpTip(tester, const Size(360, 640),
        padding: const EdgeInsets.only(top: 24, bottom: 48), textScale: 1.3);
    expect(tester.takeException(), isNull);
    // The tips scroll; the actions stay on screen.
    final scroll = tester.state<ScrollableState>(find
        .descendant(
            of: find.byKey(const Key('z_tip_scroll')),
            matching: find.byType(Scrollable))
        .first);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(tester.getRect(find.byKey(const Key('z_tip_dont_show'))).bottom,
        lessThanOrEqualTo(640 - 48));
    await tester.tap(find.byKey(const Key('z_tip_dont_show')));
    await tester.pump();
    expect(
        find.descendant(
            of: find.byKey(const Key('z_tip_checkbox')),
            matching: find.byIcon(Icons.check)),
        findsOneWidget);
  });
}
