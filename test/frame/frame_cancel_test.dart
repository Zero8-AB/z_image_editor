import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';
import 'package:z_image_editor/src/widgets/image_canvas.dart';
import 'package:z_image_editor/z_image_editor.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector, FakeEnhancer, rect;
import 'frame_step_design_test.dart' show designTheme;

const cancelKey = Key('z_frame_cancel');
const nextKey = Key('z_frame_continue');

/// A detector whose result arrives only when [complete] is called.
class PendingDetector extends ZFrameDetector {
  final completer = Completer<List<ZFrameCandidate>>();
  @override
  Future<List<ZFrameCandidate>> detect(Uint8List imageBytes) =>
      completer.future;
  void complete() => completer.complete([rect('With frame', 0.1)]);
}

/// What the editor handed back to the app.
class Delivered {
  var discards = 0;
  var cancels = 0;
  List<File>? saved;
  final sizes = <ZArtworkSize>[];
  final evidence = <ZFrameEvidence>[];
  bool get anyResult =>
      saved != null || sizes.isNotEmpty || evidence.isNotEmpty;
}

Future<Delivered> pumpCameraEditor(
  WidgetTester tester, {
  bool withDiscard = true,
  ZFrameDetector? detector,
  Size size = const Size(390, 844),
  ZFrameCropLabels labels = const ZFrameCropLabels(),
  String cancelLabel = 'Skip',
}) async {
  final d = Delivered();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: ZImageEditor(
        imageBytesList: [testPng(w: 300, h: 400)],
        frameDetector: detector ?? FakeDetector([rect('With frame', 0.1)]),
        imageEnhancer: FakeEnhancer(testPng(w: 300, h: 400)),
        frameCropLabels: labels,
        theme: designTheme,
        cancelLabel: cancelLabel,
        enableSizeTools: true,
        onRetake: () {},
        onSaveAll: (files) => d.saved = files,
        onCancel: () => d.cancels++,
        onDiscard: withDiscard ? () => d.discards++ : null,
        onArtworkSize: d.sizes.add,
        onFrameEvidence: d.evidence.add,
      ),
    ));
  });
  await settleAsync(tester);
  return d;
}

String headerLeftLabel(WidgetTester tester) => tester
    .widget<Text>(
        find.descendant(of: find.byKey(cancelKey), matching: find.byType(Text)))
    .data!;

