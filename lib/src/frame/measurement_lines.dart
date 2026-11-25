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
            child: Column(
              key: const Key('z_frame_height_line'),
              children: [
                line(vertical: true),
                const SizedBox(height: 4),
                pill(heightLabel,
                    vertical: true, key: const Key('z_frame_height_label')),
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
            child: Row(
              key: const Key('z_frame_width_line'),
              children: [
                line(vertical: false),
                const SizedBox(width: 4),
                pill(widthLabel,
                    vertical: false, key: const Key('z_frame_width_label')),
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
