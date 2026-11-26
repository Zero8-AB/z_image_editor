import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/image_editor_controller.dart';
import '../models/adjust_tab_settings.dart';
import '../models/image_editor_state.dart';
import '../theme/themed_controls.dart';
import '../theme/z_image_editor_theme.dart';
import 'editor_ruler_painter.dart';

/// Texts of the Adjust tab in the themed look, including "Auto".
class ZAutoFixLabels {
  final String auto;
  final String brightness;
  final String contrast;
  final String colour;

  /// No longer shown: Auto never turns itself on, so the compare always
  /// shows [compare].
  @Deprecated('Auto never turns itself on; [compare] is always shown.')
  final String compareHazy;
  final String compare;
  final String before;
  final String after;

  const ZAutoFixLabels({
    this.auto = 'Auto',
    this.brightness = 'Brightness',
    this.contrast = 'Contrast',
    this.colour = 'Colour',
    @Deprecated('Auto never turns itself on.') this.compareHazy =
        'Drag to compare. Auto was turned on because the photo looked hazy.',
    this.compare = 'Drag to compare.',
    this.before = 'Before',
    this.after = 'After',
  });
}

/// What the Adjust tab shows below the photo.
enum ZAdjustPanel { auto, brightness, contrast, saturation }

/// Adjust tab in the themed look: a chip row "Auto · Brightness ·
/// Contrast · Colour" and, for the sliders, the ruler; for Auto the compare
/// hint. Auto is a toggle: it starts off; one tap turns it on (or off
/// again).
class ThemedAdjustControls extends StatefulWidget {
  final ZImageEditorTheme theme;
  final ImageEditorController controller;
  final AdjustTabSettings settings;
  final ZAutoFixLabels labels;

  /// The Auto fix for this photo (null: none, no Auto chip).
  final List<double>? autoLevels;

  final ZAdjustPanel panel;
  final ValueChanged<ZAdjustPanel> onPanel;

  /// The user turned Auto on (true) or off (false).
  final ValueChanged<bool>? onAutoChanged;

  const ThemedAdjustControls({
    super.key,
    required this.theme,
    required this.controller,
    this.settings = const AdjustTabSettings(),
    this.labels = const ZAutoFixLabels(),
    this.autoLevels,
    required this.panel,
    required this.onPanel,
    this.onAutoChanged,
  });

  @override
  State<ThemedAdjustControls> createState() => _ThemedAdjustControlsState();
}

class _ThemedAdjustControlsState extends State<ThemedAdjustControls> {
  int? _lastTick;

  ZImageEditorTheme get t => widget.theme;

  double _angle(ImageEditorState s, ZAdjustPanel p) => switch (p) {
        ZAdjustPanel.brightness => s.brightness * 45.0 / 100.0,
        ZAdjustPanel.contrast => (s.contrast - 1.0) * 45.0,
        ZAdjustPanel.saturation => (s.saturation - 1.0) * 45.0,
        ZAdjustPanel.auto => 0,
      };