void main() {
  testWidgets('with onDiscard the frame step shows Cancel instead of Skip',
      (tester) async {
    await pumpCameraEditor(tester);
    expect(headerLeftLabel(tester), 'Cancel');
    expect(find.text('Skip'), findsNothing);
    // Skip's function stays: Full photo + Next.
    expect(find.byKey(const Key('z_frame_full')), findsOneWidget);
  });

  testWidgets('without onDiscard the frame step keeps Skip', (tester) async {
    final d = await pumpCameraEditor(tester, withDiscard: false);
    expect(headerLeftLabel(tester), 'Skip');
    await tester.tap(find.byKey(cancelKey));
    await tester.pump();
    expect(d.cancels, 1);
  });

  testWidgets('the label comes from ZFrameCropLabels.cancelLabel',
      (tester) async {
    await pumpCameraEditor(tester,
        labels: const ZFrameCropLabels(cancelLabel: 'Avbryt'));
    expect(headerLeftLabel(tester), 'Avbryt');
  });

  testWidgets('tapping Cancel calls onDiscard, not onCancel, and no result',
      (tester) async {
    final d = await pumpCameraEditor(tester);
    await tester.tap(find.byKey(cancelKey));
    await tester.pump();
    expect(d.discards, 1);
    expect(d.cancels, 0);
    expect(d.anyResult, isFalse);
  });

  testWidgets('after Cancel, Next delivers nothing (app slow to close)',
      (tester) async {
    final d = await pumpCameraEditor(tester);
    await tester.tap(find.byKey(cancelKey));
    await tester.pump();
    await tester.tap(find.byKey(nextKey), warnIfMissed: false);
    await settleAsync(tester, 40);
    expect(d.discards, 1);
    expect(d.anyResult, isFalse);
    // Still in the frame step: Next did not move on.
    expect(find.byType(ImageCanvas), findsNothing);
  });

  testWidgets('Cancel while detection runs: its late result delivers nothing',
      (tester) async {
    final detector = PendingDetector();
    final d = await pumpCameraEditor(tester, detector: detector);
    // Detection in flight: Next is disabled, Cancel is not.
    final cancel = tester.widget<ZSecondaryButton>(find.byKey(cancelKey));
    expect(cancel.onPressed, isNotNull);
    await tester.tap(find.byKey(cancelKey));
    await tester.pump();
    expect(d.discards, 1);
    detector.complete();
    await settleAsync(tester);
    await tester.tap(find.byKey(nextKey), warnIfMissed: false);
    await settleAsync(tester, 40);
    expect(d.anyResult, isFalse);
  });

  testWidgets('a reopened frame step also cancels the whole photo',
      (tester) async {
    final d = await pumpCameraEditor(tester);
    await tester.tap(find.byKey(nextKey));
    await settleAsync(tester, 60);
    expect(find.byType(ImageCanvas), findsOneWidget);
    // Editor step: "‹ Frame" goes back to the frame step ...
    await tester.tap(find.byKey(const Key('z_editor_cancel')));
    await settleAsync(tester);
    expect(headerLeftLabel(tester), 'Cancel');
    // ... where Cancel drops the photo.
    await tester.tap(find.byKey(cancelKey));
    await tester.pump();
    expect(d.discards, 1);
    expect(d.saved, isNull);
  });

  testWidgets('Cancel is disabled while Next is applying', (tester) async {
    final warp = Completer<Uint8List>();
    var cancels = 0;
    FrameCropResult? result;
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: FrameCropView(
          imageBytes: testPng(w: 300, h: 300),
          detector: FakeDetector([rect('With frame', 0.1)]),
          theme: designTheme,
          cancelLabel: 'Cancel',
          onCancel: () => cancels++,
          onContinue: (r) => result = r,
          warp: (b, c) => warp.future,
        ),
      ));
    });
    await settleAsync(tester);
    await tester.tap(find.byKey(nextKey));
    await tester.pump();
    expect(tester.widget<ZSecondaryButton>(find.byKey(cancelKey)).onPressed,
        isNull);
    await tester.tap(find.byKey(cancelKey), warnIfMissed: false);
    await tester.pump();
    expect(cancels, 0);
    warp.complete(Uint8List.fromList([1]));
    await settleAsync(tester);
    expect(result, isNotNull);
  });

  for (final scale in const [1.0, 1.3]) {
    for (final size in const [Size(360, 640), Size(430, 932)]) {
      final s = '${size.width.toInt()}x${size.height.toInt()} @ ${scale}x';
      testWidgets('top bar Cancel · title · Next fits ($s)', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpCameraEditor(tester,
            size: size,
            labels: const ZFrameCropLabels(title: 'Choose what to keep'));
        expect(tester.takeException(), isNull);
        final cancel = tester.getRect(find.byKey(cancelKey));
        final next = tester.getRect(find.byKey(nextKey));
        final title = tester.getRect(find.text('Choose what to keep'));
        final cancelText = tester.getRect(find.descendant(
            of: find.byKey(cancelKey), matching: find.byType(Text)));
        expect(cancel.left, greaterThanOrEqualTo(0));
        expect(next.right, lessThanOrEqualTo(size.width));
        expect(cancel.height, greaterThanOrEqualTo(44));
        // Neither button covers the title, the label stays in its button.
        expect(cancel.right, lessThanOrEqualTo(title.left + 0.01));
        expect(next.left, greaterThanOrEqualTo(title.right - 0.01));
        expect(cancelText.left, greaterThanOrEqualTo(cancel.left - 0.01));
        expect(cancelText.right, lessThanOrEqualTo(cancel.right + 0.01));
        // The tool row is unchanged by Cancel: Retake still at the end.
        final retake = tester.getRect(find.byKey(const Key('z_frame_retake')));
        expect(retake.right, lessThanOrEqualTo(size.width));
      });
    }
  }
}
