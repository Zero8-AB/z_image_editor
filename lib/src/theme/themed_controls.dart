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

  /// Retake the photo: a camera.
  camera,

  /// Change a value shown on the photo (the size): a pen.
  edit,
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
      case ZLineIconKind.camera:
        canvas.drawPath(
          Path()
            ..moveTo(3, 8)
            ..lineTo(7, 8)
            ..lineTo(9, 5)
            ..lineTo(15, 5)
            ..lineTo(17, 8)
            ..lineTo(21, 8)
            ..lineTo(21, 19)
            ..lineTo(3, 19)
            ..close(),
          p,
        );
        canvas.drawCircle(const Offset(12, 13), 3.5, p);
      case ZLineIconKind.edit:
        canvas.drawPath(
          Path()
            ..moveTo(4, 20)
            ..lineTo(4, 16)
            ..lineTo(15, 5)
            ..lineTo(19, 9)
            ..lineTo(8, 20)
            ..close(),
          p,
        );
        line(12.5, 7.5, 16.5, 11.5);
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

  /// Lines reserved for the label, whatever it says now (see [build]).
  final int labelLines;

  const ZToolButton({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
    this.toggled,
    this.labelLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? theme.disabledColor
        : active
            ? (activeColor ?? theme.toggleOnColor)
            : theme.textColor;
    final style = theme.text(
      color: color,
      fontSize: theme.toolLabelFontSize,
      letterSpacing: 0.4,
      fontWeight: active ? FontWeight.w500 : FontWeight.normal,
    );
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
          // The icon sits at the same height in every button, and the label
          // always gets two lines: a one-line and a two-line label ("≈ 50 ×
          // 50 cm · Check"), or a label that changes, never moves the
          // icons. A label too large for its room scales down.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ZLineIcon(icon, color: color, size: theme.toolIconSize),
              const SizedBox(height: 4),
              SizedBox(
                height: toolLabelHeight(theme, labelLines),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: ZSteadyWeightText(
                    label.contains(' · ')
                        ? label.replaceFirst(' · ', '\n· ')
                        : label,
                    style: style,
                    maxLines: labelLines,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Room for a [lines]-line label at text scale 1 (a larger text scale
  /// scales the label down to fit instead of growing the row).
  static double toolLabelHeight(ZImageEditorTheme theme, int lines) =>
      (theme.toolLabelFontSize * 1.45 * lines).ceilToDouble();
}

/// Small pill on top of the photo: an icon (a spinner while [busy]) and a
/// one-line label that ellipsizes when there is no room. Dark and
/// see-through (the panel colour), or filled with the accent colour when
/// [filled]. The pill is about 30 px tall inside a tap area of at least
/// 44 px.
class ZPhotoPill extends StatelessWidget {
  final ZImageEditorTheme theme;
  final ZLineIconKind icon;
  final String label;

  /// Shown instead of [label] when there is no room for all of it (e.g.
  /// the size without "· Check"); accessibility always gets [label].
  final String? shortLabel;
  final VoidCallback? onTap;

  /// Icon and label in the theme's toggle colour (e.g. a confirmed size).
  final bool active;

  /// Filled with the accent colour (a toggle that is on).
  final bool filled;

  /// Shows a small spinner in place of the icon.
  final bool busy;

  /// Exposes on/off state to accessibility (for toggles).
  final bool? toggled;

  const ZPhotoPill({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.shortLabel,
    this.active = false,
    this.filled = false,
    this.busy = false,
    this.toggled,
  });

  static const double _fontSize = 13;
  static const double _iconSize = 16;
  static const double _iconGap = 6;
  static const double _padX = 12;
  static const double _padY = 4;

  /// Smallest tap area (and the pill's smallest width).
  static const double minTapSize = 44;

  /// Height of the visible pill at text scale 1.
  static const double pillHeight = 30;

  static TextStyle _style(ZImageEditorTheme theme, Color color) => theme
      .text(color: color, fontSize: _fontSize, fontWeight: FontWeight.w500)
      .copyWith(height: 18 / _fontSize);

  /// The size the pill takes for [label] when it has all the room it wants
  /// (tap area included), at the current text scale.
  static Size sizeFor(
      BuildContext context, ZImageEditorTheme theme, String label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: DefaultTextStyle.of(context)
            .style
            .merge(_style(theme, theme.textColor)),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final size = Size(
      math.max(minTapSize,
          (tp.width + _iconSize + _iconGap + _padX * 2).ceilToDouble() + 1),
      math.max(minTapSize, math.max(pillHeight, tp.height + _padY * 2)),
    );
    tp.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final color = filled
        ? theme.onAccentColor
        : onTap == null
            ? theme.disabledColor
            : active
                ? theme.toggleOnColor
                : theme.textColor;
    return Semantics(
      button: true,
      toggled: toggled,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        // Opaque also when disabled: a tap on the pill never reaches the
        // photo underneath.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) => _pill(
            color,
            shortLabel != null &&
                    constraints.maxWidth < sizeFor(context, theme, label).width
                ? shortLabel!
                : label,
          ),
        ),
      ),
    );
  }

  Widget _pill(Color color, String shown) => ConstrainedBox(
        constraints:
            const BoxConstraints(minWidth: minTapSize, minHeight: minTapSize),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: pillHeight),
            padding:
                const EdgeInsets.symmetric(horizontal: _padX, vertical: _padY),
            decoration: BoxDecoration(
              color: filled
                  ? theme.accentColor
                  : theme.panelColor.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: _iconSize,
                    height: _iconSize,
                    child: CupertinoActivityIndicator(
                        radius: _iconSize / 2 - 1, color: color),
                  )
                else
                  ZLineIcon(icon, color: color, size: _iconSize),
                const SizedBox(width: _iconGap),
                Flexible(
                  child: Text(
                    shown,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: _style(theme, color),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Text whose width does not change between normal and medium weight: it
/// reserves the wider of the two, so a selected (w500) label never pushes
/// its neighbours. One [Text] widget, so finders see one label.
class ZSteadyWeightText extends StatelessWidget {
  final String data;
  final TextStyle style;
  final int? maxLines;
  final TextAlign textAlign;

  const ZSteadyWeightText(
    this.data, {
    super.key,
    required this.style,
    this.maxLines,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    double widthOf(FontWeight w) {
      final tp = TextPainter(
        text: TextSpan(text: data, style: base.copyWith(fontWeight: w)),
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        textScaler: scaler,
        maxLines: maxLines,
        textAlign: textAlign,
      )..layout();
      final w0 = tp.width;
      tp.dispose();
      return w0;
    }

    final reserved = math.max(
      widthOf(FontWeight.normal),
      widthOf(FontWeight.w500),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: reserved.ceilToDouble()),
      child: Text(
        data,
        style: style,
        maxLines: maxLines,
        textAlign: textAlign,
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
              // Same width selected or not: the row never shifts.
              child: ZSteadyWeightText(
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