  void _drag(double dx, ImageEditorState s, ZAdjustPanel p) {
    final delta = dx / EditorRulerPainter.pxPerDeg;
    final tick = (_angle(s, p) - delta).round();
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.selectionClick();
    }
    final c = widget.controller;
    switch (p) {
      case ZAdjustPanel.brightness:
        c.setBrightness(
            (s.brightness - delta * 100.0 / 45.0).clamp(-100.0, 100.0));
      case ZAdjustPanel.contrast:
        c.setContrast((s.contrast - delta / 45.0).clamp(0.0, 2.0));
      case ZAdjustPanel.saturation:
        c.setSaturation((s.saturation - delta / 45.0).clamp(0.0, 2.0));
      case ZAdjustPanel.auto:
        break;
    }
  }

  void _tapAuto(ImageEditorState s) {
    final levels = widget.autoLevels;
    if (levels == null) return;
    final turnOn = s.autoLevels == null;
    widget.controller.setAutoLevels(turnOn ? levels : null);
    widget.onAutoChanged?.call(turnOn);
    widget.onPanel(ZAdjustPanel.auto);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.labels;
    final st = widget.settings;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final s = widget.controller.state;
        final hasAuto = widget.autoLevels != null;
        var panel = widget.panel;
        if (panel == ZAdjustPanel.auto && !hasAuto) {
          panel = st.showBrightness
              ? ZAdjustPanel.brightness
              : st.showContrast
                  ? ZAdjustPanel.contrast
                  : ZAdjustPanel.saturation;
        }
        final chips = <Widget>[
          if (hasAuto)
            _AutoChip(
              key: const Key('z_adjust_auto'),
              theme: t,
              label: l.auto,
              on: s.autoLevels != null,
              onTap: () => _tapAuto(s),
            ),
          if (st.showBrightness)
            ZChip(
              key: const Key('z_adjust_brightness'),
              theme: t,
              label: l.brightness,
              selected: panel == ZAdjustPanel.brightness,
              onTap: () => widget.onPanel(ZAdjustPanel.brightness),
            ),
          if (st.showContrast)
            ZChip(
              key: const Key('z_adjust_contrast'),
              theme: t,
              label: l.contrast,
              selected: panel == ZAdjustPanel.contrast,
              onTap: () => widget.onPanel(ZAdjustPanel.contrast),
            ),
          if (st.showSaturation)
            ZChip(
              key: const Key('z_adjust_saturation'),
              theme: t,
              label: l.colour,
              selected: panel == ZAdjustPanel.saturation,
              onTap: () => widget.onPanel(ZAdjustPanel.saturation),
            ),
        ];

        final Widget top;
        if (panel == ZAdjustPanel.auto) {
          top = s.autoLevels == null
              ? const SizedBox.shrink()
              : Center(
                  child: Text(
                    l.compare,
                    key: const Key('z_adjust_compare_hint'),
                    textAlign: TextAlign.center,
                    style: t.text(color: t.mutedTextColor, fontSize: 13),
                  ),
                );
        } else {
          top = GestureDetector(
            key: const Key('z_adjust_ruler'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => widget.controller.beginGesture(),
            onHorizontalDragUpdate: (d) =>
                _drag(d.delta.dx, widget.controller.state, panel),
            onDoubleTap: () {
              widget.controller.beginGesture();
              switch (panel) {
                case ZAdjustPanel.brightness:
                  widget.controller.setBrightness(0);
                case ZAdjustPanel.contrast:
                  widget.controller.setContrast(1);
                case ZAdjustPanel.saturation:
                  widget.controller.setSaturation(1);
                case ZAdjustPanel.auto:
                  break;
              }
            },
            child: CustomPaint(
              painter: EditorRulerPainter(
                accentColor: t.accentColor,
                angle: _angle(s, panel),
              ),
              child: const SizedBox.expand(),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 40, child: top),
              const SizedBox(height: 8),
              SingleChildScrollView(
                key: const Key('z_adjust_chips'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < chips.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      chips[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The Auto chip: filled while Auto is on, with the wand icon.
class _AutoChip extends StatelessWidget {
  final ZImageEditorTheme theme;
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _AutoChip({
    super.key,
    required this.theme,
    required this.label,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final fg = on ? t.chipSelectedTextColor : t.chipTextColor;
    return Semantics(
      button: true,
      toggled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height:
              t.chipTapHeight > t.chipHeight ? t.chipTapHeight : t.chipHeight,
          child: Center(
            child: Container(
              height: t.chipHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: on ? t.chipSelectedColor : null,
                borderRadius: BorderRadius.circular(t.chipHeight),
                border: Border.all(
                    color: on ? t.chipSelectedColor : t.chipBorderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZLineIcon(ZLineIconKind.auto, color: fg, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: t.text(
                      color: fg,
                      fontSize: t.chipFontSize,
                      fontWeight: on ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
