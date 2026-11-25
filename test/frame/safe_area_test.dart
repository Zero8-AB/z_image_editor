import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/z_image_editor.dart';

import '../editor/auto_fix_test.dart' show autoTheme;
import '../helpers.dart';
import 'frame_crop_view_test.dart' show FakeDetector, rect;
import 'frame_step_design_test.dart' show designTheme;

/// A phone: size, safe-area insets (top / bottom) and side gesture insets
/// (0 with 3-button navigation).
class Phone {
  final String name;
  final Size size;
  final double top;
  final double bottom;
  final double gesture;
  const Phone(this.name, this.size, this.top, this.bottom, this.gesture);
}

const phones = [
  Phone('360x640 Android (24/48)', Size(360, 640), 24, 48, 0),
  Phone('360x640 Android gestures', Size(360, 640), 24, 24, 30),
  Phone('375x667 iPhone SE', Size(375, 667), 20, 0, 0),
  Phone('393x852 iPhone (59/34)', Size(393, 852), 59, 34, 0),
  Phone('412x915 3-button (48)', Size(412, 915), 24, 48, 0),
  Phone('430x932 iPhone Pro Max', Size(430, 932), 59, 34, 0),
];

void setPhone(WidgetTester tester, Phone p, {double textScale = 1.3}) {
  tester.view.physicalSize = p.size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: p.top, bottom: p.bottom);
  tester.view.viewPadding = FakeViewPadding(top: p.top, bottom: p.bottom);
  tester.view.systemGestureInsets =
      FakeViewPadding(left: p.gesture, right: p.gesture);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

class _Checker extends ZPhotoChecker {
  const _Checker();
  @override
  Future<ZPhotoIssue?> check(Uint8List b, List<ZFrameCandidate> c) async =>
      ZPhotoIssue.glare;
}

class _Enhancer extends ZImageEnhancer {
  @override
  String get label => 'No reflections';
  @override
  Future<Uint8List?> apply(Uint8List imageBytes) async => imageBytes;
}

/// The busiest frame step: shape label, three chips, hint banner, size and
/// reflection tools; the outer outline is the whole photo, so its handles
/// sit at the photo's edges.
Widget busyStep() => FrameCropView(
      imageBytes: testPng(w: 300, h: 300),
      detector: FakeDetector([
        rect('Artwork', 0.3),
        rect('No frame', 0.15),
        ZFrameCandidate(
          label: 'With frame',
          corners: rect('x', 0).corners,
          shape: ZFrameShape.round,
          preselected: true,
        ),
      ]),
      enhancer: _Enhancer(),
      photoChecker: const _Checker(),
      onRetake: () {},
      sizeTools: true,
      labels: const ZFrameCropLabels(title: 'Choose what to keep'),
      theme: designTheme,
      onCancel: () {},
      onContinue: (_) {},
      warp: (b, c) async => b,
    );

void main() {
  for (final p in phones) {
    group(p.name, () {
      testWidgets('frame step: inside the safe area, handles off the edges',
          (tester) async {
        setPhone(tester, p);
        await tester.runAsync(() async {
          await tester.pumpWidget(MaterialApp(home: busyStep()));
        });
        await settleAsync(tester);
        expect(tester.takeException(), isNull);
        final cancel = tester.getRect(find.byKey(const Key('z_frame_cancel')));
        final next = tester.getRect(find.byKey(const Key('z_frame_continue')));
        expect(cancel.top, greaterThanOrEqualTo(p.top));
        expect(next.top, greaterThanOrEqualTo(p.top));
        expect(find.byKey(const Key('z_hint_banner')), findsOneWidget);
        expect(find.byKey(const Key('z_frame_shape_label')), findsOneWidget);
        final reset = tester.getRect(find.byKey(const Key('z_frame_reset')));
        expect(reset.bottom, lessThanOrEqualTo(p.size.height - p.bottom));
        final margin = p.gesture + 12 > 24 ? p.gesture + 12 : 24.0;
        for (var i = 0; i < 4; i++) {
          final h = tester.getCenter(find.byKey(Key('z_frame_handle_$i')));
          expect(h.dx, greaterThanOrEqualTo(margin - 0.5), reason: 'handle $i');
          expect(h.dx, lessThanOrEqualTo(p.size.width - margin + 0.5),
              reason: 'handle $i');
        }
        // Every tool and chip is still at least 44 px tall.
        for (final k in const ['z_frame_size', 'z_frame_reset']) {
          expect(tester.getSize(find.byKey(Key(k))).height,
              greaterThanOrEqualTo(44));
        }
      });

      testWidgets('editor: header and tools inside the safe area',
          (tester) async {
        setPhone(tester, p);
        await tester.runAsync(() async {
          await tester.pumpWidget(MaterialApp(
            home: ZImageEditor(
              imageBytesList: [testPng()],
              theme: autoTheme,
              enableAutoFix: true,
              edgeToEdge: true,
              onSaveAll: (_) {},
              onCancel: () {},
            ),
          ));
        });
        await settleAsync(tester);
        expect(tester.takeException(), isNull);
        final done = tester.getRect(find.byKey(const Key('z_editor_done')));
        expect(done.top, greaterThanOrEqualTo(p.top));
        final crop = tester.getRect(find.byKey(const Key('z_editor_tab_crop')));
        expect(crop.bottom, lessThanOrEqualTo(p.size.height - p.bottom));
        // Edge to edge: transparent bars, light icons.
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
        expect(region.value.statusBarColor, const Color(0x00000000));
        expect(region.value.statusBarIconBrightness, Brightness.light);
        await tester.tap(find.byKey(const Key('z_editor_tab_adjust')));
        await settleAsync(tester, 5);
        expect(tester.takeException(), isNull);
      });

      testWidgets('tip sheet: Take photo above the home bar', (tester) async {
        setPhone(tester, p);
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showZPhotoTipSheet(context, theme: designTheme),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final take = tester.getRect(find.byKey(const Key('z_tip_take_photo')));
        expect(take.bottom, lessThanOrEqualTo(p.size.height - p.bottom));
        expect(take.top, greaterThan(p.top));
      });

      testWidgets('size sheet: Confirm above the home bar and the keyboard',
          (tester) async {
        setPhone(tester, p);
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showZArtworkSizeSheet(context,
                      theme: designTheme, estimatedAspectHW: 1.25),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        var confirm = tester.getRect(find.byKey(const Key('z_size_confirm')));
        expect(confirm.bottom, lessThanOrEqualTo(p.size.height - p.bottom));
        // Keyboard open (300 px): Confirm stays above it.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        confirm = tester.getRect(find.byKey(const Key('z_size_confirm')));
        expect(confirm.bottom, lessThanOrEqualTo(p.size.height - 300));
      });

      testWidgets('shape menu: options above the home bar', (tester) async {
        setPhone(tester, p);
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showZFrameShapeMenu(context,
                      theme: designTheme,
                      labels: const ZFrameCropLabels(),
                      current: ZFrameShape.round),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final oval =
            tester.getRect(find.byKey(const Key('z_frame_shape_oval')));
        expect(oval.bottom, lessThanOrEqualTo(p.size.height - p.bottom));
        expect(oval.height, greaterThanOrEqualTo(44));
      });
    });
  }
}
