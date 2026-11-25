import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/src/widgets/image_canvas.dart';
import 'package:z_image_editor/image_editor.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector, rect;

void main() {
  testWidgets('without detector or flag the editor opens as before',
      (tester) async {
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng()],
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    expect(find.byKey(const Key('z_frame_canvas')), findsNothing);
    expect(find.byType(ImageCanvas), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Frame'), findsNothing);
  });

  testWidgets('with a detector the frame step comes first', (tester) async {
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng()],
        frameDetector: FakeDetector([rect('With frame', 0.1)]),
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    expect(find.byKey(const Key('z_frame_canvas')), findsOneWidget);
    expect(find.byType(ImageCanvas), findsNothing);
    expect(find.text('With frame'), findsOneWidget);
  });

  testWidgets(
      'startWithFrameCrop: false keeps the old flow even with a detector',
      (tester) async {
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng()],
        frameDetector: FakeDetector([rect('With frame', 0.1)]),
        startWithFrameCrop: false,
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    expect(find.byKey(const Key('z_frame_canvas')), findsNothing);
  });

  testWidgets('Next warps, continues in the editor, and Frame goes back',
      (tester) async {
    List<File>? saved;
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng(w: 300, h: 400)],
        frameDetector: FakeDetector([rect('With frame', 0.1)]),
        onSaveAll: (files) => saved = files,
        onCancel: () {},
      ),
    );
    await tester.tap(find.byKey(const Key('z_frame_continue')));
    await settleAsync(tester, 60);
    expect(find.byKey(const Key('z_frame_canvas')), findsNothing);
    final canvas = tester.widget<ImageCanvas>(find.byType(ImageCanvas));
    expect(canvas.imageBytes, isNotNull);
    expect(canvas.imageFile, isNull);
    // The warped JPEG is 80% of 300x400.
    expect(canvas.imageBytes!.sublist(0, 2), [0xFF, 0xD8]);

    // Back to the frame step keeps the chosen outline.
    await tester.tap(find.byKey(const Key('z_editor_cancel')));
    await settleAsync(tester);
    expect(find.byKey(const Key('z_frame_canvas')), findsOneWidget);
    // Cancel from a reopened frame step returns to the editor.
    await tester.tap(find.byKey(const Key('z_frame_cancel')));
    await settleAsync(tester);
    expect(find.byType(ImageCanvas), findsOneWidget);

    // Done without further edits hands back the warped image unchanged.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('z_editor_done')));
      for (var i = 0; i < 20 && saved == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    expect(saved, hasLength(1));
    final out = await tester.runAsync(() => saved!.first.readAsBytes());
    expect(out, canvas.imageBytes);
  });

  testWidgets('Cancel in the first frame step cancels the editor',
      (tester) async {
    var cancelled = false;
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng()],
        startWithFrameCrop: true,
        onSaveAll: (_) {},
        onCancel: () => cancelled = true,
      ),
    );
    await tester.tap(find.byKey(const Key('z_frame_cancel')));
    expect(cancelled, isTrue);
  });

  testWidgets('Full photo continues with the original bytes', (tester) async {
    final original = testPng();
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [original],
        startWithFrameCrop: true,
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    await tester.tap(find.byKey(const Key('z_frame_continue')));
    await settleAsync(tester);
    final canvas = tester.widget<ImageCanvas>(find.byType(ImageCanvas));
    expect(identical(canvas.imageBytes, original), isTrue);
  });

  testWidgets('themed tool-row tabs switch tabs', (tester) async {
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng()],
        theme: const ZImageEditorTheme(toolRowTabs: true, showTitle: true),
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    expect(find.byKey(const Key('z_editor_tab_crop')), findsOneWidget);
    await tester.tap(find.byKey(const Key('z_editor_tab_crop')));
    await settleAsync(tester, 5);
    final adjust = find.byKey(const Key('z_editor_tab_adjust'));
    await tester.tap(adjust);
    await settleAsync(tester, 5);
    expect(find.text('Adjust'), findsWidgets);
  });

  testWidgets('an unreadable file shows an error with Cancel', (tester) async {
    var cancelled = false;
    await pumpEditor(
      tester,
      ZImageEditor(
        imageFiles: [File('/nonexistent/z_image_editor_test.jpg')],
        startWithFrameCrop: true,
        onSaveAll: (_) {},
        onCancel: () => cancelled = true,
      ),
    );
    expect(find.byKey(const Key('z_frame_load_error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('z_frame_error_cancel')));
    expect(cancelled, isTrue);
  });

  testWidgets(
      'back to Frame + Next without changes keeps the edits; '
      'a new outline keeps the colour adjustments', (tester) async {
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng(w: 300, h: 400)],
        frameDetector:
            FakeDetector([rect('With frame', 0.1), rect('Painting', 0.25)]),
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    await tester.tap(find.byKey(const Key('z_frame_continue')));
    await settleAsync(tester, 60);
    ImageEditorController c() =>
        tester.widget<ImageCanvas>(find.byType(ImageCanvas)).controller;
    c().setBrightness(30);
    c().flipHorizontal();
    await tester.pump();

    // Unchanged quad: everything kept.
    await tester.tap(find.byKey(const Key('z_editor_cancel')));
    await settleAsync(tester);
    await tester.tap(find.byKey(const Key('z_frame_continue')));
    await settleAsync(tester, 60);
    expect(c().state.brightness, 30);
    expect(c().state.flipHorizontal, isTrue);

    // Another outline: geometry resets, adjustments stay.
    await tester.tap(find.byKey(const Key('z_editor_cancel')));
    await settleAsync(tester);
    await tester.ensureVisible(find.byKey(const Key('z_frame_chip_1')));
    await tester.tap(find.byKey(const Key('z_frame_chip_1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('z_frame_continue')));
    await settleAsync(tester, 60);
    expect(c().state.brightness, 30);
    expect(c().state.flipHorizontal, isFalse);
  });
}
