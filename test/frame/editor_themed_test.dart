import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';
import 'package:z_image_editor/z_image_editor.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector, rect;

/// The Monogram look as the app passes it (title, tool-row tabs).
const themed = ZImageEditorTheme(
  backgroundColor: Color(0xFF1C1A1A),
  panelColor: Color(0xFF1C1A1A),
  textColor: Color(0xFFFDFDFB),
  accentColor: Color(0xFFCE5151),
  toggleOnColor: Color(0xFFE06A6A),
  tabSelectedColor: Color(0xFFFDFDFB),
  toolRowTabs: true,
  showTitle: true,
  primaryButtonColor: Color(0xFFCE5151),
  primaryButtonTextColor: Color(0xFFFDFDFB),
  primaryButtonHeight: 44,
  cancelButtonColor: null,
  chipHeight: 40,
  chipTapHeight: 44,
  chipSelectedColor: Color(0xFFCE5151),
  chipSelectedTextColor: Color(0xFFFDFDFB),
  quadColor: Color(0xFFCE5151),
);

class Run {
  List<File>? saved;
  bool cancelled = false;
}

Future<Run> pumpThemed(WidgetTester tester, Size size) async {
  final run = Run();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: ZImageEditor(
        imageBytesList: [testPng(w: 300, h: 400)],
        frameDetector: FakeDetector([rect('With frame', 0.1)]),
        theme: themed,
        frameCropLabels: const ZFrameCropLabels(
          title: 'Choose what to keep',
          editorTitle: 'Edit photo',
        ),
        doneLabel: 'Save',
        enableAutoFix: true,
        onSaveAll: (f) => run.saved = f,
        onCancel: () => run.cancelled = true,
      ),
    ));
  });
  await settleAsync(tester);
  return run;
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('z_frame_continue')));
  await settleAsync(tester, 60);
}

void main() {
  for (final size in const [Size(360, 640), Size(390, 844)]) {
    group('themed editor @ ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('Cancel in the frame step cancels the editor',
          (tester) async {
        final run = await pumpThemed(tester, size);
        expect(find.text('Choose what to keep'), findsOneWidget);
        await tester.tap(find.byKey(const Key('z_frame_cancel')));
        await tester.pump();
        expect(run.cancelled, isTrue);
      });

      testWidgets('Next: "Edit photo", ‹ Frame and Save in the header',
          (tester) async {
        await pumpThemed(tester, size);
        await next(tester);
        expect(find.text('Edit photo'), findsOneWidget);
        final back = tester
            .widget<ZSecondaryButton>(find.byKey(const Key('z_editor_cancel')));
        expect(back.label, 'Frame');
        expect(back.showBackChevron, isTrue);
        expect(find.text('Save'), findsOneWidget);
        for (final k in const ['z_editor_cancel', 'z_editor_done']) {
          expect(tester.getSize(find.byKey(Key(k))).height,
              greaterThanOrEqualTo(44));
        }
      });

      testWidgets('‹ Frame goes back to the frame step and Next returns',
          (tester) async {
        final run = await pumpThemed(tester, size);
        await next(tester);
        await tester.tap(find.byKey(const Key('z_editor_cancel')));
        await settleAsync(tester);
        expect(find.byKey(const Key('z_frame_canvas')), findsOneWidget);
        expect(run.cancelled, isFalse);
        await next(tester);
        expect(find.text('Edit photo'), findsOneWidget);
      });

      testWidgets('Crop and Adjust tabs switch; Adjust shows its chips',
          (tester) async {
        await pumpThemed(tester, size);
        await next(tester);
        await tester.tap(find.byKey(const Key('z_editor_tab_crop')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(
            tester
                .widget<ZToolButton>(find.byKey(const Key('z_editor_tab_crop')))
                .active,
            isTrue);
        await tester.tap(find.byKey(const Key('z_editor_tab_adjust')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(
            tester
                .widget<ZToolButton>(
                    find.byKey(const Key('z_editor_tab_adjust')))
                .active,
            isTrue);
        expect(find.byKey(const Key('z_adjust_brightness')), findsOneWidget);
        expect(find.byKey(const Key('z_adjust_contrast')), findsOneWidget);
        expect(find.byKey(const Key('z_adjust_saturation')), findsOneWidget);
      });

      testWidgets('Save hands back one edited image', (tester) async {
        final run = await pumpThemed(tester, size);
        await next(tester);
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('z_editor_done')));
          for (var i = 0; i < 40 && run.saved == null; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
          }
        });
        expect(run.saved, hasLength(1));
      });
    });
  }
}
