import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/z_image_editor.dart';

void main() {
  test('formatCm / parseCm', () {
    expect(formatCm(50), '50');
    expect(formatCm(0.1), '0.1');
    expect(formatCm(42.04), '42');
    expect(parseCm('≈ 2'), 2);
    expect(parseCm('50,5'), 50.5);
    expect(parseCm(' 40 cm'), 40);
    expect(parseCm(''), isNull);
    expect(parseCm('0'), isNull);
    expect(parseCm('abc'), isNull);
  });

  test('ZArtworkSize: H × W text, exactness, aspect', () {
    const s = ZArtworkSize(heightCm: 50, widthCm: 40, depthCm: 2);
    expect(s.hwText, '50 × 40');
    expect(s.isExact, isTrue);
    expect(s.aspectHW, 1.25);
    expect(s.copyWith(source: ZSizeSource.estimated).isExact, isFalse);
    expect(s, const ZArtworkSize(heightCm: 50, widthCm: 40, depthCm: 2));
  });

  group('ZCommonSizes', () {
    test('upright art gets upright sizes, wide art wide sizes', () {
      expect(ZCommonSizes.forAspect(1.25).first.label, '40 × 30');
      expect(ZCommonSizes.forAspect(0.8).first.label, '30 × 40');
      expect(ZCommonSizes.forAspect(0.8)[4].label, 'A3 · 30 × 42');
    });

    test('best fit only when the shape matches', () {
      expect(ZCommonSizes.bestFit(1.25)!.label, '50 × 40');
      expect(ZCommonSizes.bestFit(1.33)!.label, '40 × 30');
      expect(ZCommonSizes.bestFit(0.8)!.label, '40 × 50');
      expect(ZCommonSizes.bestFit(1.43)!.label, '100 × 70');
      expect(ZCommonSizes.bestFit(0.25), isNull);
      // Square (round frames): 50 × 50 first.
      expect(ZCommonSizes.bestFit(1.0)!.label, '50 × 50');
      expect(ZCommonSizes.forAspect(1.02).first.label, '50 × 50');
      expect(ZCommonSizes.forAspect(1.25).any((s) => s.heightCm == s.widthCm),
          isFalse);
    });

    test('estimate: the common size when one has the shape', () {
      final s = ZCommonSizes.estimate(1.4);
      expect((s.heightCm, s.widthCm), (70, 50));
      expect(s.source, ZSizeSource.estimated);
      expect(s.isExact, isFalse);
      expect(ZCommonSizes.estimate(1.0).hwText, '50 × 50');
    });

    test(
        'estimate: no common size has the shape: the shape itself, as large '
        'as the typical size, in 5 cm steps', () {
      // A TV, 16 : 9 landscape and turned.
      for (final aspect in [9 / 16, 16 / 9]) {
        expect(ZCommonSizes.bestFit(aspect), isNull);
        final s = ZCommonSizes.estimate(aspect);
        expect(s.source, ZSizeSource.estimated);
        expect(s.aspectHW / aspect, closeTo(1, 0.06));
        expect(s.heightCm * s.widthCm, closeTo(50 * 40, 200));
        expect(s.heightCm % 5, 0);
        expect(s.widthCm % 5, 0);
      }
      expect(ZCommonSizes.estimate(9 / 16).hwText, '35 × 60');
      expect(ZCommonSizes.estimate(16 / 9).hwText, '60 × 35');
      // Extreme strips keep positive sides.
      expect(ZCommonSizes.estimate(1 / 400).heightCm, 5);
      expect(ZCommonSizes.estimate(400).widthCm, 5);
    });

    test('estimate: the size keeps the photo’s shape, whatever it is', () {
      for (var a = 0.2; a < 5; a *= 1.03) {
        final s = ZCommonSizes.estimate(a);
        // Within a common size's tolerance, or the 5 cm rounding.
        expect(ZCommonSizes.shapeDiff(s.aspectHW, a), lessThan(0.2),
            reason: 'aspect $a -> ${s.hwText}');
      }
    });

    test('ratio text', () {
      expect(ZCommonSizes.ratioText(1.25), 'about 5 : 4');
      expect(ZCommonSizes.ratioText(0.25), 'wide, about 1 : 4');
      expect(ZCommonSizes.ratioText(2.0), 'tall, about 2 : 1');
      expect(ZCommonSizes.ratioText(1.0), 'about 1 : 1');
    });

    test('depth presets and default', () {
      expect([for (final p in ZDepthPreset.all) '${p.label} ${formatCm(p.cm)}'],
          ['Paper 0.1', 'Canvas 2', 'Deep canvas 4', 'Framed 3']);
      expect(ZDepthPreset.defaultCm, 2);
    });
  });

  test('warpOutputSize keeps the real shape when given', () {
    // A 50 x 40 (H x W) artwork photographed from the side looks 300 wide,
    // 260 tall: the output must be 4 : 5 (W : H), not 300 x 260.
    const quad = [
      Offset(0, 0),
      Offset(300, 20),
      Offset(300, 240),
      Offset(0, 260)
    ];
    final s = ZQuadMath.warpOutputSize(quad, aspectWH: 0.8);
    expect(s.width / s.height, closeTo(0.8, 0.01));
    final tall = ZQuadMath.warpOutputSize(
        const [Offset(0, 0), Offset(100, 0), Offset(100, 400), Offset(0, 400)],
        aspectWH: 0.5);
    expect(tall, const Size(200, 400));
    final capped = ZQuadMath.warpOutputSize(quad, aspectWH: 0.8, maxSide: 100);
    expect(capped.height, 100);
    expect(capped.width, 80);
  });
}
