import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/image_editor.dart';
import 'package:z_image_editor/src/widgets/image_canvas.dart';

import '../helpers.dart';

ImageEditorController controllerOf(WidgetTester tester) =>
    tester.widget<ImageCanvas>(find.byType(ImageCanvas)).controller;

/// Viewport-pixel → global position of a crop corner.
Offset cropCorner(WidgetTester tester, Alignment a) {
  final box = tester.getRect(find.byType(CropOverlay));
  final c = controllerOf(tester).state.cropRect!;
  final x = c.left + (a.x + 1) / 2 * c.width;
  final y = c.top + (a.y + 1) / 2 * c.height;
  return Offset(box.left + x * box.width, box.top + y * box.height);
}

Future<void> openCropTab(WidgetTester tester) async {
  await tester.tap(find.text('Crop'));
  await settleAsync(tester, 5);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  Future<void> pumpPlain(WidgetTester tester,
      {void Function(List<File>)? onSave, int w = 300, int h = 200}) {
    return pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng(w: w, h: h)],
        onSaveAll: onSave ?? (_) {},
        onCancel: () {},
      ),
    );
  }

  testWidgets('Done without edits returns the original bytes unchanged',
      (tester) async {
    List<File>? saved;
    final input = testPng(w: 300, h: 200);
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [input],
        onSaveAll: (f) => saved = f,
        onCancel: () {},
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Done'));
      for (var i = 0; i < 40 && saved == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    expect(saved, hasLength(1));
    final out = await tester.runAsync(() => saved!.first.readAsBytes());
    expect(out, input);
    expect(saved!.first.path, endsWith('.png'));
  });

  testWidgets('Done without edits never returns the caller\'s own File',
      (tester) async {
    final input = testPng(w: 300, h: 200);
    final dir = await tester
        .runAsync(() => Directory.systemTemp.createTemp('z_image_editor_test'));
    final original = File('${dir!.path}/photo.jpeg');
    await tester.runAsync(() => original.writeAsBytes(input));
    List<File>? saved;
    await pumpEditor(
      tester,
      ZImageEditor(
        imageFiles: [original],
        onSaveAll: (f) => saved = f,
        onCancel: () {},
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Done'));
      for (var i = 0; i < 40 && saved == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    final out = saved!.single;
    expect(out.path, isNot(original.path));
    // Extension from the content (PNG), not the misleading original name.
    expect(out.path, endsWith('.png'));
    expect(out.path, isNot(endsWith('.tmp')));
    expect(await tester.runAsync(() => out.readAsBytes()), input);
  });

  testWidgets('dragging the top-left crop handle inward shrinks the crop',
      (tester) async {
    await pumpPlain(tester);
    await openCropTab(tester);
    final before = controllerOf(tester).state.cropRect!;
    final start = cropCorner(tester, Alignment.topLeft);
    await dragStepwise(tester, start, const Offset(40, 30));
    await tester.pump();
    final after = controllerOf(tester).state.cropRect!;
    expect(after.left, greaterThan(before.left));
    expect(after.top, greaterThan(before.top));
    // Known quirk (not changed here): the overlay keeps a 16 px inset from
    // the screen edges, so on a full-width image the first handle drag also
    // pulls the opposite edge in by up to 16 px.
    final vpW = controllerOf(tester).state.displaySize!.width;
    expect((before.left + before.width - after.left - after.width) * vpW,
        inInclusiveRange(-1e-6, 16 + 1e-6));
  });

  testWidgets('a crop handle cannot be dragged past the image edge',
      (tester) async {
    await pumpPlain(tester);
    await openCropTab(tester);
    final fitted = controllerOf(tester).fittedImageRect!;
    final vp = controllerOf(tester).state.displaySize!;
    final start = cropCorner(tester, Alignment.bottomRight);
    await dragStepwise(tester, start, const Offset(300, 400));
    await tester.pump();
    final c = controllerOf(tester).state.cropRect!;
    expect(
        (c.top + c.height) * vp.height, lessThanOrEqualTo(fitted.bottom + 0.5));
    expect(
        (c.left + c.width) * vp.width, lessThanOrEqualTo(fitted.right + 0.5));
  });

  testWidgets('after a crop the box snaps to fill the viewport when idle',
      (tester) async {
    await pumpPlain(tester);
    await openCropTab(tester);
    await dragStepwise(
        tester, cropCorner(tester, Alignment.topLeft), const Offset(80, 40));
    await tester.pump();
    final scaleBefore = controllerOf(tester).state.scale;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controllerOf(tester).state.scale, greaterThan(scaleBefore));
  });

  testWidgets('Reset in the crop toolbar undoes rotation and flips',
      (tester) async {
    await pumpPlain(tester);
    await openCropTab(tester);
    final c = controllerOf(tester);
    c.rotate90();
    c.flipHorizontal();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Reset').hitTestable().first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.state.rotation, 0);
    expect(c.state.flipHorizontal, isFalse);
  });

  testWidgets('switching tabs keeps the crop', (tester) async {
    await pumpPlain(tester);
    await openCropTab(tester);
    await dragStepwise(
        tester, cropCorner(tester, Alignment.topLeft), const Offset(40, 30));
    await tester.pump();
    final crop = controllerOf(tester).state.cropRect!;
    await tester.tap(find.text('Adjust'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controllerOf(tester).state.currentTab, EditorTab.adjust);
    expect(controllerOf(tester).state.cropRect!.left, closeTo(crop.left, 1e-9));
  });

  testWidgets('labels are configurable', (tester) async {
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng()],
        cancelLabel: 'Avbryt',
        doneLabel: 'Klar',
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    expect(find.text('Avbryt'), findsOneWidget);
    expect(find.text('Klar'), findsOneWidget);
  });

  testWidgets('multi-image sessions show Next and a counter', (tester) async {
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng(), testPng()],
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('hiding tabs hides the tab bar', (tester) async {
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng()],
        showCropTab: false,
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    expect(find.text('Crop'), findsNothing);
    expect(controllerOf(tester).state.currentTab, EditorTab.adjust);
  });
}
