import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A small PNG: grey background with a dark inner rectangle.
Uint8List testPng({int w = 300, int h = 400}) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(90, 90, 90));
  img.fillRect(im,
      x1: 30, y1: 40, x2: w - 30, y2: h - 40, color: img.ColorRgb8(20, 20, 20));
  return Uint8List.fromList(img.encodePng(im));
}

/// Lets real async work (image decoding, isolates) finish between frames.
Future<void> settleAsync(WidgetTester tester, [int rounds = 20]) async {
  await tester.runAsync(() async {
    for (var i = 0; i < rounds; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
  });
  await tester.pump();
}

/// Pumps [child] full-screen on a 390x844 phone-sized surface.
Future<void> pumpEditor(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(home: child));
  });
  await settleAsync(tester);
}

/// Drags from [from] by [by] in small steps (a single large move can be
/// swallowed by the drag slop).
Future<void> dragStepwise(WidgetTester tester, Offset from, Offset by,
    {int steps = 10}) async {
  final g = await tester.startGesture(from);
  for (var i = 0; i < steps; i++) {
    await g.moveBy(by / steps.toDouble());
    await tester.pump();
  }
  await g.up();
  await tester.pump();
}
