import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/image_editor.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector, rect;
import 'frame_step_design_test.dart' show designTheme;

class FakeChecker extends ZPhotoChecker {
  final ZPhotoIssue? issue;
  int calls = 0;
  List<ZFrameCandidate>? seen;
  FakeChecker(this.issue);
  @override
  Future<ZPhotoIssue?> check(Uint8List bytes, List<ZFrameCandidate> c) async {
    calls++;
    seen = c;
    return issue;
  }
}

class HintHarness {
  int retakes = 0;
  FrameCropResult? result;
  late FakeChecker checker;
}

Future<HintHarness> pumpHint(
  WidgetTester tester,
  Size size,
  ZPhotoIssue? issue, {
  bool retake = true,
  FrameCropResult? previous,
  ZPhotoChecker? checker,
}) async {
  final h = HintHarness()..checker = FakeChecker(issue);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: FrameCropView(
        imageBytes: testPng(w: 300, h: 400),
        detector: FakeDetector([rect('With frame', 0.1)]),
        theme: designTheme,
        photoChecker: checker ?? h.checker,
        previous: previous,
        onRetake: retake ? () => h.retakes++ : null,
        onCancel: () {},
        onContinue: (r) => h.result = r,
        warp: (b, c) async => Uint8List.fromList([1]),
      ),
    ));
  });
  await settleAsync(tester);
  return h;
}

const copy = {
  ZPhotoIssue.glare: (
    'Strong reflection on the glass',
    'Step a little to the side and try again. Monogram straightens the photo afterwards.'
  ),
  ZPhotoIssue.blurry: (
    'The photo is a bit blurry. Hold still and try again.',
    null
  ),
  ZPhotoIssue.tooDark: (
    'It’s quite dark. Turn on a light in the room, not behind you.',
    null
  ),
  ZPhotoIssue.cornersMissing: (
    'Part of the frame is outside the photo. Step back a little.',
    null
  ),
};

void main() {
  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    group('photo hint @ $s', () {
      for (final issue in ZPhotoIssue.values) {
        testWidgets('${issue.name}: exact copy, its icon, one banner',
            (tester) async {
          final h = await pumpHint(tester, size, issue);
          expect(find.byKey(const Key('z_hint_banner')), findsOneWidget);
          expect(find.text(copy[issue]!.$1), findsOneWidget);
          final body = copy[issue]!.$2;
          if (body != null) {
            expect(find.text(body), findsOneWidget);
          } else {
            expect(find.byKey(const Key('z_hint_body')), findsNothing);
          }
          expect(find.byKey(Key('z_hint_icon_${issue.name}')), findsOneWidget);
          expect(
              tester
                  .widget<ZLineIcon>(
                      find.byKey(Key('z_hint_icon_${issue.name}')))
                  .kind,
              ZPhotoHintBanner.iconFor(issue));
          // The check ran once, after detection, with its outlines.
          expect(h.checker.calls, 1);
          expect(h.checker.seen, hasLength(1));
          // Never blocks: Next stays enabled; banner inside the screen.
          final banner = tester.getRect(find.byKey(const Key('z_hint_banner')));
          expect(banner.right, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('no issue: no banner', (tester) async {
        await pumpHint(tester, size, null);
        expect(find.byKey(const Key('z_hint_banner')), findsNothing);
      });

      testWidgets('Retake calls back and keeps the hint', (tester) async {
        final h = await pumpHint(tester, size, ZPhotoIssue.glare);
        expect(
            tester.getSize(find.byKey(const Key('z_hint_retake'))).height, 44);
        await tester.tap(find.byKey(const Key('z_hint_retake')));
        await tester.pump();
        expect(h.retakes, 1);
      });

      testWidgets('Use anyway closes the hint', (tester) async {
        final h = await pumpHint(tester, size, ZPhotoIssue.blurry);
        await tester.tap(find.byKey(const Key('z_hint_use_anyway')));
        await tester.pump();
        expect(find.byKey(const Key('z_hint_banner')), findsNothing);
        expect(h.retakes, 0);
      });

      testWidgets('the cross dismisses the hint (44 px target)',
          (tester) async {
        await pumpHint(tester, size, ZPhotoIssue.tooDark);
        expect(tester.getSize(find.byKey(const Key('z_hint_dismiss'))),
            const Size(44, 44));
        await tester.tap(find.byKey(const Key('z_hint_dismiss')));
        await tester.pump();
        expect(find.byKey(const Key('z_hint_banner')), findsNothing);
      });

      testWidgets('without onRetake there is no Retake', (tester) async {
        await pumpHint(tester, size, ZPhotoIssue.cornersMissing, retake: false);
        expect(find.byKey(const Key('z_hint_retake')), findsNothing);
        expect(find.byKey(const Key('z_hint_use_anyway')), findsOneWidget);
      });

      testWidgets('Next works with the hint shown and keeps its state',
          (tester) async {
        final h = await pumpHint(tester, size, ZPhotoIssue.glare);
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('z_frame_continue')));
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
        expect(h.result, isNotNull);
        expect(h.result!.photoIssue, ZPhotoIssue.glare);
        expect(h.result!.photoChecked, isTrue);
        expect(h.result!.hintClosed, isFalse);
      });
    });
  }

  testWidgets('reopening the step: a closed hint stays closed, no re-check',
      (tester) async {
    final checker = FakeChecker(ZPhotoIssue.glare);
    await pumpHint(
      tester,
      const Size(390, 844),
      ZPhotoIssue.glare,
      checker: checker,
      previous: const FrameCropResult(
        outputBytes: null,
        corners: ZQuadMath.fullImage,
        candidates: [],
        photoIssue: ZPhotoIssue.glare,
        photoChecked: true,
        hintClosed: true,
      ),
    );
    expect(checker.calls, 0);
    expect(find.byKey(const Key('z_hint_banner')), findsNothing);
  });

  testWidgets('a failing checker shows nothing', (tester) async {
    await pumpHint(tester, const Size(390, 844), null,
        checker: _ThrowingChecker());
    expect(find.byKey(const Key('z_hint_banner')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the editor passes the checker and Retake through',
      (tester) async {
    var retakes = 0;
    await pumpEditor(
      tester,
      ZImageEditor(
        imageBytesList: [testPng(w: 300, h: 400)],
        frameDetector: FakeDetector([rect('With frame', 0.1)]),
        photoChecker: FakeChecker(ZPhotoIssue.blurry),
        onRetake: () => retakes++,
        theme: designTheme,
        onSaveAll: (_) {},
        onCancel: () {},
      ),
    );
    expect(find.text(copy[ZPhotoIssue.blurry]!.$1), findsOneWidget);
    await tester.tap(find.byKey(const Key('z_hint_retake')));
    await tester.pump();
    expect(retakes, 1);
  });
}

class _ThrowingChecker extends ZPhotoChecker {
  @override
  Future<ZPhotoIssue?> check(Uint8List b, List<ZFrameCandidate> c) =>
      throw StateError('boom');
}
