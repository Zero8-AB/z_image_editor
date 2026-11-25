import 'package:flutter/material.dart';

import '../theme/z_image_editor_theme.dart';
import 'frame_detector.dart';

/// Small pill above the chips: "◯ Round frame found · Wrong?". A tap
/// anywhere on it opens [showZFrameShapeMenu] (44 px tall tap area). There are no shape buttons: the shape comes
/// from the detector and this is only the way to correct it.
class ZFrameShapeLabel extends StatelessWidget {
  final ZImageEditorTheme theme;
  final ZFrameCropLabels labels;
  final ZFrameShape shape;
  final VoidCallback? onWrong;

  const ZFrameShapeLabel({
    super.key,
    required this.theme,
    required this.labels,
    required this.shape,
    required this.onWrong,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final text = switch (shape) {
      ZFrameShape.round => labels.roundFoundLabel,
      ZFrameShape.oval => labels.ovalFoundLabel,
      ZFrameShape.rectangle => labels.rectangleShapeLabel,
    };
    // The whole pill is one button: its text changes with the shape
    // ("Round frame found" → "Rectangle"), which moved "Wrong?" sideways,
    // so a second tap where "Wrong?" used to be hit nothing. Any tap on the
    // pill opens the menu now, on the first tap.
    return Center(
      child: Semantics(
        button: true,
        enabled: onWrong != null,
        label: '$text. ${labels.wrongShapeLabel}',
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('z_frame_shape_label'),
          behavior: HitTestBehavior.opaque,
          onTap: onWrong,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Container(
                key: const Key('z_frame_shape_pill'),
                padding: const EdgeInsets.only(left: 14),
                decoration: BoxDecoration(
                  color: t.textColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ZShapeIcon(shape: shape, color: t.toggleOnColor, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        key: const Key('z_frame_shape_text'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.text(fontSize: 14),
                      ),
                    ),
                    Container(
                      key: const Key('z_frame_shape_wrong'),
                      // The 32 px pill; the 44 px tap area is the whole
                      // label around it.
                      height: 32,
                      constraints: const BoxConstraints(minWidth: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      child: Text(
                        labels.wrongShapeLabel,
                        maxLines: 1,
                        style: t
                            .text(color: t.mutedTextColor, fontSize: 13)
                            .copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Line icon for a shape: circle, ellipse or rectangle.
class ZShapeIcon extends StatelessWidget {
  final ZFrameShape shape;
  final Color color;
  final double size;

  const ZShapeIcon({
    super.key,
    required this.shape,
    required this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _ShapeIconPainter(shape, color),
      );
}

class _ShapeIconPainter extends CustomPainter {
  final ZFrameShape shape;
  final Color color;
  _ShapeIconPainter(this.shape, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * size.width / 24;
    final s = size.width / 24;
    switch (shape) {
      case ZFrameShape.round:
        canvas.drawCircle(Offset(12 * s, 12 * s), 8 * s, p);
      case ZFrameShape.oval:
        canvas.drawOval(Rect.fromLTWH(6 * s, 3 * s, 12 * s, 18 * s), p);
      case ZFrameShape.rectangle:
        canvas.drawRect(Rect.fromLTWH(5 * s, 3 * s, 14 * s, 18 * s), p);
    }
  }

  @override
  bool shouldRepaint(_ShapeIconPainter old) =>
      old.shape != shape || old.color != color;
}

/// Bottom sheet with Rectangle / Round / Oval; resolves to the chosen shape
/// or null when dismissed.
Future<ZFrameShape?> showZFrameShapeMenu(
  BuildContext context, {
  required ZImageEditorTheme theme,
  required ZFrameCropLabels labels,
  required ZFrameShape current,
}) {
  return showModalBottomSheet<ZFrameShape>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x80000000),
    builder: (context) => ZFrameShapeMenu(
      theme: theme,
      labels: labels,
      current: current,
      onPick: (s) => Navigator.of(context).pop(s),
    ),
  );
}

/// The shape menu's content (see [showZFrameShapeMenu]).
class ZFrameShapeMenu extends StatelessWidget {
  final ZImageEditorTheme theme;
  final ZFrameCropLabels labels;
  final ZFrameShape current;
  final ValueChanged<ZFrameShape> onPick;

  const ZFrameShapeMenu({
    super.key,
    required this.theme,
    required this.labels,
    required this.current,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    Widget option(ZFrameShape s, String label) {
      final selected = s == current;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          key: Key('z_frame_shape_${s.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onPick(s),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                ZShapeIcon(shape: s, color: t.sheetTextColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: t.text(color: t.sheetTextColor, fontSize: 16),
                  ),
                ),
                if (selected)
                  Icon(Icons.check, color: t.sheetAccentColor, size: 22),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('z_frame_shape_menu'),
        decoration: BoxDecoration(
          color: t.sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        padding: EdgeInsets.only(bottom: 8 + bottom),
        child: SingleChildScrollView(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Text(
                  labels.shapeMenuTitle,
                  style: TextStyle(
                    fontFamily: t.titleFontFamily ?? t.fontFamily,
                    fontSize: 24,
                    color: t.sheetTextColor,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              option(ZFrameShape.rectangle, labels.shapeRectangle),
              option(ZFrameShape.round, labels.shapeRound),
              option(ZFrameShape.oval, labels.shapeOval),
            ],
          ),
        ),
      ),
    );
  }
}
