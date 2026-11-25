import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/image_editor.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';

import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector, FakeEnhancer, rect;

ZFrameCandidate level(
  String label,
  double inset,
  ZFrameLevel level, {
  bool mat = false,
  ZFrameShape shape = ZFrameShape.rectangle,
}) =>
    ZFrameCandidate(
      label: label,
      corners: rect(label, inset).corners,
      level: level,
      matAround: mat,
      shape: shape,
    );

void main() {
  group('ZFrameEvidence.fromCandidates', () {
    test('only the artwork: no frame', () {
      final e = ZFrameEvidence.fromCandidates(
          [level('Artwork', 0.1, ZFrameLevel.artwork)]);
      expect(e, const ZFrameEvidence(hasFrame: false));
    });

    test('frame directly around the artwork: frame, no mat', () {
      final e = ZFrameEvidence.fromCandidates([
        level('Artwork', 0.2, ZFrameLevel.artwork),
        level('With frame', 0.1, ZFrameLevel.frame),
      ]);
      expect(e.hasFrame, isTrue);
      expect(e.hasMat, isFalse);
      expect(e.glassReflections, isFalse);
    });

    test('frame + light mat', () {
      final e = ZFrameEvidence.fromCandidates([
        level('Artwork', 0.3, ZFrameLevel.artwork, mat: true),
        level('No frame', 0.2, ZFrameLevel.inner),
        level('With frame', 0.1, ZFrameLevel.frame),
      ], glassReflections: true);
      expect(
          e,
          const ZFrameEvidence(
              hasFrame: true, hasMat: true, glassReflections: true));
    });

    test('a mat without a frame is not a mat', () {
      final e = ZFrameEvidence.fromCandidates(
          [level('Artwork', 0.1, ZFrameLevel.artwork, mat: true)]);
      expect(e.hasMat, isFalse);
    });

    test('without levels, two nested outlines count as a frame', () {
      expect(ZFrameEvidence.fromCandidates([rect('a', 0.1)]).hasFrame, isFalse);
      expect(
          ZFrameEvidence.fromCandidates([rect('a', 0.2), rect('b', 0.1)])
              .hasFrame,
          isTrue);
    });

    test('shape: the outermost outline, with a "Wrong?" correction', () {
      final cs = [
        level('Artwork', 0.3, ZFrameLevel.artwork),
        level('With frame', 0.1, ZFrameLevel.frame, shape: ZFrameShape.round),
      ];
      expect(ZFrameEvidence.fromCandidates(cs).shape, ZFrameShape.round);
      expect(
          ZFrameEvidence.fromCandidates(cs,
              shapeOverrides: {1: ZFrameShape.oval}).shape,
          ZFrameShape.oval);
    });
  });

  group('FrameCropResult.evidence', () {
    FrameCropResult result({
      List<ZFrameCandidate>? candidates,
      bool done = true,
      ZPhotoIssue? issue,
      bool enhanced = false,
    }) =>
        FrameCropResult(
          outputBytes: null,
          corners: const [Offset.zero, Offset.zero, Offset.zero, Offset.zero],
          candidates: candidates ??
              [
                level('Artwork', 0.2, ZFrameLevel.artwork),
                level('With frame', 0.1, ZFrameLevel.frame),
              ],
          detectionDone: done,
          photoIssue: issue,
          enhancedBytes: enhanced ? testPng() : null,
        );

    test('none before detection or without outlines', () {
      expect(result(done: false).evidence, isNull);
      expect(result(candidates: const []).evidence, isNull);
    });

    test('glass from the reflection fix or the glare hint', () {
      expect(result().evidence!.glassReflections, isFalse);
      expect(result(enhanced: true).evidence!.glassReflections, isTrue);
      expect(
          result(issue: ZPhotoIssue.glare).evidence!.glassReflections, isTrue);
      expect(result(issue: ZPhotoIssue.blurry).evidence!.glassReflections,
          isFalse);
    });
  });

  group('ZImageEditor.onFrameEvidence', () {
    Future<List<ZFrameEvidence>> next(
      WidgetTester tester, {
      required List<ZFrameCandidate> candidates,
      ZImageEnhancer? enhancer,
    }) async {
      final got = <ZFrameEvidence>[];
      await pumpEditor(
        tester,
        ZImageEditor(
          imageBytesList: [testPng(w: 300, h: 400)],
          frameDetector: FakeDetector(candidates),
          imageEnhancer: enhancer,
          enableAutoFix: false,
          onFrameEvidence: got.add,
          onSaveAll: (_) {},
          onCancel: () {},
        ),
      );
      await tester.tap(find.byKey(const Key('z_frame_continue')));
      await settleAsync(tester, 60);
      return got;
    }

    testWidgets('Next reports frame, mat and glass', (tester) async {
      final got = await next(
        tester,
        candidates: [
          level('Artwork', 0.3, ZFrameLevel.artwork, mat: true),
          level('With frame', 0.1, ZFrameLevel.frame),
        ],
        enhancer: FakeEnhancer(testPng(w: 300, h: 400)),
      );
      expect(got, [
        const ZFrameEvidence(
            hasFrame: true, hasMat: true, glassReflections: true),
      ]);
    });

    testWidgets('Next reports "no frame" for the artwork alone',
        (tester) async {
      final got = await next(
        tester,
        candidates: [level('Artwork', 0.1, ZFrameLevel.artwork)],
        enhancer: FakeEnhancer(null),
      );
      expect(got, [const ZFrameEvidence(hasFrame: false)]);
    });

    testWidgets('nothing found: no evidence', (tester) async {
      final got = await next(tester, candidates: const []);
      expect(got, isEmpty);
    });
  });
}
