import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/image_editor.dart';

const vp = Size(400, 600);
const imgSize = Size(3000, 2000);

ImageEditorController loaded() {
  final c = ImageEditorController();
  c.initialize(imageBytes: Uint8List(1));
  c.setDisplaySize(vp);
  c.setImageSize(imgSize);
  return c;
}

void main() {
  setUp(() => transformationService.clearCache());

  group('initial state', () {
    test('crop rect is initialised to the fitted image', () {
      final c = loaded();
      final crop = c.state.cropRect!;
      // 3000x2000 in 400x600: 400 x 266.67 centred vertically.
      expect(crop.left, closeTo(0, 1e-9));
      expect(crop.width, closeTo(1, 1e-9));
      expect(crop.height * vp.height, closeTo(266.6667, 1e-3));
      expect(crop.top * vp.height, closeTo((600 - 266.6667) / 2, 1e-3));
    });

    test('a freshly loaded image has no changes', () {
      final c = loaded();
      expect(c.state.hasChanges, isFalse,
          reason: 'the initial fitted crop rect is not an edit');
    });

    test('fittedImageRect matches BoxFit.contain', () {
      final r = loaded().fittedImageRect!;
      expect(r.width, closeTo(400, 1e-9));
      expect(r.height, closeTo(266.6667, 1e-3));
      expect(r.center, const Offset(200, 300));
    });
  });

  group('adjustments', () {
    test('brightness, contrast, saturation are stored and count as changes',
        () {
      final c = loaded();
      c.setBrightness(30);
      c.setContrast(1.4);
      c.setSaturation(0.2);
      expect(c.state.brightness, 30);
      expect(c.state.contrast, 1.4);
      expect(c.state.saturation, 0.2);
      expect(c.state.hasChanges, isTrue);
    });
  });

  group('rotation', () {
    test('rotate90 steps through 90, 180, 270, 0 and records undo', () {
      final c = loaded();
      final seen = <double>[];
      for (var i = 0; i < 4; i++) {
        c.rotate90();
        seen.add(c.state.rotation);
      }
      expect(seen, [90, 180, 270, 0]);
      expect(c.canUndo, isTrue);
    });

    test('rotate90 keeps the image covering the crop', () {
      final c = loaded();
      c.rotate90();
      final s = c.state;
      final crop = s.cropRect!;
      final total = s.minScaleForRotation * s.scale;
      for (final p in [
        Offset(crop.left * vp.width, crop.top * vp.height),
        Offset((crop.left + crop.width) * vp.width,
            (crop.top + crop.height) * vp.height),
      ]) {
        final ip = transformationService.viewportToImageCoordinates(
          viewportPoint: p,
          viewportSize: vp,
          imageSize: imgSize,
          rotationDegrees: s.totalRotation,
          scale: total,
          panOffset: s.panOffset,
          flipHorizontal: s.flipHorizontal,
          flipVertical: s.flipVertical,
        );
        expect(ip.dx, inInclusiveRange(-0.5, imgSize.width + 0.5));
        expect(ip.dy, inInclusiveRange(-0.5, imgSize.height + 0.5));
      }
    });

    test('fine rotation within ±45° updates totalRotation and min scale', () {
      final c = loaded();
      c.setFineRotation(12);
      expect(c.state.fineRotation, 12);
      expect(c.state.totalRotation, 12);
      expect(c.state.minScaleForRotation, greaterThan(1));
      c.setFineRotation(-45);
      expect(c.state.totalRotation, -45);
      c.setFineRotation(0);
      expect(c.state.minScaleForRotation, 1);
    });

    test('small fine rotations still keep the crop covered', () {
      final c = loaded();
      for (final a in [0.2, 0.4, 0.49, -0.3]) {
        c.setFineRotation(a);
        final s = c.state;
        final crop = s.cropRect!;
        final total = s.minScaleForRotation * s.scale;
        for (final p in [
          Offset(crop.left * vp.width, crop.top * vp.height),
          Offset((crop.left + crop.width) * vp.width, crop.top * vp.height),
          Offset((crop.left + crop.width) * vp.width,
              (crop.top + crop.height) * vp.height),
          Offset(crop.left * vp.width, (crop.top + crop.height) * vp.height),
        ]) {
          final ip = transformationService.viewportToImageCoordinates(
            viewportPoint: p,
            viewportSize: vp,
            imageSize: imgSize,
            rotationDegrees: s.totalRotation,
            scale: total,
            panOffset: s.panOffset,
            flipHorizontal: false,
          );
          expect(ip.dx, inInclusiveRange(-0.5, imgSize.width + 0.5),
              reason: 'angle $a corner $p');
          expect(ip.dy, inInclusiveRange(-0.5, imgSize.height + 0.5),
              reason: 'angle $a corner $p');
        }
      }
    });

    test('tilt is clamped to ±30', () {
      final c = loaded();
      c.setTiltHorizontal(99);
      c.setTiltVertical(-99);
      expect(c.state.tiltHorizontal, 30);
      expect(c.state.tiltVertical, -30);
    });
  });

  group('flips, undo and redo', () {
    test('flips toggle and undo/redo restore them', () {
      final c = loaded();
      c.flipHorizontal();
      c.flipVertical();
      expect(c.state.flipHorizontal, isTrue);
      expect(c.state.flipVertical, isTrue);
      c.undo();
      expect(c.state.flipVertical, isFalse);
      expect(c.state.flipHorizontal, isTrue);
      c.undo();
      expect(c.state.flipHorizontal, isFalse);
      expect(c.canUndo, isFalse);
      c.redo();
      expect(c.state.flipHorizontal, isTrue);
      expect(c.canRedo, isTrue);
    });

    test('undo keeps the current tab', () {
      final c = loaded();
      c.setTab(EditorTab.crop);
      c.flipHorizontal();
      c.setTab(EditorTab.adjust);
      c.undo();
      expect(c.state.currentTab, EditorTab.adjust);
    });

    test('a new action clears redo', () {
      final c = loaded();
      c.flipHorizontal();
      c.undo();
      expect(c.canRedo, isTrue);
      c.flipVertical();
      expect(c.canRedo, isFalse);
    });

    test('history is capped at 50 steps', () {
      final c = loaded();
      for (var i = 0; i < 60; i++) {
        c.flipHorizontal();
      }
      var n = 0;
      while (c.canUndo) {
        c.undo();
        n++;
      }
      expect(n, 50);
    });
  });

  group('crop', () {
    test('setCropRect clamps a crop over the letterbox to the image', () {
      final c = loaded();
      c.setCropRect(const CropRect(left: 0, top: 0, width: 1, height: 1));
      final crop = c.state.cropRect!;
      expect(crop.top * vp.height, closeTo((600 - 266.6667) / 2, 1e-3));
      expect(crop.height * vp.height, closeTo(266.6667, 1e-3));
    });

    test('a smaller crop is kept and is a change', () {
      final c = loaded();
      final f = c.state.cropRect!;
      final smaller = CropRect(
        left: f.left + 0.1,
        top: f.top + 0.05,
        width: f.width - 0.2,
        height: f.height - 0.1,
      );
      c.setCropRect(smaller);
      expect(c.state.cropRect!.width, closeTo(smaller.width, 1e-9));
      expect(c.state.hasChanges, isTrue);
    });

    test('resetCrop restores the fitted bounds', () {
      final c = loaded();
      final f = c.state.cropRect!;
      c.setCropRect(
          CropRect(left: 0.2, top: f.top, width: 0.3, height: f.height / 2));
      c.resetCrop();
      expect(c.state.cropRect!.width, closeTo(f.width, 1e-9));
      expect(c.state.cropRect!.height, closeTo(f.height, 1e-9));
    });

    test('aspect ratio preset is stored and undoable', () {
      final c = loaded();
      c.setAspectRatioPreset(AspectRatioPreset.square);
      expect(c.state.aspectRatioPreset, AspectRatioPreset.square);
      c.undo();
      expect(c.state.aspectRatioPreset, AspectRatioPreset.free);
    });

    test('setScale clamps to 0.05…4', () {
      final c = loaded();
      c.setScale(10);
      expect(c.state.scale, 4);
      c.setScale(0);
      expect(c.state.scale, 0.05);
    });
  });

  test('reset clears every edit and history, keeps sizes', () {
    final c = loaded();
    c.setBrightness(20);
    c.rotate90();
    c.flipVertical();
    c.reset();
    final s = c.state;
    expect(s.brightness, 0);
    expect(s.rotation, 0);
    expect(s.flipVertical, isFalse);
    expect(s.imageSize, imgSize);
    expect(s.displaySize, vp);
    expect(s.cropRect, isNotNull);
    expect(c.canUndo, isFalse);
    expect(s.hasChanges, isFalse);
  });

  test('AspectRatioPreset labels and ratios', () {
    expect(AspectRatioPreset.free.ratio, isNull);
    expect(AspectRatioPreset.square.ratio, 1);
    for (final p in AspectRatioPreset.values) {
      expect(p.label, isNotEmpty);
    }
  });
}
