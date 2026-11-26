import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/z_image_editor_theme.dart';

/// Red size lines next to the outline: a vertical line with a rotated pill
/// on the right (height) and a horizontal one underneath (width). "≈ 50 cm"
/// for an estimate, "50 cm" when confirmed or measured. Both stay inside
/// [bounds] (the canvas), moving inwards when the outline reaches its edge.
class FrameMeasurementLines extends StatelessWidget {
  final ZImageEditorTheme theme;

  /// Bounding box of the outline on screen.
  final Rect outline;

  /// Area the lines must stay inside.
  final Size bounds;
  final String heightLabel;
  final String widthLabel;

  const FrameMeasurementLines({
    super.key,
    required this.theme,
    required this.outline,
    required this.bounds,
    required this.heightLabel,
    required this.widthLabel,
  });

  static const double _thickness = 26;

  /// Where the height line and its label are drawn for [outline] inside
  /// [bounds].
  static Rect heightLineArea(Rect outline, Size bounds) => Rect.fromLTWH(
        math.max(0, math.min(outline.right + 7, bounds.width - _thickness)),
        outline.top,
        _thickness,
        math.max(0, outline.height),
      );

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: theme.fontFamily,
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w500,
      color: theme.textColor,
      decoration: TextDecoration.none,
    );
    final vx = math.min(outline.right + 7, bounds.width - _thickness);
    final hy = math.min(outline.bottom + 11, bounds.height - _thickness);
    Widget pill(String text, {required bool vertical, required Key key}) {
      final label = Container(
        key: key,
        padding: vertical
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: theme.measurementColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(text, style: style, maxLines: 1, softWrap: false),
      );
      return vertical ? RotatedBox(quarterTurns: 3, child: label) : label;
    }

    // Natural pill length (text + padding); when the outline is shorter,
    // only the pill is shown, scaled down to fit.
    double pillLength(String text) {
      final tp = TextPainter(
        // As the Text widget will draw it (inherits the default style).
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final w = tp.width + 16;
      tp.dispose();
      return w;
    }

    Widget fitted(Widget pill, {required bool vertical}) => Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: pill),
        );

    Widget line({required bool vertical}) => Expanded(
          child: Container(
            width: vertical ? 1 : null,
            height: vertical ? null : 1,
            color: theme.measurementColor,
          ),
        );

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: math.max(0, vx),
            top: outline.top,
            width: _thickness,
            height: math.max(0, outline.height),
            child: outline.height < pillLength(heightLabel) + 8
                ? fitted(
                    pill(heightLabel,
                        vertical: true, key: const Key('z_frame_height_label')),
                    vertical: true)
                : Column(
                    key: const Key('z_frame_height_line'),
                    children: [
                      line(vertical: true),
                      const SizedBox(height: 4),
                      pill(heightLabel,
                          vertical: true,
                          key: const Key('z_frame_height_label')),
                      const SizedBox(height: 4),
                      line(vertical: true),
                    ],
                  ),
          ),
          Positioned(
            left: outline.left,
            top: math.max(0, hy),
            width: math.max(0, outline.width),
            height: _thickness,
            child: outline.width < pillLength(widthLabel) + 8
                ? fitted(
                    pill(widthLabel,
                        vertical: false, key: const Key('z_frame_width_label')),
                    vertical: false)
                : Row(
                    key: const Key('z_frame_width_line'),
                    children: [
                      line(vertical: false),
                      const SizedBox(width: 4),
                      pill(widthLabel,
                          vertical: false,
                          key: const Key('z_frame_width_label')),
                      const SizedBox(width: 4),
                      line(vertical: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
