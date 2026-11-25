import 'package:flutter/widgets.dart';

/// Look of the editor chrome and the frame step. Every colour, font and size
/// those use lives here, so the editor can be restyled without touching its
/// layout or behaviour.
///
/// The default constructor reproduces the editor's original iOS-style look
/// (yellow accents), so apps that pass nothing see no change.
@immutable
class ZImageEditorTheme {
  // ── General ──────────────────────────────────────────────────────────────
  /// Behind the photo.
  final Color backgroundColor;

  /// Header, bottom panel and tool row.
  final Color panelColor;

  /// Raised surfaces: toolbar pills, tab bar, menus.
  final Color surfaceColor;

  /// Main text and icon colour.
  final Color textColor;

  /// Secondary text (hints, inactive tabs).
  final Color mutedTextColor;

  /// Disabled tools.
  final Color disabledColor;

  /// Hairline dividers (above the tool row).
  final Color dividerColor;

  /// Selection / emphasis colour (selected chip, active tab, Reset).
  final Color accentColor;

  /// Text on top of [accentColor].
  final Color onAccentColor;

  /// Colour of an "on" toggle in the tool row (e.g. reflection removal).
  final Color toggleOnColor;

  /// UI font (null = platform default) and the screen-title font.
  final String? fontFamily;
  final String? titleFontFamily;
  final double titleFontSize;

  /// Whether the header shows a centred screen title.
  final bool showTitle;

  // ── Tabs ─────────────────────────────────────────────────────────────────
  /// Colour of the selected tab (Adjust / Crop).
  final Color tabSelectedColor;

  /// Tabs as a flat tool row (line icons over labels, hairline above)
  /// instead of the floating pill.
  final bool toolRowTabs;

  // ── Header buttons ───────────────────────────────────────────────────────
  final Color primaryButtonColor;
  final Color primaryButtonPressedColor;
  final Color primaryButtonTextColor;
  final double primaryButtonRadius;
  final double primaryButtonHeight;

  /// Cancel: a filled pill when [cancelButtonColor] is set, a text button
  /// in [textColor] otherwise.
  final Color? cancelButtonColor;
  final Color cancelButtonTextColor;

  // ── Chips ────────────────────────────────────────────────────────────────
  final double chipHeight;
  final Color chipSelectedColor;
  final Color chipSelectedTextColor;
  final Color chipTextColor;
  final Color chipBorderColor;
  final double chipFontSize;

  // ── Tool row (icon + short label) ────────────────────────────────────────
  final double toolIconSize;
  final double toolLabelFontSize;

  // ── Frame step quad ──────────────────────────────────────────────────────
  final Color quadColor;
  final double quadStrokeWidth;
  final double dimOpacity;
  final double dimOpacityDragging;
  final bool showGrid;
  final Color gridColor;
  final double handleDiameter;
  final double handleDiameterActive;
  final double handleHitSize;
  final Color handleColor;
  final Color handleHaloColor;

  /// Ring around each corner handle (null: no ring).
  final Color? handleRingColor;
  final double handleRingWidth;

  /// Outline of the other (not selected) detected outlines; null hides them.
  final Color? alternativeOutlineColor;
  final double alternativeOutlineWidth;

  /// Tap height around a chip (the pill itself is [chipHeight]).
  final double chipTapHeight;

  /// Header height (below the status bar) and side padding.
  final double headerHeight;
  final double loupeDiameter;
  final double loupeZoom;
  final Color loupeBorderColor;
  final Color loupeCrosshairColor;
  final double canvasPadding;

  const ZImageEditorTheme({
    this.backgroundColor = const Color(0xFF000000),
    this.panelColor = const Color(0xFF1C1C1E),
    this.surfaceColor = const Color(0xFF2C2C2E),
    this.textColor = const Color(0xFFFFFFFF),
    this.mutedTextColor = const Color(0xB3FFFFFF),
    this.disabledColor = const Color(0x4DFFFFFF),
    this.dividerColor = const Color(0x00000000),
    this.accentColor = const Color(0xFFFFCC00),
    this.onAccentColor = const Color(0xFF000000),
    this.toggleOnColor = const Color(0xFFFFCC00),
    this.fontFamily,
    this.titleFontFamily,
    this.titleFontSize = 17,
    this.showTitle = false,
    this.tabSelectedColor = const Color(0xFF007AFF),
    this.toolRowTabs = false,
    this.primaryButtonColor = const Color(0xFFFFCC00),
    this.primaryButtonPressedColor = const Color(0xFFE6B800),
    this.primaryButtonTextColor = const Color(0xFF000000),
    this.primaryButtonRadius = 50,
    this.primaryButtonHeight = 28,
    this.cancelButtonColor = const Color(0xFFFFFFFF),
    this.cancelButtonTextColor = const Color(0xFF000000),
    this.chipHeight = 34,
    this.chipSelectedColor = const Color(0xFFAEAEB2),
    this.chipSelectedTextColor = const Color(0xFF000000),
    this.chipTextColor = const Color(0xB3FFFFFF),
    this.chipBorderColor = const Color(0x00000000),
    this.chipFontSize = 14,
    this.toolIconSize = 22,
    this.toolLabelFontSize = 11,
    this.quadColor = const Color(0xFFFFFFFF),
    this.quadStrokeWidth = 1.5,
    this.dimOpacity = 0.55,
    this.dimOpacityDragging = 0.35,
    this.showGrid = true,
    this.gridColor = const Color(0x59FFFFFF),
    this.handleDiameter = 18,
    this.handleDiameterActive = 26,
    this.handleHitSize = 48,
    this.handleColor = const Color(0xFFFFFFFF),
    this.handleHaloColor = const Color(0x40FFFFFF),
    this.handleRingColor,
    this.handleRingWidth = 2,
    this.alternativeOutlineColor,
    this.alternativeOutlineWidth = 1,
    this.chipTapHeight = 44,
    this.headerHeight = 44,
    this.loupeDiameter = 96,
    this.loupeZoom = 2.5,
    this.loupeBorderColor = const Color(0xFFFFFFFF),
    this.loupeCrosshairColor = const Color(0xFFFFCC00),
    this.canvasPadding = 28,
  });

  /// Text style for UI text in this theme.
  TextStyle text({
    Color? color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    double? letterSpacing,
  }) =>
      TextStyle(
        color: color ?? textColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
        letterSpacing: letterSpacing,
        decoration: TextDecoration.none,
      );
}
