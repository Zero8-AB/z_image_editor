import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/z_image_editor.dart';

Future<void> pumpLines(WidgetTester tester, Rect outline) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Stack(children: [
      Positioned.fill(
        child: FrameMeasurementLines(
          theme: const ZImageEditorTheme(),
          outline: outline,
          bounds: const Size(360, 640),
          heightLabel: '≈ 100 cm',
          widthLabel: '≈ 70 cm',
        ),
      ),
    ]),
  ));
}

void main() {
  testWidgets('a large outline: lines with the labels in the middle',
      (tester) async {
    await pumpLines(tester, const Rect.fromLTWH(40, 40, 260, 400));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('z_frame_width_line')), findsOneWidget);
    expect(find.byKey(const Key('z_frame_height_line')), findsOneWidget);
  });

  testWidgets('just too short for lines and label, with letter spacing',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (var w = 60.0; w < 200; w += 0.5) {
      await tester.pumpWidget(MaterialApp(
        home: DefaultTextStyle(
          style: const TextStyle(letterSpacing: 1.5),
          child: Stack(children: [
            Positioned.fill(
              child: FrameMeasurementLines(
                theme: const ZImageEditorTheme(),
                outline: Rect.fromLTWH(20, 20, w, w),
                bounds: const Size(360, 640),
                heightLabel: '≈ 50 cm',
                widthLabel: '≈ 50 cm',
              ),
            ),
          ]),
        ),
      ));
      expect(tester.takeException(), isNull, reason: 'width $w');
    }
  });

  testWidgets('an outline shorter than its label: label only, scaled down',
      (tester) async {
    await pumpLines(tester, const Rect.fromLTWH(100, 100, 40, 30));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('z_frame_width_line')), findsNothing);
    expect(find.byKey(const Key('z_frame_height_line')), findsNothing);
    expect(find.text('≈ 70 cm'), findsOneWidget);
    expect(find.text('≈ 100 cm'), findsOneWidget);
    final label = tester.getRect(find.byKey(const Key('z_frame_width_label')));
    expect(label.width, lessThanOrEqualTo(40.5));
  });
}
