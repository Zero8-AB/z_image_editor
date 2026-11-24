import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Material;

import '../theme/themed_controls.dart';
import '../theme/z_image_editor_theme.dart';
import 'frame_detector.dart';
import 'perspective_warp.dart';
import 'quad_math.dart';

/// At most this many outline chips are shown, whatever the detector returns.
const int kMaxFrameCandidates = 3;

/// What the frame step hands back to the editor.
class FrameCropResult {
  /// The image to continue editing with, or null to keep the original
  /// unchanged (full photo, not turned, no enhancement).
  final Uint8List? outputBytes;

  /// The corners the user ended with, normalized in the *turned* view
  /// (TL, TR, BR, BL on screen).
  final List<Offset> corners;

  /// Quarter turns clockwise applied in the frame step.
  final int quarterTurns;

  /// Index of the chip the outline came from (null: full photo / manual).
  final int? baseCandidate;

  /// Whether the outline was dragged after choosing [baseCandidate].
  final bool edited;

  /// The detector's candidates, so reopening the step does not detect again.
  final List<ZFrameCandidate> candidates;

  /// Whether detection finished (an empty [candidates] then means "nothing
  /// found", not "not run yet").
  final bool detectionDone;

  /// Whether the enhancer toggle was on.
  final bool enhanceOn;

  /// The enhancer output (cached for reopening), or null if none.
  final Uint8List? enhancedBytes;

  /// Whether the enhancer already ran.
  final bool enhancerRan;

  const FrameCropResult({
    required this.outputBytes,
    required this.corners,
    required this.candidates,
    this.quarterTurns = 0,
    this.detectionDone = true,
    this.baseCandidate,
    this.edited = false,
    this.enhanceOn = false,
    this.enhancedBytes,
    this.enhancerRan = false,
  });
}

/// Signature of the function that rectifies the image; injectable for tests.
/// [corners] are normalized in the original (EXIF-oriented) image, in output
/// order TL, TR, BR, BL.
typedef FrameWarpFunction = Future<Uint8List> Function(
  Uint8List bytes,
  List<Offset> corners,
);

/// The "choose the painting's rectangle" step: the photo with a draggable
/// four-corner outline, up to [kMaxFrameCandidates] detector outlines as
/// chips, and a tool row (enhancer toggle, Rotate, Full photo, Reset).
class FrameCropView extends StatefulWidget {
  final Uint8List imageBytes;
  final ZFrameDetector? detector;
  final ZImageEnhancer? enhancer;
  final ZFrameCropLabels labels;
  final ZImageEditorTheme theme;
  final String cancelLabel;
  final String resetLabel;
  final bool enableMagnifyingGlass;

  /// State to restore when the step is reopened.
  final FrameCropResult? previous;

  final VoidCallback onCancel;
  final ValueChanged<FrameCropResult> onContinue;

  /// Defaults to [ZPerspectiveWarp.warpBytes].
  final FrameWarpFunction? warp;

  const FrameCropView({
    super.key,
    required this.imageBytes,
    required this.onCancel,
    required this.onContinue,
    this.detector,
    this.enhancer,
    this.labels = const ZFrameCropLabels(),
    this.theme = const ZImageEditorTheme(),
    this.cancelLabel = 'Cancel',
    this.resetLabel = 'Reset',
    this.enableMagnifyingGlass = true,
    this.previous,
    this.warp,
  });

  @override
  State<FrameCropView> createState() => _FrameCropViewState();
}

Future<ui.Image> _decodeForDisplay(Uint8List bytes) async {
  // A display copy is enough (corners are normalized); cap its size to keep
  // memory low with 12+ MP photos.
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      const maxSide = 2048;
      final longest = math.max(w, h);
      if (longest <= maxSide) return ui.TargetImageSize(width: w);
      return ui.TargetImageSize(width: (w * maxSide / longest).round());
    },
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

class _FrameCropViewState extends State<FrameCropView> {
  ui.Image? _image;
  bool _decodeFailed = false;

  /// Detector outlines, normalized in the original (unturned) image.
  List<ZFrameCandidate> _candidates = const [];
  bool _detecting = false;

