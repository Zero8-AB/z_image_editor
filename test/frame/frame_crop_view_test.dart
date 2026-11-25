import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';
import 'package:z_image_editor/z_image_editor.dart';

import '../helpers.dart';

class FakeDetector extends ZFrameDetector {
  final List<ZFrameCandidate> result;
  int calls = 0;
  FakeDetector(this.result);
  @override
  Future<List<ZFrameCandidate>> detect(Uint8List imageBytes) async {
    calls++;
    return result;
  }
}

class ThrowingDetector extends ZFrameDetector {
  @override
  Future<List<ZFrameCandidate>> detect(Uint8List imageBytes) async =>
      throw StateError('boom');
}

class FakeEnhancer extends ZImageEnhancer {
  final Uint8List? output;
  FakeEnhancer(this.output);
  @override
  String get label => 'No reflections';
  @override
  String get offLabel => 'Reflections shown';
  @override
  Future<Uint8List?> apply(Uint8List imageBytes) async => output;
}

ZFrameCandidate rect(String label, double inset) => ZFrameCandidate(
      label: label,
      corners: [
        Offset(inset, inset),
        Offset(1 - inset, inset),
        Offset(1 - inset, 1 - inset),
        Offset(inset, 1 - inset),
      ],
    );

final threeCandidates = [
  rect('With frame', 0.1),
  rect('With mat', 0.2),
  rect('Painting', 0.3),
];

class Harness {
  FrameCropResult? result;
  bool cancelled = false;
  List<Offset>? warpedCorners;
  Uint8List? warpedSource;
}

class SlowDetector extends ZFrameDetector {
  final completer = Completer<List<ZFrameCandidate>>();
  int calls = 0;
  @override
  Future<List<ZFrameCandidate>> detect(Uint8List imageBytes) {
    calls++;
    return completer.future;
  }
}

class SlowEnhancer extends ZImageEnhancer {
  final completer = Completer<Uint8List?>();
  @override
  String get label => 'No reflections';
  @override
  Future<Uint8List?> apply(Uint8List imageBytes) => completer.future;
}

Future<Harness> pumpFrame(
  WidgetTester tester, {
  ZFrameDetector? detector,
  ZImageEnhancer? enhancer,
  Uint8List? bytes,
  FrameCropResult? previous,
  FrameWarpFunction? warp,
}) async {
  final h = Harness();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final source = bytes ?? testPng();
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: FrameCropView(
        imageBytes: source,
        detector: detector,
        enhancer: enhancer,
        previous: previous,
        onCancel: () => h.cancelled = true,
        onContinue: (r) => h.result = r,
        warp: warp ??
            (b, c) async {
              h.warpedSource = b;
              h.warpedCorners = c;
              return Uint8List.fromList([1, 2, 3]);
            },
      ),
    ));
    // Let the image decode and the fakes complete.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
  });
  await tester.pump();
  return h;
}

Offset handle(WidgetTester tester, int i) =>
    tester.getCenter(find.byKey(Key('z_frame_handle_$i')));

