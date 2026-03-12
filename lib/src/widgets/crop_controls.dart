import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:z_image_editor/image_editor.dart';

/// Which ruler axis is currently active.
enum _TiltMode { straighten, vertical, horizontal }

/// Crop controls — iOS-style mode badges + ruler slider.
class CropControls extends StatefulWidget {
  final ImageEditorController controller;

  const CropControls({super.key, required this.controller});

  @override
  State<CropControls> createState() => _CropControlsState();
}

class _CropControlsState extends State<CropControls> {
  static const double _pxPerDeg = _RulerPainter._pxPerDeg;

  _TiltMode _activeMode = _TiltMode.straighten;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final angle = state.fineRotation;
        final tiltV = state.tiltVertical;
        final tiltH = state.tiltHorizontal;

        // Value and range for the currently active mode.
        final double activeValue;
        final double maxRange;
        switch (_activeMode) {
          case _TiltMode.straighten:
            activeValue = angle;
            maxRange = 45.0;
          case _TiltMode.vertical:
            activeValue = tiltV;
            maxRange = 30.0;
          case _TiltMode.horizontal:
            activeValue = tiltH;
            maxRange = 30.0;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // — badges row: straighten · vertical tilt · horizontal tilt
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ModeBadge(
                    label: '\u21ba',
                    value: angle,
                    selected: _activeMode == _TiltMode.straighten,
                    onTap: () =>
                        setState(() => _activeMode = _TiltMode.straighten),
                  ),
                  const SizedBox(width: 16),
                  _ModeBadge(
                    label: '\u2195',
                    value: tiltV,
                    selected: _activeMode == _TiltMode.vertical,
                    onTap: () =>
                        setState(() => _activeMode = _TiltMode.vertical),
                  ),
                  const SizedBox(width: 16),
                  _ModeBadge(
                    label: '\u2194',
                    value: tiltH,
                    selected: _activeMode == _TiltMode.horizontal,
                    onTap: () =>
                        setState(() => _activeMode = _TiltMode.horizontal),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // — ruler (controls active mode)
              SizedBox(
                height: 40,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    switch (_activeMode) {
                      case _TiltMode.straighten:
                        widget.controller.setFineRotation(
                          (angle - d.delta.dx / _pxPerDeg).clamp(-45.0, 45.0),
                        );
                      case _TiltMode.vertical:
                        widget.controller.setTiltVertical(
                          (tiltV - d.delta.dx / _pxPerDeg).clamp(-30.0, 30.0),
                        );
                      case _TiltMode.horizontal:
                        widget.controller.setTiltHorizontal(
                          (tiltH - d.delta.dx / _pxPerDeg).clamp(-30.0, 30.0),
                        );
                    }
                  },
                  // After lifting the finger, smoothly animate any remaining
                  // scale/pan correction so the settle feels fluid.
                  onHorizontalDragEnd: (_) =>
                      widget.controller.settleAfterRulerDrag(),
                  child: CustomPaint(
                    painter: _RulerPainter(
                      angle: activeValue,
                      maxRange: maxRange,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Circular mode badge ───────────────────────────────────────────────────────

/// Badge that shows the mode icon (label) when value is near-zero, or the
/// numeric value when adjusted. Highlights in yellow when selected and non-zero.
class _ModeBadge extends StatelessWidget {
  final String label;
  final double value;
  final bool selected;
  final VoidCallback onTap;

  const _ModeBadge({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNonZero = value.abs() > 0.05;

    final Color borderColor;
    final Color textColor;
    if (isNonZero && selected) {
      borderColor = const Color(0xFFFFCC00);
      textColor = const Color(0xFFFFCC00);
    } else if (isNonZero) {
      borderColor = Colors.white54;
      textColor = Colors.white70;
    } else if (selected) {
      borderColor = Colors.white70;
      textColor = Colors.white70;
    } else {
      borderColor = Colors.white24;
      textColor = Colors.white38;
    }

    final String displayText = isNonZero
        ? '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}'
        : label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Center(
          child: Text(
            displayText,
            style: TextStyle(
              color: textColor,
              fontSize: isNonZero ? 11 : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Ruler painter ─────────────────────────────────────────────────────────────

class _RulerPainter extends CustomPainter {
  final double angle;
  final double maxRange;
  const _RulerPainter({required this.angle, this.maxRange = 45.0});

  static const double _pxPerDeg = 5.0;
  static const double _majorEvery = 5.0;
  static const double _minorEvery = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Tick extents
    final double majorH = size.height * 0.55;
    final double minorH = size.height * 0.28;
    final double medH = size.height * 0.40;

    final tickPaint = Paint()
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    // Centre yellow line
    final centrePaint = Paint()
      ..color = const Color(0xFFFFCC00)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Clamp to hard stops so ticks never extend beyond the allowed range.
    final double visibleDeg = (size.width / 2) / _pxPerDeg + 2;
    final double startDeg =
        math.max(-maxRange, (angle - visibleDeg).floorToDouble());
    final double endDeg =
        math.min(maxRange, (angle + visibleDeg).ceilToDouble());

    for (double deg = startDeg; deg <= endDeg; deg += _minorEvery) {
      final double x = cx + (deg - angle) * _pxPerDeg;
      if (x < 0 || x > size.width) continue;

      final bool isMajor = (deg % _majorEvery).abs() < 0.01;
      final bool isMed = (deg % 5 != 0) && (deg % 5).abs() < 2.51;
      final double h = isMajor ? majorH : (isMed ? medH : minorH);

      // Fade ticks near the edges
      final double distFromCentre = (x - cx).abs() / (size.width / 2);
      final double opacity =
          (1.0 - math.pow(distFromCentre, 2)).clamp(0.15, 1.0).toDouble();

      tickPaint.color = isMajor
          ? Colors.white.withValues(alpha: opacity)
          : Colors.white54.withValues(alpha: opacity * 0.7);

      canvas.drawLine(
        Offset(x, cy - h / 2),
        Offset(x, cy + h / 2),
        tickPaint,
      );
    }

    // Fixed centre indicator line
    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, size.height * 0.72),
      centrePaint,
    );
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.angle != angle || old.maxRange != maxRange;
}