  // Enhancer: original and fixed versions are both kept for instant switching.
  bool _enhancing = false;
  bool _enhancerRan = false;
  Uint8List? _enhancedBytes;
  ui.Image? _enhancedImage;
  bool _enhanceOn = true;

  /// Quarter turns clockwise of the photo in this step.
  int _turns = 0;

  /// Current outline, normalized in the turned view, TL/TR/BR/BL on screen.
  List<Offset> _corners = ZQuadMath.fullImage;

  /// Chip the outline came from; null = full photo or hand-made.
  int? _base;

  /// Whether the outline was dragged since choosing [_base].
  bool _edited = false;

  bool _userTouched = false;
  int? _dragCorner;
  bool _applying = false;

  ZImageEditorTheme get _theme => widget.theme;

  ui.Image? get _displayImage =>
      _enhanceOn && _enhancedImage != null ? _enhancedImage : _image;

  /// Default outline (what Reset returns to): the pre-selected candidate,
  /// else the first, else the full photo.
  int? get _defaultBase {
    if (_candidates.isEmpty) return null;
    final i = _candidates.indexWhere((c) => c.preselected);
    return i < 0 ? 0 : i;
  }

  List<Offset> _candidateCorners(int i) =>
      ZQuadMath.rotateQuad(_candidates[i].corners, _turns);

  bool get _isFullPhoto =>
      _base == null && !_edited && ZQuadMath.isFullImage(_corners);

  bool get _canReset =>
      _turns != 0 ||
      _edited ||
      _base != _defaultBase ||
      (_defaultBase == null && !ZQuadMath.isFullImage(_corners));