void main() {
  bool selected(WidgetTester tester, String key) =>
      tester.widget<ZChip>(find.byKey(Key(key))).selected;

  testWidgets('shows the detector candidates and selects the first',
      (tester) async {
    final det = FakeDetector(threeCandidates);
    await pumpFrame(tester, detector: det);
    expect(det.calls, 1);
    expect(find.text('With frame'), findsOneWidget);
    expect(find.text('With mat'), findsOneWidget);
    expect(find.text('Painting'), findsOneWidget);
    expect(selected(tester, 'z_frame_chip_0'), isTrue);
    expect(selected(tester, 'z_frame_chip_1'), isFalse);
  });

  testWidgets('pre-selects the candidate marked preselected', (tester) async {
    await pumpFrame(tester,
        detector: FakeDetector([
          rect('Painting', 0.3),
          rect('With mat', 0.2),
          ZFrameCandidate(
            label: 'With frame',
            preselected: true,
            corners: rect('x', 0.1).corners,
          ),
        ]));
    expect(selected(tester, 'z_frame_chip_2'), isTrue);
    expect(selected(tester, 'z_frame_chip_0'), isFalse);
    // Reset returns to it, too.
    await tester.ensureVisible(find.byKey(const Key('z_frame_chip_0')));
    await tester.tap(find.byKey(const Key('z_frame_chip_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('z_frame_reset')));
    await tester.pump();
    expect(selected(tester, 'z_frame_chip_2'), isTrue);
  });

  testWidgets('never shows more than three chips', (tester) async {
    await pumpFrame(tester,
        detector: FakeDetector([...threeCandidates, rect('Extra', 0.4)]));
    expect(find.byKey(const Key('z_frame_chip_2')), findsOneWidget);
    expect(find.byKey(const Key('z_frame_chip_3')), findsNothing);
    expect(find.text('Extra'), findsNothing);
  });

  testWidgets('drops invalid (non-convex) candidates', (tester) async {
    await pumpFrame(tester,
        detector: FakeDetector([
          ZFrameCandidate(label: 'Bow tie', corners: const [
            Offset(0.1, 0.1),
            Offset(0.9, 0.9),
            Offset(0.9, 0.1),
            Offset(0.1, 0.9),
          ]),
          rect('Painting', 0.3),
        ]));
    expect(find.text('Bow tie'), findsNothing);
    expect(selected(tester, 'z_frame_chip_0'), isTrue);
    expect(find.text('Painting'), findsOneWidget);
  });

  testWidgets('tapping a chip moves the handles to that outline',
      (tester) async {
    await pumpFrame(tester, detector: FakeDetector(threeCandidates));
    final before = handle(tester, 0);
    await tester.ensureVisible(find.byKey(const Key('z_frame_chip_2')));
    await tester.tap(find.byKey(const Key('z_frame_chip_2')));
    await tester.pump();
    expect(selected(tester, 'z_frame_chip_2'), isTrue);
    final after = handle(tester, 0);
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
  });

  testWidgets('tapping the photo cycles chips, then full photo, then around',
      (tester) async {
    await pumpFrame(tester, detector: FakeDetector(threeCandidates));
    final photo = find.byKey(const Key('z_frame_photo'));
    Future<void> tapPhoto() async {
      // Tap away from the handles (photo centre).
      await tester.tapAt(tester.getCenter(photo));
      await tester.pump();
    }

    await tapPhoto();
    expect(selected(tester, 'z_frame_chip_1'), isTrue);
    await tapPhoto();
    expect(selected(tester, 'z_frame_chip_2'), isTrue);
    await tapPhoto();
    // Full photo: no chip selected, Full photo tool active.
    for (var i = 0; i < 3; i++) {
      expect(selected(tester, 'z_frame_chip_$i'), isFalse);
    }
    expect(
        tester
            .widget<ZToolButton>(find.byKey(const Key('z_frame_full')))
            .active,
        isTrue);
    await tapPhoto();
    expect(selected(tester, 'z_frame_chip_0'), isTrue);
  });

  testWidgets('dragging a corner moves it and marks the chip as edited',
      (tester) async {
    await pumpFrame(tester, detector: FakeDetector(threeCandidates));
    final start = handle(tester, 0);
    await tester.drag(
        find.byKey(const Key('z_frame_handle_0')), const Offset(20, 30));
    await tester.pump();
    final end = handle(tester, 0);
    expect(end.dx, greaterThan(start.dx + 5));
    expect(end.dy, greaterThan(start.dy + 5));
    expect(find.text('With frame · edited'), findsOneWidget);
  });

  testWidgets('shows the magnifier only while dragging', (tester) async {
    await pumpFrame(tester, detector: FakeDetector(threeCandidates));
    expect(find.byKey(const Key('z_frame_loupe')), findsNothing);
    final gesture = await tester.startGesture(handle(tester, 2));
    await gesture.moveBy(const Offset(-30, -10));
    await tester.pump();
    expect(find.byKey(const Key('z_frame_loupe')), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(find.byKey(const Key('z_frame_loupe')), findsNothing);
  });

  testWidgets('a corner cannot be dragged across another (no mirroring)',
      (tester) async {
    await pumpFrame(tester, detector: FakeDetector(threeCandidates));
    final tr = handle(tester, 1);
    // Drag TL far to the right past TR.
    await tester.drag(
        find.byKey(const Key('z_frame_handle_0')), const Offset(600, 0));
    await tester.pump();
    expect(handle(tester, 0).dx, lessThan(tr.dx));
  });

  testWidgets('Reset restores the default outline and is greyed when clean',
      (tester) async {
    await pumpFrame(tester, detector: FakeDetector(threeCandidates));
    ZToolButton reset() =>
        tester.widget<ZToolButton>(find.byKey(const Key('z_frame_reset')));
    expect(reset().onTap, isNull);
    final original = handle(tester, 3);
    await tester.drag(
        find.byKey(const Key('z_frame_handle_3')), const Offset(25, -25));
    await tester.pump();
    expect(handle(tester, 3), isNot(original));
    expect(reset().onTap, isNotNull);
    await tester.tap(find.byKey(const Key('z_frame_reset')));
    await tester.pump();
    expect(handle(tester, 3), original);
    expect(selected(tester, 'z_frame_chip_0'), isTrue);
    expect(find.text('With frame'), findsOneWidget);
  });

  testWidgets('Full photo puts the handles at the image corners',
      (tester) async {
    await pumpFrame(tester, detector: FakeDetector(threeCandidates));
    await tester.tap(find.byKey(const Key('z_frame_full')));
    await tester.pump();
    final tl = handle(tester, 0), br = handle(tester, 2);
    final canvas = tester.getRect(find.byKey(const Key('z_frame_photo')));
    // Image is fitted with 28 px padding inside the canvas.
    expect(tl.dx, greaterThanOrEqualTo(canvas.left + 27));
    expect(br.dx, lessThanOrEqualTo(canvas.right - 27));
  });

  testWidgets('Continue warps with the selected outline', (tester) async {
    final h = await pumpFrame(tester, detector: FakeDetector(threeCandidates));
    await tester.ensureVisible(find.byKey(const Key('z_frame_chip_1')));
    await tester.tap(find.byKey(const Key('z_frame_chip_1')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(h.warpedCorners, threeCandidates[1].corners);
    expect(h.result!.outputBytes, Uint8List.fromList([1, 2, 3]));
    expect(h.result!.baseCandidate, 1);
  });

  testWidgets('Continue with the full photo does not warp', (tester) async {
    final h = await pumpFrame(tester);
    expect(find.text('Drag the corners to the edges you want to keep.'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('z_frame_continue')));
    await tester.pump();
    expect(h.warpedCorners, isNull);
    expect(h.result, isNotNull);
    expect(h.result!.outputBytes, isNull);
  });

  testWidgets('Rotate turns the view and the warp applies the turn',
      (tester) async {
    final h = await pumpFrame(tester);
    final canvas = tester.getRect(find.byKey(const Key('z_frame_photo')));
    double aspect() =>
        (handle(tester, 1).dx - handle(tester, 0).dx) /
        (handle(tester, 3).dy - handle(tester, 0).dy);
    expect(aspect(), closeTo(0.75, 0.02));
    await tester.tap(find.byKey(const Key('z_frame_rotate')));
    await tester.pump();
    // The 300x400 portrait image is now shown landscape.
    expect(aspect(), closeTo(4 / 3, 0.03));
    expect(handle(tester, 1).dx, lessThanOrEqualTo(canvas.right));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    // Screen TL of a clockwise-turned image is the source's bottom-left.
    expect(h.warpedCorners!.first.dx, closeTo(0, 1e-9));
    expect(h.warpedCorners!.first.dy, closeTo(1, 1e-9));
    expect(h.result!.quarterTurns, 1);
  });

  testWidgets('detector errors fall back to manual mode', (tester) async {
    await pumpFrame(tester, detector: ThrowingDetector());
    expect(find.byKey(const Key('z_frame_chip_0')), findsNothing);
    expect(find.text('Drag the corners to the edges you want to keep.'),
        findsOneWidget);
  });

  testWidgets('Cancel calls onCancel', (tester) async {
    final h = await pumpFrame(tester);
    await tester.tap(find.byKey(const Key('z_frame_cancel')));
    expect(h.cancelled, isTrue);
  });

  group('enhancer toggle', () {
    testWidgets('is on by default and warps the enhanced image',
        (tester) async {
      final fixed = testPng(w: 300, h: 400);
      final h = await pumpFrame(tester,
          detector: FakeDetector(threeCandidates),
          enhancer: FakeEnhancer(fixed));
      expect(find.text('No reflections'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('z_frame_continue')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(identical(h.warpedSource, fixed), isTrue);
      expect(h.result!.enhanceOn, isTrue);
    });

    testWidgets('tapping it switches to the original', (tester) async {
      final original = testPng();
      final h = await pumpFrame(tester,
          bytes: original,
          detector: FakeDetector(threeCandidates),
          enhancer: FakeEnhancer(testPng()));
      await tester.tap(find.byKey(const Key('z_frame_enhance')));
      await tester.pump();
      expect(find.text('Reflections shown'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('z_frame_continue')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(identical(h.warpedSource, original), isTrue);
      expect(h.result!.enhanceOn, isFalse);
    });

    testWidgets('is hidden when there is nothing to fix', (tester) async {
      await pumpFrame(tester, enhancer: FakeEnhancer(null));
      expect(find.byKey(const Key('z_frame_enhance')), findsNothing);
    });

    testWidgets('full photo + enhancement returns the enhanced bytes',
        (tester) async {
      final fixed = testPng();
      final h = await pumpFrame(tester, enhancer: FakeEnhancer(fixed));
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      await tester.pump();
      expect(h.warpedCorners, isNull);
      expect(identical(h.result!.outputBytes, fixed), isTrue);
    });
  });

  testWidgets('reopening restores the previous outline without re-detecting',
      (tester) async {
    final det = FakeDetector(threeCandidates);
    final previous = FrameCropResult(
      outputBytes: null,
      corners: threeCandidates[2].corners,
      candidates: threeCandidates,
      baseCandidate: 2,
      edited: true,
    );
    await pumpFrame(tester, detector: det, previous: previous);
    expect(det.calls, 0);
    expect(find.text('Painting · edited'), findsOneWidget);
  });

  group('review fixes', () {
    ZPrimaryButton next(WidgetTester tester) => tester
        .widget<ZPrimaryButton>(find.byKey(const Key('z_frame_continue')));

    testWidgets('Next is disabled and busy while the detector runs',
        (tester) async {
      final det = SlowDetector();
      await pumpFrame(tester, detector: det);
      expect(next(tester).onPressed, isNull);
      expect(next(tester).busy, isTrue);
      det.completer.complete(threeCandidates);
      await settleAsync(tester, 3);
      expect(next(tester).onPressed, isNotNull);
      expect(next(tester).busy, isFalse);
    });

    testWidgets('Next is disabled while the enhancer runs', (tester) async {
      final enh = SlowEnhancer();
      await pumpFrame(tester, enhancer: enh);
      expect(next(tester).onPressed, isNull);
      enh.completer.complete(null);
      await settleAsync(tester, 3);
      expect(next(tester).onPressed, isNotNull);
    });

    testWidgets('Next stays disabled until the enhanced image is decoded',
        (tester) async {
      final enh = SlowEnhancer();
      final fixed = testPng(w: 300, h: 400);
      final h = await pumpFrame(tester,
          detector: FakeDetector(threeCandidates), enhancer: enh);
      enh.completer.complete(fixed);
      // The enhancer is done but its output is not decoded yet.
      await tester.pump();
      expect(next(tester).onPressed, isNull);
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      await tester.pump();
      expect(h.result, isNull);
      await settleAsync(tester, 5);
      expect(next(tester).onPressed, isNotNull);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('z_frame_continue')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(identical(h.warpedSource, fixed), isTrue);
    });

    testWidgets('reopened: Next waits for the cached enhanced image',
        (tester) async {
      final fixed = testPng(w: 300, h: 400);
      final h = Harness();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: FrameCropView(
          imageBytes: testPng(),
          previous: FrameCropResult(
            outputBytes: null,
            corners: threeCandidates[0].corners,
            candidates: threeCandidates,
            baseCandidate: 0,
            enhanceOn: true,
            enhancerRan: true,
            enhancedBytes: fixed,
          ),
          onCancel: () {},
          onContinue: (r) => h.result = r,
          warp: (b, c) async {
            h.warpedSource = b;
            return Uint8List.fromList([1]);
          },
        ),
      ));
      expect(next(tester).onPressed, isNull);
      await settleAsync(tester, 5);
      expect(next(tester).onPressed, isNotNull);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('z_frame_continue')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(identical(h.warpedSource, fixed), isTrue);
    });

    testWidgets('reopening re-detects when detection had not finished',
        (tester) async {
      final det = FakeDetector(threeCandidates);
      await pumpFrame(
        tester,
        detector: det,
        previous: const FrameCropResult(
          outputBytes: null,
          corners: ZQuadMath.fullImage,
          candidates: [],
          detectionDone: false,
        ),
      );
      expect(det.calls, 1);
      expect(find.text('With frame'), findsOneWidget);
    });

    testWidgets('corners are locked while Next is applying', (tester) async {
      final warpDone = Completer<Uint8List>();
      await pumpFrame(
        tester,
        detector: FakeDetector(threeCandidates),
        warp: (b, c) => warpDone.future,
      );
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      await tester.pump();
      final before = handle(tester, 0);
      await dragStepwise(tester, before, const Offset(30, 30));
      expect(handle(tester, 0), before);
      warpDone.complete(Uint8List.fromList([1]));
      await settleAsync(tester, 3);
    });
  });
}
