import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/z_image_editor_theme.dart';
import 'sheet_parts.dart';

/// Texts of the tip sheet shown before the camera opens.
class ZPhotoTipLabels {
  final String title;
  final String sideTitle;
  final String sideBody;
  final String lampTitle;
  final String lampBody;
  final String wholeTitle;
  final String wholeBody;
  final String takePhoto;
  final String dontShowAgain;

  const ZPhotoTipLabels({
    this.title = 'Photograph your artwork',
    this.sideTitle = 'Stand slightly to the side',
    this.sideBody =
        'Reflections move off the glass. Monogram straightens the photo '
            'afterwards.',
    this.lampTitle = 'No lamp behind you',
    this.lampBody =
        'Turn off lights that shine on the glass. Don’t use the flash.',
    this.wholeTitle = 'Show the whole frame',
    this.wholeBody =
        'Keep a little wall around it, so all four corners are found.',
    this.takePhoto = 'Take photo',
    this.dontShowAgain = 'Don’t show this again',
  });
}

/// What the user chose in the tip sheet.
class ZPhotoTipResult {
  /// "Don’t show this again" was ticked when "Take photo" was tapped.
  final bool dontShowAgain;

  const ZPhotoTipResult({required this.dontShowAgain});
}

/// Shows the tip sheet. Resolves when "Take photo" is tapped, or to null
/// when the sheet is dismissed (no photo should be taken then).
Future<ZPhotoTipResult?> showZPhotoTipSheet(
  BuildContext context, {
  required ZImageEditorTheme theme,
  ZPhotoTipLabels labels = const ZPhotoTipLabels(),
}) {
  return showModalBottomSheet<ZPhotoTipResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x80000000),
    builder: (context) => ZPhotoTipSheet(
      theme: theme,
      labels: labels,
      onTakePhoto: (r) => Navigator.of(context).pop(r),
    ),
  );
}

/// "Photograph your artwork": three tips, "Take photo" and
/// "Don’t show this again".
class ZPhotoTipSheet extends StatefulWidget {
  final ZImageEditorTheme theme;
  final ZPhotoTipLabels labels;
  final ValueChanged<ZPhotoTipResult> onTakePhoto;

  const ZPhotoTipSheet({
    super.key,
    required this.theme,
    this.labels = const ZPhotoTipLabels(),
    required this.onTakePhoto,
  });

  @override
  State<ZPhotoTipSheet> createState() => _ZPhotoTipSheetState();
}

class _ZPhotoTipSheetState extends State<ZPhotoTipSheet> {
  bool _dontShow = false;

  ZImageEditorTheme get t => widget.theme;

  TextStyle _text(double size,
          {Color? color, FontWeight weight = FontWeight.normal}) =>
      TextStyle(
        fontFamily: t.fontFamily,
        fontSize: size,
        color: color ?? t.sheetTextColor,
        fontWeight: weight,
        height: 1.4,
        decoration: TextDecoration.none,
      );

  Widget _tip(Key key, _TipIcon icon, String title, String body) => Row(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child:
                CustomPaint(painter: _TipIconPainter(icon, t.sheetAccentColor)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _text(16, weight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(body, style: _text(14, color: t.sheetMutedColor)),
              ],
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final l = widget.labels;
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('z_tip_sheet'),
        decoration: BoxDecoration(
          color: t.sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        constraints: BoxConstraints(maxHeight: mq.size.height - 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.sheetBorderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            // The tips scroll on small phones; the actions stay in view.
            Flexible(
              child: SingleChildScrollView(
                key: const Key('z_tip_scroll'),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.title,
                      style: TextStyle(
                        fontFamily: t.titleFontFamily ?? t.fontFamily,
                        fontSize: 32,
                        height: 1,
                        color: t.sheetTextColor,
                        letterSpacing: 0.6,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _tip(const Key('z_tip_side'), _TipIcon.side, l.sideTitle,
                        l.sideBody),
                    const SizedBox(height: 16),
                    _tip(const Key('z_tip_lamp'), _TipIcon.lamp, l.lampTitle,
                        l.lampBody),
                    const SizedBox(height: 16),
                    _tip(const Key('z_tip_whole'), _TipIcon.whole, l.wholeTitle,
                        l.wholeBody),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24, math.max(16.0, mq.padding.bottom)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ZSheetButton(
                    key: const Key('z_tip_take_photo'),
                    theme: t,
                    label: l.takePhoto,
                    onTap: () => widget
                        .onTakePhoto(ZPhotoTipResult(dontShowAgain: _dontShow)),
                  ),
                  const SizedBox(height: 4),
                  _checkbox(l.dontShowAgain),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkbox(String label) => Semantics(
        checked: _dontShow,
        child: GestureDetector(
          key: const Key('z_tip_dont_show'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _dontShow = !_dontShow),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  key: const Key('z_tip_checkbox'),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _dontShow ? t.sheetAccentColor : t.sheetFieldColor,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: _dontShow ? t.sheetAccentColor : t.sheetMutedColor,
                      width: 1.5,
                    ),
                  ),
                  child: _dontShow
                      ? Icon(Icons.check,
                          size: 14, color: t.primaryButtonTextColor)
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child:
                      Text(label, style: _text(14, color: t.sheetMutedColor)),
                ),
              ],
            ),
          ),
        ),
      );
}

enum _TipIcon { side, lamp, whole }

/// The tips' 40 px line drawings (from the design, 1.5 px strokes).
class _TipIconPainter extends CustomPainter {
  final _TipIcon icon;
  final Color color;
  _TipIconPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40, size.height / 40);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void poly(List<double> xy) {
      final path = Path()..moveTo(xy[0], xy[1]);
      for (var i = 2; i < xy.length; i += 2) {
        path.lineTo(xy[i], xy[i + 1]);
      }
      canvas.drawPath(path, p);
    }

    switch (icon) {
      case _TipIcon.side:
        canvas.drawRect(const Rect.fromLTWH(10, 8, 18, 24), p);
        poly([4, 30, 10, 26]);
        poly([36, 30, 30, 26]);
        poly([30, 20, 36, 20]);
        poly([33, 17, 36, 20, 33, 23]);
      case _TipIcon.lamp:
        final bulb = Path()
          ..moveTo(14, 22)
          ..arcToPoint(const Offset(26, 22),
              radius: const Radius.circular(8), largeArc: true)
          ..cubicTo(24.5, 23.5, 24, 25, 24, 27)
          ..lineTo(16, 27)
          ..cubicTo(16, 25, 15.5, 23.5, 14, 22)
          ..close();
        canvas.drawPath(bulb, p);
        poly([16, 31, 24, 31]);
        poly([6, 6, 34, 34]);
      case _TipIcon.whole:
        poly([6, 12, 6, 6, 12, 6]);
        poly([28, 6, 34, 6, 34, 12]);
        poly([34, 28, 34, 34, 28, 34]);
        poly([12, 34, 6, 34, 6, 28]);
        canvas.drawRect(const Rect.fromLTWH(12, 11, 16, 18), p);
    }
  }

  @override
  bool shouldRepaint(_TipIconPainter old) =>
      old.icon != icon || old.color != color;
}