  @override
  void initState() {
    super.initState();
    final previous = widget.previous;
    if (previous != null) {
      _turns = previous.quarterTurns;
      _corners = List.of(previous.corners);
      _base = previous.baseCandidate;
      _edited = previous.edited;
      _userTouched = true;
      _enhanceOn = previous.enhanceOn;
    }
    _decode();
    if (previous != null && previous.detectionDone) {
      _setCandidates(previous.candidates);
    } else if (widget.detector != null) {
      _detect();
    }
    if (previous != null && previous.enhancerRan) {
      _enhancerRan = true;
      if (previous.enhancedBytes != null) {
        _useEnhanced(previous.enhancedBytes!);
      }
    } else if (widget.enhancer != null) {
      _enhance();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _enhancedImage?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final image = await _decodeForDisplay(widget.imageBytes);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (_) {
      if (mounted) setState(() => _decodeFailed = true);
    }
  }

  Future<void> _detect() async {
    setState(() => _detecting = true);
    List<ZFrameCandidate> found;
    try {
      found = await widget.detector!.detect(widget.imageBytes);
    } catch (_) {
      found = const [];
    }
    if (!mounted) return;
    setState(() {
      _detecting = false;
      _setCandidates(found);
    });
  }

  Future<void> _enhance() async {
    setState(() => _enhancing = true);
    Uint8List? fixed;
    try {
      fixed = await widget.enhancer!.apply(widget.imageBytes);
    } catch (_) {
      fixed = null;
    }
    if (!mounted) return;
    setState(() {
      _enhancing = false;
      _enhancerRan = true;
    });
    if (fixed != null) await _useEnhanced(fixed);
  }

  Future<void> _useEnhanced(Uint8List bytes) async {
    try {
      final image = await _decodeForDisplay(bytes);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _enhancedBytes = bytes;
        _enhancedImage = image;
      });
    } catch (_) {
      // Undecodable output: behave as "nothing to fix".
    }
  }

  void _setCandidates(List<ZFrameCandidate> found) {
    final valid = <ZFrameCandidate>[];
    for (final c in found) {
      final clamped = [for (final p in c.corners) ZQuadMath.clampUnit(p)];
      if (!ZQuadMath.isConvex(clamped, clockwiseOnly: true)) continue;
      valid.add(ZFrameCandidate(
        corners: clamped,
        label: c.label,
        score: c.score,
        preselected: c.preselected,
      ));
      if (valid.length == kMaxFrameCandidates) break;
    }
    _candidates = valid;
    if (!_userTouched) {
      _base = _defaultBase;
      _edited = false;
      _corners =
          _base == null ? ZQuadMath.fullImage : _candidateCorners(_base!);
    }
  }

  void _selectCandidate(int? index) {
    setState(() {
      _userTouched = true;
      _base = index;
      _edited = false;
      _corners = index == null ? ZQuadMath.fullImage : _candidateCorners(index);
    });
  }

  /// Tap on the photo: next chip, then the full photo, then around again.
  void _cycle() {
    if (_candidates.isEmpty) return;
    final order = <int?>[for (var i = 0; i < _candidates.length; i++) i, null];
    final at = _isFullPhoto ? order.length - 1 : order.indexOf(_base);
    _selectCandidate(order[(at + 1) % order.length]);
  }

  void _rotate() {
    setState(() {
      _userTouched = true;
      _turns = (_turns + 1) % 4;
      _corners = ZQuadMath.rotateQuad(_corners, 1);
    });
  }

  void _reset() {
    setState(() {
      _userTouched = true;
      _turns = 0;
      _base = _defaultBase;
      _edited = false;
      _corners =
          _base == null ? ZQuadMath.fullImage : _candidateCorners(_base!);
    });
  }

  void _moveCorner(int index, Offset delta, Rect fitted) {
    if (_applying) return;
    final moved = List.of(_corners);
    moved[index] = ZQuadMath.clampUnit(
      moved[index] + Offset(delta.dx / fitted.width, delta.dy / fitted.height),
    );
    // Keep a sane, non-mirrored outline of a minimum size.
    if (!ZQuadMath.isConvex(moved, clockwiseOnly: true) ||
        ZQuadMath.area(moved) < 0.0025) {
      return;
    }
    setState(() {
      _userTouched = true;
      _corners = moved;
      _edited = true;
    });
  }

  Future<void> _continue() async {
    if (_applying || _detecting || _enhancing || _image == null) return;
    final corners = List<Offset>.unmodifiable(_corners);
    final enhanced = _enhanceOn ? _enhancedBytes : null;
    FrameCropResult result(Uint8List? out) => FrameCropResult(
          outputBytes: out,
          corners: corners,
          quarterTurns: _turns,
          baseCandidate: _base,
          edited: _edited,
          candidates: _candidates,
          detectionDone: !_detecting,
          enhanceOn: _enhanceOn,
          enhancedBytes: _enhancedBytes,
          enhancerRan: _enhancerRan,
        );

    if (_turns == 0 && ZQuadMath.isFullImage(corners)) {
      widget.onContinue(result(enhanced));
      return;
    }
    setState(() => _applying = true);
    try {
      // Output order follows the screen; map the corners back into the
      // unturned image so the warp also applies the turn.
      final source = [
        for (final c in corners) ZQuadMath.unrotatePoint(c, _turns),
      ];
      final warp = widget.warp ?? ZPerspectiveWarp.warpBytes;
      final bytes = await warp(enhanced ?? widget.imageBytes, source);
      if (!mounted) return;
      widget.onContinue(result(bytes));
    } catch (_) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to process image'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final enhancer = widget.enhancer;
    return Material(
      color: _theme.backgroundColor,
      child: Column(
        children: [
          FrameStepHeader(
            theme: _theme,
            title: labels.title,
            cancelLabel: widget.cancelLabel,
            continueLabel: labels.continueLabel,
            busy: _applying || _detecting || _enhancing,
            onCancel: _applying ? null : widget.onCancel,
            onContinue: _applying || _detecting || _enhancing || _image == null
                ? null
                : _continue,
          ),
          Expanded(child: _buildCanvas()),
          Container(
            color: _theme.panelColor,
            padding: EdgeInsets.only(
              top: 12,
              bottom: 8 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: math.max(_theme.chipHeight, 36),
                  child: _buildChips(labels),
                ),
                const SizedBox(height: 12),
                FrameToolRow(
                  theme: _theme,
                  children: [
                    if (enhancer != null &&
                        (_enhancing || _enhancedBytes != null))
                      ZToolButton(
                        key: const Key('z_frame_enhance'),
                        theme: _theme,
                        icon: _enhanceOn
                            ? ZLineIconKind.reflectionsOff
                            : ZLineIconKind.reflections,
                        label: _enhanceOn ? enhancer.label : enhancer.offLabel,
                        active: _enhanceOn && !_enhancing,
                        toggled: _enhanceOn,
                        onTap: _enhancing || _applying
                            ? null
                            : () => setState(() => _enhanceOn = !_enhanceOn),
                      ),
                    ZToolButton(
                      key: const Key('z_frame_rotate'),
                      theme: _theme,
                      icon: ZLineIconKind.rotate,
                      label: labels.rotateLabel,
                      onTap: _applying || _image == null ? null : _rotate,
                    ),
                    ZToolButton(
                      key: const Key('z_frame_full'),
                      theme: _theme,
                      icon: ZLineIconKind.fullPhoto,
                      label: labels.fullPhotoLabel,
                      active: _isFullPhoto,
                      activeColor: _theme.accentColor,
                      onTap: _applying ? null : () => _selectCandidate(null),
                    ),
                    ZToolButton(
                      key: const Key('z_frame_reset'),
                      theme: _theme,
                      icon: ZLineIconKind.reset,
                      label: widget.resetLabel,
                      onTap: _applying || !_canReset ? null : _reset,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChips(ZFrameCropLabels labels) {
    if (_detecting) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(color: _theme.mutedTextColor),
          const SizedBox(width: 10),
          Text(labels.detectingLabel,
              style: _theme.text(color: _theme.mutedTextColor)),
        ],
      );
    }
    if (_candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            labels.manualHint,
            textAlign: TextAlign.center,
            style: _theme.text(color: _theme.mutedTextColor, fontSize: 13),
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _candidates.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ZChip(
                  key: Key('z_frame_chip_$i'),
                  theme: _theme,
                  label: _base == i && _edited
                      ? '${_candidates[i].label}${labels.editedSuffix}'
                      : _candidates[i].label,
                  selected: _base == i,
                  onTap: _applying ? null : () => _selectCandidate(i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    final image = _displayImage;
    if (image == null) {
      return Center(
        child: _decodeFailed
            ? Text('Could not open the image',
                style: _theme.text(color: _theme.mutedTextColor))
            : CupertinoActivityIndicator(color: _theme.textColor),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = _theme.canvasPadding;
        final area = Size(
          math.max(1, constraints.maxWidth - pad * 2),
          math.max(1, constraints.maxHeight - pad * 2),
        );
        final odd = _turns.isOdd;
        final imgSize = Size(
          (odd ? image.height : image.width).toDouble(),
          (odd ? image.width : image.height).toDouble(),
        );
        final fittedSize =
            applyBoxFit(BoxFit.contain, imgSize, area).destination;
        final fitted = Rect.fromLTWH(
          (constraints.maxWidth - fittedSize.width) / 2,
          (constraints.maxHeight - fittedSize.height) / 2,
          fittedSize.width,
          fittedSize.height,
        );
        final pts = [
          for (final c in _corners)
            Offset(
              fitted.left + c.dx * fitted.width,
              fitted.top + c.dy * fitted.height,
            ),
        ];
        final hit = _theme.handleHitSize;

        return Stack(
          key: const Key('z_frame_canvas'),
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const Key('z_frame_photo'),
                behavior: HitTestBehavior.opaque,
                onTap: _applying ? null : _cycle,
                child: CustomPaint(
                  painter: FrameQuadPainter(
                    image: image,
                    quarterTurns: _turns,
                    fitted: fitted,
                    quad: pts,
                    dragging: _dragCorner != null,
                    theme: _theme,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < 4; i++)
              Positioned(
                left: pts[i].dx - hit / 2,
                top: pts[i].dy - hit / 2,
                width: hit,
                height: hit,
                child: FrameCornerHandle(
                  key: Key('z_frame_handle_$i'),
                  theme: _theme,
                  active: _dragCorner == i,
                  onStart: () {
                    if (!_applying) setState(() => _dragCorner = i);
                  },
                  onMove: (delta) => _moveCorner(i, delta, fitted),
                  onEnd: () => setState(() => _dragCorner = null),
                ),
              ),
            if (widget.enableMagnifyingGlass && _dragCorner != null)
              _buildLoupe(image, fitted, pts, _dragCorner!, constraints),
          ],
        );
      },
    );
  }

  Widget _buildLoupe(
    ui.Image image,
    Rect fitted,
    List<Offset> pts,
    int corner,
    BoxConstraints constraints,
  ) {
    final diameter = _theme.loupeDiameter;
    final focus = pts[corner];
    // Above the finger; below it when there is no room at the top.
    var top = focus.dy - diameter - 48;
    if (top < 0) top = focus.dy + 48;
    final maxLeft = math.max(0.0, constraints.maxWidth - diameter);
    final left = (focus.dx - diameter / 2).clamp(0.0, maxLeft).toDouble();
    return Positioned(
      left: left,
      top: top,
      width: diameter,
      height: diameter,
      child: IgnorePointer(
        child: CustomPaint(
          key: const Key('z_frame_loupe'),
          painter: FrameLoupePainter(
            image: image,
            quarterTurns: _turns,
            fitted: fitted,
            quad: pts,
            focus: focus,
            theme: _theme,
          ),
        ),
      ),
    );
  }
}

// ── Presentational pieces (all styling comes from ZImageEditorTheme) ─────────

/// Header: secondary action left, optional title, primary action right.
class FrameStepHeader extends StatelessWidget {
  final ZImageEditorTheme theme;
  final String title;
  final String cancelLabel;
  final String continueLabel;
  final bool busy;
  final VoidCallback? onCancel;
  final VoidCallback? onContinue;
  final bool cancelIsBack;

  const FrameStepHeader({
    super.key,
    required this.theme,
    required this.title,
    required this.cancelLabel,
    required this.continueLabel,
    required this.busy,
    required this.onCancel,
    required this.onContinue,
    this.cancelIsBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = kIsWeb ? 0.0 : MediaQuery.of(context).padding.top;
    return Container(
      color: theme.panelColor,
      padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 6),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (theme.showTitle)
              Text(
                title,
                style: TextStyle(
                  color: theme.textColor,
                  fontFamily: theme.titleFontFamily ?? theme.fontFamily,
                  fontSize: theme.titleFontSize,
                  letterSpacing: 0.5,
                  decoration: TextDecoration.none,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ZSecondaryButton(
                  key: const Key('z_frame_cancel'),
                  theme: theme,
                  label: cancelLabel,
                  showBackChevron: cancelIsBack,
                  onPressed: onCancel,
                ),
                ZPrimaryButton(
                  key: const Key('z_frame_continue'),
                  theme: theme,
                  label: continueLabel,
                  busy: busy,
                  onPressed: onContinue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of [ZToolButton]s with a hairline above it.
class FrameToolRow extends StatelessWidget {
  final ZImageEditorTheme theme;
  final List<Widget> children;

  const FrameToolRow({super.key, required this.theme, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [for (final c in children) Expanded(child: c)],
      ),
    );
  }
}

/// Round corner handle with a larger, transparent touch target.
class FrameCornerHandle extends StatelessWidget {
  final ZImageEditorTheme theme;
  final bool active;
  final VoidCallback onStart;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEnd;

  const FrameCornerHandle({
    super.key,
    required this.theme,
    required this.active,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final d = active ? theme.handleDiameterActive : theme.handleDiameter;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => onStart(),
      onPanUpdate: (details) => onMove(details.delta),
      onPanEnd: (_) => onEnd(),
      onPanCancel: onEnd,
      child: Center(
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.handleColor,
            boxShadow: [
              if (active)
                BoxShadow(color: theme.handleHaloColor, spreadRadius: 6)
              else
                const BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _paintTurnedImage(
  Canvas canvas,
  ui.Image image,
  int quarterTurns,
  Rect fitted,
  FilterQuality quality,
) {
  canvas.save();
  canvas.translate(fitted.center.dx, fitted.center.dy);
  canvas.rotate(quarterTurns * math.pi / 2);
  final w = quarterTurns.isOdd ? fitted.height : fitted.width;
  final h = quarterTurns.isOdd ? fitted.width : fitted.height;
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromCenter(center: Offset.zero, width: w, height: h),
    Paint()..filterQuality = quality,
  );
  canvas.restore();
}

/// Photo, dimmed outside the outline, thirds grid, and the outline itself.
class FrameQuadPainter extends CustomPainter {
  final ui.Image image;
  final int quarterTurns;
  final Rect fitted;
  final List<Offset> quad;
  final bool dragging;
  final ZImageEditorTheme theme;

  FrameQuadPainter({
    required this.image,
    required this.quarterTurns,
    required this.fitted,
    required this.quad,
    required this.dragging,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintTurnedImage(
        canvas, image, quarterTurns, fitted, FilterQuality.medium);

    final quadPath = Path()..addPolygon(quad, true);
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(fitted)
      ..addPath(quadPath, Offset.zero);
    canvas.drawPath(
      dim,
      Paint()
        ..color = const Color(0xFF000000).withValues(
          alpha: dragging ? theme.dimOpacityDragging : theme.dimOpacity,
        ),
    );

    if (theme.showGrid) {
      final grid = Paint()
        ..color = theme.gridColor
        ..strokeWidth = 1;
      for (final t in const [1 / 3, 2 / 3]) {
        canvas.drawLine(Offset.lerp(quad[0], quad[1], t)!,
            Offset.lerp(quad[3], quad[2], t)!, grid);
        canvas.drawLine(Offset.lerp(quad[0], quad[3], t)!,
            Offset.lerp(quad[1], quad[2], t)!, grid);
      }
    }

    canvas.drawPath(
      quadPath,
      Paint()
        ..color = theme.quadColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.quadStrokeWidth,
    );
  }

  @override
  bool shouldRepaint(FrameQuadPainter old) =>
      old.image != image ||
      old.quarterTurns != quarterTurns ||
      old.fitted != fitted ||
      old.dragging != dragging ||
      old.theme != theme ||
      !_sameQuad(old.quad, quad);
}

/// Circular magnifier centred on the dragged corner, with a crosshair.
class FrameLoupePainter extends CustomPainter {
  final ui.Image image;
  final int quarterTurns;
  final Rect fitted;
  final List<Offset> quad;
  final Offset focus;
  final ZImageEditorTheme theme;

  FrameLoupePainter({
    required this.image,
    required this.quarterTurns,
    required this.fitted,
    required this.quad,
    required this.focus,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = theme.loupeZoom;
    final r = size.width / 2;
    final centre = Offset(r, r);

    canvas.drawCircle(
      centre.translate(0, 4),
      r,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.save();
    canvas
        .clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r)));
    canvas.drawPaint(Paint()..color = theme.backgroundColor);
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(zoom);
    canvas.translate(-focus.dx, -focus.dy);
    _paintTurnedImage(canvas, image, quarterTurns, fitted, FilterQuality.high);
    canvas.drawPath(
      Path()..addPolygon(quad, true),
      Paint()
        ..color = theme.quadColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / zoom,
    );
    canvas.restore();

    final cross = Paint()
      ..color = theme.loupeCrosshairColor
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, r), Offset(size.width, r), cross);
    canvas.drawLine(Offset(r, 0), Offset(r, size.height), cross);
    canvas.drawCircle(
      centre,
      r - 1,
      Paint()
        ..color = theme.loupeBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(FrameLoupePainter old) =>
      old.focus != focus ||
      old.fitted != fitted ||
      old.image != image ||
      old.quarterTurns != quarterTurns ||
      !_sameQuad(old.quad, quad);
}

bool _sameQuad(List<Offset> a, List<Offset> b) {
  for (var i = 0; i < 4; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
