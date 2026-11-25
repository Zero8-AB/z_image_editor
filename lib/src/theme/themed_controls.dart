import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'z_image_editor_theme.dart';

/// Thin line icons (1.5 px strokes on a 24-unit grid) used by the tool rows.
enum ZLineIconKind {
  reflectionsOff,
  reflections,
  rotate,
  fullPhoto,
  reset,
  crop,
  adjust,
  back,

  /// Size not confirmed yet: dashed rectangle.
  sizeEstimated,

  /// Size confirmed or measured: rectangle with a lock.
  sizeConfirmed,
  close,
  check,
  auto,
  compare,
  circle,
  oval,

  /// Photo hints: reflection (sun), blur, darkness (moon), cut-off corners.
  hintGlare,
  hintBlurry,
  hintDark,
  hintCorners,
}

/// Draws [path] dashed ([dash] on, [gap] off).
void drawDashedPath(Canvas canvas, Path path, Paint paint,
    {double dash = 3, double gap = 2}) {
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      final next = math.min(d + dash, metric.length);
      canvas.drawPath(metric.extractPath(d, next), paint);
      d = next + gap;
    }
  }
}

class ZLineIcon extends StatelessWidget {
  final ZLineIconKind kind;
  final Color color;
  final double size;

  const ZLineIcon(this.kind, {super.key, required this.color, this.size = 22});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LineIconPainter(kind, color)),
      );
}

class _LineIconPainter extends CustomPainter {
  final ZLineIconKind kind;
  final Color color;
  _LineIconPainter(this.kind, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);

