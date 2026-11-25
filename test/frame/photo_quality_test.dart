import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:z_image_editor/z_image_editor.dart';

/// Fixtures: tool/make_photo_quality_fixtures.dart. A 512 x 384 photo of a
/// framed artwork; the frame spans x 136..376, y 32..352.
const _dir = 'test/fixtures/photo_quality';

ZFrameCandidate quad(double l, double t, double r, double b,
        [String label = 'With frame']) =>
    ZFrameCandidate(label: label, corners: [
      Offset(l, t),
      Offset(r, t),
      Offset(r, b),
      Offset(l, b),
    ]);

/// The detector's outlines for the fixture photos.
final framed = [
  quad(136 / 512, 32 / 384, 376 / 512, 352 / 384),
  quad(172 / 512, 70 / 384, 340 / 512, 314 / 384, 'Artwork'),
];

/// Frame moved 170 px left: its left edge is outside the photo.
final cutOff = [
  quad(0, 32 / 384, 206 / 512, 352 / 384),
  quad(2 / 512, 70 / 384, 170 / 512, 314 / 384, 'Artwork'),
];

ZPhotoMetrics measure(String name, {List<ZFrameCandidate>? candidates}) {
  final im = img.decodeJpg(File('$_dir/$name.jpg').readAsBytesSync())!;
  final rgba =
      im.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
  return ZPhotoQuality.measureRgba(rgba, im.width, im.height,
      region: ZPhotoQuality.artworkRegion(candidates ?? framed));
}

ZPhotoIssue? classify(String name, {List<ZFrameCandidate>? candidates}) =>
    ZPhotoQuality.classify(measure(name, candidates: candidates),
        candidates: candidates ?? framed);

void main() {
  group('classifiers on fixtures', () {
    test('a good photo gets no hint', () {
      expect(classify('good'), isNull);
    });

    test('a flat, calm painting is not "blurry" (the frame is sharp)', () {
      final m = measure('flat_painting');
      expect(ZPhotoQuality.isBlurry(m), isFalse);
      expect(classify('flat_painting'), isNull);
    });

    test('a white painting is not glare (nothing clipped)', () {
      expect(ZPhotoQuality.isGlare(measure('white_painting')), isFalse);
      expect(classify('white_painting'), isNull);
    });

    test('glare: clipped, colourless blob on the glass', () {
      final m = measure('glare');
      expect(m.glareFraction, greaterThan(ZPhotoQuality.glareMinFraction));
      expect(classify('glare'), ZPhotoIssue.glare);
    });

    test('blurry: low Laplacian variance and no strong edge', () {
      final m = measure('blurry');
      expect(m.laplacianVariance, lessThan(ZPhotoQuality.blurVariance));
      expect(measure('good').laplacianVariance,
          greaterThan(ZPhotoQuality.blurVariance * 10));
      expect(classify('blurry'), ZPhotoIssue.blurry);
    });

    test('too dark (and not also called blurry)', () {
      final m = measure('dark');
      expect(ZPhotoQuality.isTooDark(m), isTrue);
      expect(ZPhotoQuality.isBlurry(m), isFalse);
      expect(classify('dark'), ZPhotoIssue.tooDark);
    });

    test('corners missing: the outer outline touches the edge', () {
      expect(classify('corners_missing', candidates: cutOff),
          ZPhotoIssue.cornersMissing);
      expect(ZPhotoQuality.cornersMissing(framed), isFalse);
      // No outline, or the whole photo, says nothing about the frame.
      expect(ZPhotoQuality.cornersMissing(const []), isFalse);
      expect(ZPhotoQuality.cornersMissing([quad(0, 0, 1, 1)]), isFalse);
    });
  });

  group('one hint at a time, in order', () {
    const glare = ZPhotoMetrics(
        meanLuma: 30,
        p95Luma: 100,
        glareFraction: 0.05,
        laplacianVariance: 1,
        laplacianP995: 1);
    test('glare beats corners, darkness and blur', () {
      expect(
          ZPhotoQuality.classify(glare, candidates: cutOff), ZPhotoIssue.glare);
    });
    test('corners beat darkness', () {
      final dark = ZPhotoMetrics(
          meanLuma: glare.meanLuma,
          p95Luma: glare.p95Luma,
          glareFraction: 0,
          laplacianVariance: 1,
          laplacianP995: 1);
      expect(ZPhotoQuality.classify(dark, candidates: cutOff),
          ZPhotoIssue.cornersMissing);
      expect(ZPhotoQuality.classify(dark), ZPhotoIssue.tooDark);
    });
    test('an overexposed (mostly clipped) photo is not glare', () {
      const blown = ZPhotoMetrics(
          meanLuma: 240,
          p95Luma: 255,
          glareFraction: 0.8,
          laplacianVariance: 500,
          laplacianP995: 100);
      expect(ZPhotoQuality.classify(blown), isNull);
    });
  });

  test('glare region: outermost outline, else the middle of the photo', () {
    expect(ZPhotoQuality.artworkRegion(const []),
        const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9));
    final r = ZPhotoQuality.artworkRegion(framed);
    expect(r.left, closeTo(136 / 512, 1e-9));
    expect(r.bottom, closeTo(352 / 384, 1e-9));
  });

  testWidgets('check() decodes the photo and returns the hint', (tester) async {
    await tester.runAsync(() async {
      Future<ZPhotoIssue?> run(String n, [List<ZFrameCandidate>? c]) =>
          const ZPhotoQuality()
              .check(File('$_dir/$n.jpg').readAsBytesSync(), c ?? framed);
      expect(await run('good'), isNull);
      expect(await run('glare'), ZPhotoIssue.glare);
      expect(await run('blurry'), ZPhotoIssue.blurry);
      expect(await run('dark'), ZPhotoIssue.tooDark);
      expect(await run('corners_missing', cutOff), ZPhotoIssue.cornersMissing);
    });
  });

  testWidgets('undecodable bytes: only the outline can still say something',
      (tester) async {
    await tester.runAsync(() async {
      const q = ZPhotoQuality();
      expect(await q.check(Uint8List(3), cutOff), ZPhotoIssue.cornersMissing);
      expect(await q.check(Uint8List(3), framed), isNull);
    });
  });
}
