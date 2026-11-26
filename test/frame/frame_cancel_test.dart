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
  OnDiscardHost host = OnDiscardHost.count,
  int images = 1,
}) async {
  final d = Delivered();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final open = ValueNotifier(true);
  void onDiscard(BuildContext context) {
    d.discards++;
    switch (host) {
      case OnDiscardHost.count:
        break;
      case OnDiscardHost.close:
        open.value = false;
      case OnDiscardHost.confirmThenKeep:
        // "Discard photo?" and the user backs out: the editor stays open.
        showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Discard photo?'),
            actions: [
              TextButton(
                key: keepPhotoKey,
                onPressed: () => Navigator.pop(c),
                child: const Text('Keep'),
              ),
            ],
          ),
        );
    }
  }

  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: open,
        builder: (context, isOpen, _) => !isOpen
            ? const SizedBox(key: closedKey)
            : ZImageEditor(
                imageBytesList: [
                  for (var i = 0; i < images; i++) testPng(w: 300, h: 400)
                ],
                frameDetector:
                    detector ?? FakeDetector([rect('With frame', 0.1)]),
                imageEnhancer: FakeEnhancer(testPng(w: 300, h: 400)),
                frameCropLabels: labels,
                theme: designTheme,
                cancelLabel: cancelLabel,
                enableSizeTools: true,
                onRetake: () {},
                onSaveAll: (files) => d.saved = files,
                onCancel: () => d.cancels++,
                onDiscard: withDiscard ? () => onDiscard(context) : null,
                onArtworkSize: d.sizes.add,
                onFrameEvidence: d.evidence.add,
              ),
      ),
    ));
  });
  await settleAsync(tester);
  return d;
}

/// What the app does in onDiscard.
enum OnDiscardHost {
  /// Only counts the call.
  count,

  /// Closes the editor.
  close,

  /// Asks "Discard photo?"; the user taps Keep (the editor stays open).
  confirmThenKeep,
}

const keepPhotoKey = Key('test_keep_photo');
const closedKey = Key('test_editor_closed');

/// Cancel, then Keep in the app's "Discard photo?" dialog.
Future<void> cancelThenKeep(WidgetTester tester) async {
  await tester.tap(find.byKey(cancelKey));
  await tester.pumpAndSettle();
  expect(find.text('Discard photo?'), findsOneWidget);
  await tester.tap(find.byKey(keepPhotoKey));
  await tester.pumpAndSettle();
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

  testWidgets('the app closes the editor on Cancel: nothing is delivered',
      (tester) async {
    final d = await pumpCameraEditor(tester, host: OnDiscardHost.close);
    await tester.tap(find.byKey(cancelKey));
    await tester.pump();
    // The editor is gone: no Next to tap.
    expect(find.byKey(nextKey), findsNothing);
    await settleAsync(tester, 40);
    expect(d.discards, 1);
    expect(d.anyResult, isFalse);
    expect(find.byKey(closedKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel while detection runs: its late result delivers nothing',
      (tester) async {
    final detector = PendingDetector();
    final d = await pumpCameraEditor(tester,
        detector: detector, host: OnDiscardHost.close);
    // Detection in flight: Next is disabled, Cancel is not.
    final cancel = tester.widget<ZSecondaryButton>(find.byKey(cancelKey));
    expect(cancel.onPressed, isNotNull);
    await tester.tap(find.byKey(cancelKey));
    await tester.pump();
    expect(d.discards, 1);
    detector.complete();
    await settleAsync(tester);
    // The editor is gone: no Next to tap.
    expect(find.byKey(nextKey), findsNothing);
    await settleAsync(tester, 40);
    expect(d.anyResult, isFalse);
    expect(tester.takeException(), isNull);
  });

  group('the app asks "Discard photo?" and the user backs out', () {
    testWidgets('a second Cancel calls onDiscard again', (tester) async {
      final d =
          await pumpCameraEditor(tester, host: OnDiscardHost.confirmThenKeep);
      await cancelThenKeep(tester);
      expect(d.discards, 1);
      await cancelThenKeep(tester);
      expect(d.discards, 2);
      expect(d.cancels, 0);
      expect(d.anyResult, isFalse);
    });

    testWidgets('Next still works and delivers, and so does Save',
        (tester) async {
      final d =
          await pumpCameraEditor(tester, host: OnDiscardHost.confirmThenKeep);
      await cancelThenKeep(tester);
      await tester.tap(find.byKey(nextKey));
      await settleAsync(tester, 60);
      expect(find.byType(ImageCanvas), findsOneWidget);
      expect(d.sizes, hasLength(1));
      expect(d.evidence, hasLength(1));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('z_editor_done')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settleAsync(tester, 40);
      expect(d.saved, hasLength(1));
    });

    testWidgets('with several images, the next image still works',
        (tester) async {
      final d = await pumpCameraEditor(tester,
          images: 2, host: OnDiscardHost.confirmThenKeep);
      await cancelThenKeep(tester);
      await tester.tap(find.byKey(nextKey));
      await settleAsync(tester, 60);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('z_editor_done')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settleAsync(tester, 40);
      // Image 2's frame step: Cancel, Keep, Next, Save.
      await cancelThenKeep(tester);
      expect(d.discards, 2);
      await tester.tap(find.byKey(nextKey));
      await settleAsync(tester, 60);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('z_editor_done')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settleAsync(tester, 40);
      expect(d.saved, hasLength(2));
    });
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