    switch (kind) {
      case ZLineIconKind.reflections:
      case ZLineIconKind.reflectionsOff:
        canvas.drawCircle(const Offset(12, 12), 4, p);
        line(12, 3, 12, 5);
        line(12, 19, 12, 21);
        line(4.2, 4.2, 5.6, 5.6);
        line(18.4, 18.4, 19.8, 19.8);
        line(3, 12, 5, 12);
        line(19, 12, 21, 12);
        line(4.2, 19.8, 5.6, 18.4);
        line(18.4, 5.6, 19.8, 4.2);
        if (kind == ZLineIconKind.reflectionsOff) line(4, 20, 20, 4);
      case ZLineIconKind.rotate:
        canvas.drawPath(
          Path()
            ..addArc(
              Rect.fromCircle(center: const Offset(12, 12), radius: 8),
              math.atan2(-1, 8),
              -(2 * math.pi - (math.pi / 4 + math.atan2(1, 8))),
            ),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(20, 4)
            ..lineTo(20, 11)
            ..lineTo(13, 11),
          p,
        );
      case ZLineIconKind.fullPhoto:
        canvas.drawRect(const Rect.fromLTWH(4, 4, 16, 16), p);
      case ZLineIconKind.reset:
        canvas.drawPath(
          Path()
            ..addArc(
              Rect.fromCircle(center: const Offset(12, 12), radius: 9),
              math.pi,
              -(2 * math.pi - (math.atan2(-6.7, -6) + 2 * math.pi - math.pi)),
            ),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(3, 4)
            ..lineTo(3, 9)
            ..lineTo(8, 9),
          p,
        );
      case ZLineIconKind.crop:
        canvas.drawPath(
          Path()
            ..moveTo(6, 2)
            ..lineTo(6, 18)
            ..lineTo(22, 18)
            ..moveTo(2, 6)
            ..lineTo(18, 6)
            ..lineTo(18, 22),
          p,
        );
      case ZLineIconKind.adjust:
        line(4, 7, 14, 7);
        line(18, 7, 20, 7);
        line(4, 17, 6, 17);
        line(10, 17, 20, 17);
        canvas.drawCircle(const Offset(16, 7), 2, p);
        canvas.drawCircle(const Offset(8, 17), 2, p);
      case ZLineIconKind.back:
        canvas.drawPath(
          Path()
            ..moveTo(15, 5)
            ..lineTo(8, 12)
            ..lineTo(15, 19),
          p,
        );
      case ZLineIconKind.sizeEstimated:
        drawDashedPath(
            canvas, Path()..addRect(const Rect.fromLTWH(5, 3, 14, 18)), p);
      case ZLineIconKind.sizeConfirmed:
        canvas.drawRect(const Rect.fromLTWH(5, 3, 14, 18), p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(9, 10, 6, 5), const Radius.circular(1)),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(10, 10)
            ..lineTo(10, 8.5)
            ..arcToPoint(const Offset(14, 8.5),
                radius: const Radius.circular(2))
            ..lineTo(14, 10),
          p,
        );
      case ZLineIconKind.close:
        line(6, 6, 18, 18);
        line(18, 6, 6, 18);
      case ZLineIconKind.check:
        canvas.drawPath(
          Path()
            ..moveTo(5, 12)
            ..lineTo(10, 17)
            ..lineTo(19, 7),
          p,
        );
      case ZLineIconKind.auto:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..lineTo(13.8, 7.2)
            ..lineTo(18, 9)
            ..lineTo(13.8, 10.8)
            ..lineTo(12, 15)
            ..lineTo(10.2, 10.8)
            ..lineTo(6, 9)
            ..lineTo(10.2, 7.2)
            ..close()
            ..moveTo(18, 15)
            ..lineTo(18.8, 16.7)
            ..lineTo(20.5, 17.5)
            ..lineTo(18.8, 18.3)
            ..lineTo(18, 20)
            ..lineTo(17.2, 18.3)
            ..lineTo(15.5, 17.5)
            ..lineTo(17.2, 16.7)
            ..close(),
          p,
        );
      case ZLineIconKind.compare:
        canvas.drawPath(
          Path()
            ..moveTo(9, 7)
            ..lineTo(4, 12)
            ..lineTo(9, 17)
            ..moveTo(15, 7)
            ..lineTo(20, 12)
            ..lineTo(15, 17),
          p,
        );
      case ZLineIconKind.circle:
        canvas.drawCircle(const Offset(12, 12), 8, p);
      case ZLineIconKind.oval:
        canvas.drawOval(const Rect.fromLTWH(3, 6, 18, 12), p);
      case ZLineIconKind.hintGlare:
        for (final (a, b, c, d) in const [
          (12.0, 3.0, 12.0, 5.0),
          (12.0, 19.0, 12.0, 21.0),
          (4.2, 4.2, 5.6, 5.6),
          (18.4, 18.4, 19.8, 19.8),
          (3.0, 12.0, 5.0, 12.0),
          (19.0, 12.0, 21.0, 12.0),
          (4.2, 19.8, 5.6, 18.4),
          (18.4, 5.6, 19.8, 4.2),
        ]) {
          line(a, b, c, d);
        }
        canvas.drawCircle(const Offset(12, 12), 4, p);
      case ZLineIconKind.hintBlurry:
        canvas.drawRect(const Rect.fromLTWH(7, 5, 12, 14), p);
        line(4, 8, 4, 16);
        line(2, 10, 2, 14);
        line(22, 9, 22, 15);
      case ZLineIconKind.hintDark:
        canvas.drawPath(
            Path()
              ..moveTo(20, 14.5)
              ..arcToPoint(const Offset(9.5, 4),
                  radius: const Radius.circular(8), clockwise: false)
              ..arcToPoint(const Offset(20, 14.5),
                  radius: const Radius.circular(8.5)),
            p);
      case ZLineIconKind.hintCorners:
        line(3, 8, 3, 3);
        line(3, 3, 8, 3);
        line(16, 3, 21, 3);
        line(21, 3, 21, 8);
        line(21, 16, 21, 21);
        line(21, 21, 16, 21);
        drawDashedPath(
            canvas,
            Path()
              ..moveTo(8, 21)
              ..lineTo(1, 21),
            p);
        canvas.drawRect(const Rect.fromLTWH(7, 7, 10, 10), p);
    }
  }

  @override
  bool shouldRepaint(_LineIconPainter old) =>
      old.kind != kind || old.color != color;
}

/// Icon over a short label, 44 px tall touch target.
class ZToolButton extends StatelessWidget {
  final ZImageEditorTheme theme;
  final ZLineIconKind icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  /// Colour when [active]; defaults to the theme's toggle colour.
  final Color? activeColor;

  /// Exposes on/off state to accessibility (for toggles).
  final bool? toggled;

  const ZToolButton({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
    this.toggled,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? theme.disabledColor
        : active
            ? (activeColor ?? theme.toggleOnColor)
            : theme.textColor;
    return Semantics(
      button: true,
      toggled: toggled,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ZLineIcon(icon, color: color, size: theme.toolIconSize),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label.contains(' · ')
                      ? label.replaceFirst(' · ', '\n· ')
                      : label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: theme.text(
                    color: color,
                    fontSize: theme.toolLabelFontSize,
                    letterSpacing: 0.4,
                    fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill chip: filled when selected, outlined otherwise.
class ZChip extends StatelessWidget {
  final ZImageEditorTheme theme;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const ZChip({
    super.key,
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: math.max(theme.chipTapHeight, theme.chipHeight),
          child: Center(
            child: Container(
              height: theme.chipHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? theme.chipSelectedColor : null,
                borderRadius: BorderRadius.circular(theme.chipHeight),
                border: Border.all(
                  color: selected
                      ? theme.chipSelectedColor
                      : theme.chipBorderColor,
                ),
              ),
              child: Text(
                label,
                style: theme.text(
                  color: selected
                      ? theme.chipSelectedTextColor
                      : theme.chipTextColor,
                  fontSize: theme.chipFontSize,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The primary header action ("Next", "Done", "Save").
class ZPrimaryButton extends StatefulWidget {
  final ZImageEditorTheme theme;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const ZPrimaryButton({
    super.key,
    required this.theme,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  State<ZPrimaryButton> createState() => _ZPrimaryButtonState();
}

class _ZPrimaryButtonState extends State<ZPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: Opacity(
          opacity: enabled || widget.busy ? 1 : 0.5,
          child: Container(
            height: t.primaryButtonHeight,
            constraints: const BoxConstraints(minWidth: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  _pressed ? t.primaryButtonPressedColor : t.primaryButtonColor,
              borderRadius: BorderRadius.circular(t.primaryButtonRadius),
            ),
            child: widget.busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CupertinoActivityIndicator(
                      color: t.primaryButtonTextColor,
                    ),
                  )
                : Text(
                    widget.label,
                    style: t.text(
                      color: t.primaryButtonTextColor,
                      fontSize: t.cancelButtonColor == null ? 16 : 14,
                      fontWeight: t.cancelButtonColor == null
                          ? FontWeight.normal
                          : FontWeight.w600,
                      letterSpacing: t.cancelButtonColor == null ? 0.3 : null,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The secondary header action ("Cancel", "‹ Frame"): a filled pill or a
/// text button depending on the theme.
class ZSecondaryButton extends StatelessWidget {
  final ZImageEditorTheme theme;
  final String label;
  final VoidCallback? onPressed;
  final bool showBackChevron;

  const ZSecondaryButton({
    super.key,
    required this.theme,
    required this.label,
    required this.onPressed,
    this.showBackChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final filled = theme.cancelButtonColor;
    final color =
        filled != null ? theme.cancelButtonTextColor : theme.textColor;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBackChevron) ...[
          ZLineIcon(ZLineIconKind.back, color: color, size: 18),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: theme.text(
            color: color,
            fontSize: filled != null ? 14 : 16,
            fontWeight: filled != null ? FontWeight.w600 : FontWeight.normal,
            letterSpacing: filled != null ? null : 0.3,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1,
          child: filled != null
              ? Container(
                  height: theme.primaryButtonHeight,
                  constraints: const BoxConstraints(minWidth: 72),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: filled,
                    borderRadius:
                        BorderRadius.circular(theme.primaryButtonRadius),
                  ),
                  child: content,
                )
              : SizedBox(height: 44, child: Center(child: content)),
        ),
      ),
    );
  }
}
