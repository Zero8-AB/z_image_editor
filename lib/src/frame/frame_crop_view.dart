import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart' show Material;

import '../theme/themed_controls.dart';
import '../theme/z_image_editor_theme.dart';
import 'artwork_size.dart';
import 'frame_detector.dart';
import 'photo_hint_banner.dart';
import 'photo_quality.dart';
import 'measurement_lines.dart';
import 'perspective_warp.dart';
import 'quad_math.dart';
import 'rect_aspect.dart';
import 'shape_label.dart';
import 'size_sheet.dart';

/// At most this many outline chips are shown, whatever the detector returns.
const int kMaxFrameCandidates = 3;

/// How far (relative) a size from the artwork's details may be from the
/// photo's estimated H : W and still be used as the exact size.
const double kKnownSizeAspectTolerance = 0.12;

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

  /// The size the user confirmed (or that was known/measured); null when
  /// only estimated.
  final ZArtworkSize? size;

  /// A size that was confirmed in the size sheet or measured, and the
  /// outline it was given for ([anchorCorners], normalized in the turned
  /// view like [corners]). Other outlines of the same object are sized
  /// from it, so [size] is null and [shownSize] an estimate when Next was
  /// pressed on another outline. Both null when no size is tied to an
  /// outline (none, or one from the artwork's details).
  final ZArtworkSize? anchorSize;
  final List<Offset>? anchorCorners;

  /// The size the step showed on Next: [size] when exact, else the "≈"
  /// estimate (source [ZSizeSource.estimated]); null when none was shown
  /// (no size tools, or no outline to estimate from).
  final ZArtworkSize? shownSize;

  /// Width / height the straightened image was given (null: no warp).
  final double? outputAspectWH;

  /// The photo hint found (null: none, or not checked).
  final ZPhotoIssue? photoIssue;

  /// Whether the photo check ran (so reopening the step does not repeat it).
  final bool photoChecked;

  /// Whether the user closed the hint (Use anyway or the cross).
  final bool hintClosed;

  /// Shape of the outline the image was cut to (round / oval: outside the
  /// ellipse is transparent or filled).
  final ZFrameShape shape;

  /// Shapes the user picked with "Wrong?", per chip (-1: hand-made / full
  /// photo outline), so reopening restores them.
  final Map<int, ZFrameShape> shapeOverrides;

  const FrameCropResult({
    this.shape = ZFrameShape.rectangle,
    this.shapeOverrides = const {},
    this.photoIssue,
    this.photoChecked = false,
    this.hintClosed = false,
    this.size,
    this.anchorSize,
    this.anchorCorners,
    this.shownSize,
    this.outputAspectWH,
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

  /// What the step saw (frame, mat, glass, shape), or null when the
  /// detector did not run or found no outline.
  ZFrameEvidence? get evidence => !detectionDone || candidates.isEmpty
      ? null
      : ZFrameEvidence.fromCandidates(
          candidates,
          glassReflections:
              enhancedBytes != null || photoIssue == ZPhotoIssue.glare,
          shapeOverrides: shapeOverrides,
        );
}

/// Signature of the function that rectifies the image; injectable for tests.
/// [corners] are normalized in the original (EXIF-oriented) image, in output
/// order TL, TR, BR, BL.
typedef FrameWarpFunction = Future<Uint8List> Function(
  Uint8List bytes,
  List<Offset> corners,
);

/// One solved height / width, remembered for the outline it was solved for.
class _AspectMemo {
  ui.Image? image;
  int turns = 0;
  List<Offset>? corners;
  double? value;
}

/// Key of the hand-made / full-photo outline in the shape overrides.
const int _manualShapeKey = -1;

/// The "choose the painting's rectangle" step: the photo with a draggable
/// four-corner outline, up to [kMaxFrameCandidates] detector outlines as
/// chips, and a tool row (enhancer toggle, Rotate, Full photo, Reset, and
/// Retake when [onRetake] is set).
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

  /// Show the Size tool, the measurement lines and the size sheet.
  final bool sizeTools;

  /// Size known before the step (artwork details or measured).
  final ZArtworkSize? knownSize;
  final ZSizeSheetLabels sizeLabels;

  /// Checks the photo after detection and shows at most one hint.
  final ZPhotoChecker? photoChecker;
  final ZPhotoHintLabels hintLabels;

  /// "Retake" in the hint and in the tool row; null hides both.
  final VoidCallback? onRetake;

  final VoidCallback onCancel;
  final ValueChanged<FrameCropResult> onContinue;

  /// Defaults to [ZPerspectiveWarp.warpBytes].
  final FrameWarpFunction? warp;

  /// Colour outside a round / oval outline when the result can't keep
  /// transparency (e.g. the editor saves JPEG). Null: transparent.
  final Color? outsideFill;

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
    this.sizeTools = false,
    this.knownSize,
    this.sizeLabels = const ZSizeSheetLabels(),
    this.photoChecker,
    this.hintLabels = const ZPhotoHintLabels(),
    this.onRetake,
    this.outsideFill,
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

  /// Exact size (details, measured or confirmed); null = estimate only.
  /// A size from the artwork's details is only used while it matches the
  /// photo's shape: see [_exactSize].
  ZArtworkSize? _size;

  /// The outline [_size] was confirmed or measured for, in the turned view
  /// (it follows Rotate and the drags of that outline); null = not tied to
  /// an outline. On any other outline of the object the size is derived
  /// from this one ("≈"): see [_shownSize].
  List<Offset>? _sizeCorners;

  /// A measured size arrives before the outlines: it is tied to the
  /// pre-selected one (what the camera measured) once they are known.
  bool _tieMeasuredSize = false;

  /// Photo hint (at most one) and whether the user closed it.
  ZPhotoIssue? _issue;
  bool _photoChecked = false;
  bool _hintClosed = false;

  /// Shapes picked with "Wrong?" per chip ([_manualShapeKey]: hand-made).
  Map<int, ZFrameShape> _shapeOverrides = {};

  /// Focal length in display-image pixels from EXIF (null: unknown).
  double? _focalPx;
  bool _focalRead = false;

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

  /// Shape of the current outline: the user's pick, else the chip's.
  ZFrameShape get _shape {
    final o = _shapeOverrides[_base ?? _manualShapeKey];
    if (o != null) return o;
    final b = _base;
    return b == null || b >= _candidates.length
        ? ZFrameShape.rectangle
        : _candidates[b].shape;
  }

  bool get _isEllipse => _shape != ZFrameShape.rectangle;

  /// The shape label shows when a round / oval outline was found (or the
  /// user changed a shape).
  bool get _showShapeLabel =>
      _shapeOverrides.isNotEmpty ||
      _candidates.any((c) => c.shape != ZFrameShape.rectangle);

  /// Whether the shape menu is up: a second tap while it opens is ignored
  /// instead of stacking a second menu.
  bool _shapeMenuOpen = false;

  Future<void> _openShapeMenu() async {
    if (_shapeMenuOpen) return;
    _shapeMenuOpen = true;
    ZFrameShape? picked;
    try {
      picked = await showZFrameShapeMenu(
        context,
        theme: _theme,
        labels: widget.labels,
        current: _shape,
      );
    } finally {
      _shapeMenuOpen = false;
    }
    if (!mounted || picked == null) return;
    setState(() {
      _userTouched = true;
      _shapeOverrides = {
        ..._shapeOverrides,
        _base ?? _manualShapeKey: picked!,
      };
    });
  }

  bool get _isFullPhoto =>
      _base == null && !_edited && ZQuadMath.isFullImage(_corners);

  bool get _canReset =>
      _turns != 0 ||
      _shapeOverrides.isNotEmpty ||
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
      if (previous.anchorSize != null && previous.anchorCorners != null) {
        _size = previous.anchorSize;
        _sizeCorners = List.of(previous.anchorCorners!);
      } else {
        _size = previous.size;
      }
      _issue = previous.photoIssue;
      _photoChecked = previous.photoChecked;
      _hintClosed = previous.hintClosed;
      _shapeOverrides = Map.of(previous.shapeOverrides);
    }
    if (_size == null && widget.knownSize?.isExact == true) {
      _size = widget.knownSize;
      _tieMeasuredSize = _size!.source == ZSizeSource.measured;
    }
    _decode();
    if (previous != null && previous.detectionDone) {
      _setCandidates(previous.candidates);
      if (!_photoChecked) _checkPhoto();
    } else if (widget.detector != null) {
      _detect();
    } else {
      _checkPhoto();
    }
    if (previous != null && previous.enhancerRan) {
      _enhancerRan = true;
      if (previous.enhancedBytes != null) {
        _enhancing = true;
        _useEnhanced(previous.enhancedBytes!).whenComplete(() {
          if (mounted) setState(() => _enhancing = false);
        });
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

  /// Real height / width of the current outline: the exact size when known,
  /// else a perspective estimate (focal length from EXIF, or solved), else
  /// the average side lengths.
  double? get _aspectHW => _exactSize?.aspectHW ?? _estimatedAspectHW;

  /// The exact size to use for the current outline. A size from the
  /// artwork's details is a hint, not a measurement of this photo: it is
  /// used only when its H : W is within [kKnownSizeAspectTolerance] of the
  /// photo's estimate (a swapped height and width is a mismatch); otherwise
  /// the step falls back to the estimate ("≈ … · Check").
  ///
  /// A confirmed or measured size is exact only on the outline it was given
  /// for ([_sizeCorners]).
  ZArtworkSize? get _exactSize {
    final s = _size;
    if (s == null) return null;
    if (s.source != ZSizeSource.details) {
      final tied = _sizeCorners;
      return tied == null || ZQuadMath.isSame(_corners, tied) ? s : null;
    }
    final estimate = _estimatedAspectHW;
    if (estimate == null) return null;
    final ratio = s.aspectHW / estimate;
    final diff = ratio >= 1 ? ratio - 1 : 1 / ratio - 1;
    return diff <= kKnownSizeAspectTolerance ? s : null;
  }

  /// Real height / width of the current outline estimated from the photo
  /// alone (ignores any size): the size sheet's "Estimated shape".
  double? get _estimatedAspectHW =>
      _outlineAspectHW(_currentAspect, _corners, _shape);

  /// Real height / width of [corners] (turned view) from the photo: a
  /// perspective estimate (focal length from EXIF, or solved), else the
  /// average side lengths.
  double? _outlineAspectHW(
    _AspectMemo memo,
    List<Offset> corners,
    ZFrameShape shape,
  ) {
    // A round frame is a circle, however the photo was taken.
    if (shape == ZFrameShape.round) return 1;
    final image = _image;
    if (image == null) return null;
    // Asked several times per build (size label, lines, Next): solve once
    // per outline, not on every rebuild (keyboard and route animations
    // rebuild the step every frame).
    if (identical(image, memo.image) &&
        _turns == memo.turns &&
        listEquals(corners, memo.corners)) {
      return memo.value;
    }
    final v = _solveAspectHW(image, corners);
    memo
      ..image = image
      ..turns = _turns
      ..corners = List.of(corners)
      ..value = v;
    return v;
  }

  final _currentAspect = _AspectMemo();
  final _outerAspect = _AspectMemo();

  double? _solveAspectHW(ui.Image image, List<Offset> corners) {
    final imgSize = Size(image.width.toDouble(), image.height.toDouble());
    if (!_focalRead) {
      _focalRead = true;
      _focalPx = ZRectAspect.focalPxFromExif(widget.imageBytes, imgSize);
    }
    final px = [
      for (final c in corners)
        () {
          final o = ZQuadMath.unrotatePoint(c, _turns);
          return Offset(o.dx * imgSize.width, o.dy * imgSize.height);
        }(),
    ];
    final wh = ZRectAspect.widthOverHeight(px, imgSize, focalPx: _focalPx) ??
        ZRectAspect.sideAverage(px);
    // Quarter turns swap what the screen shows as width and height.
    return wh <= 0 ? null : 1 / wh;
  }

  /// The detector's outermost outline (largest area), or null.
  int? get _outerCandidate {
    int? outer;
    var area = 0.0;
    for (var i = 0; i < _candidates.length; i++) {
      final a = ZQuadMath.area(_candidates[i].corners);
      if (a > area) {
        area = a;
        outer = i;
      }
    }
    return outer;
  }

  /// The size to show: exact, or an estimate ("≈").
  ///
  /// A photo has no scale, so only one outline of an object gets its size
  /// from the common sizes; every outline nested with it (frame, mat
  /// window, artwork) is measured against that one on the straightened
  /// plane. The reference is the outline a size was confirmed or measured
  /// for, else the detector's outermost outline. So an inner level is
  /// never larger than the level around it.
  ZArtworkSize? get _shownSize {
    final exact = _exactSize;
    if (exact != null) return exact;

    final s = _size, tied = _sizeCorners;
    if (s != null && tied != null && s.source != ZSizeSource.details) {
      final derived = _sizeFrom(tied, s.heightCm, s.widthCm);
      if (derived != null) return derived;
    }

    final outer = _outerCandidate;
    if (outer != null && _base != outer) {
      final corners = _candidateCorners(outer);
      final aspect = _outlineAspectHW(
        _outerAspect,
        corners,
        _shapeOverrides[outer] ?? _candidates[outer].shape,
      );
      if (aspect != null &&
          ZQuadMath.isInside(_corners, corners, tolerance: _nestTolerance)) {
        final whole = ZCommonSizes.estimate(aspect);
        final derived = _sizeFrom(corners, whole.heightCm, whole.widthCm);
        if (derived != null) return derived;
      }
    }

    final aspect = _estimatedAspectHW;
    return aspect == null ? null : ZCommonSizes.estimate(aspect);
  }

  /// How far (normalized) an outline may poke out of the one around it and
  /// still count as nested.
  static const double _nestTolerance = 0.01;

  /// The current outline's size from [reference] (turned view), an outline
  /// of [heightCm] × [widthCm] that it lies inside or around; whole
  /// centimetres. Null when the two are not nested (or for the full
  /// photo, which is not a level of the object).
  ZArtworkSize? _sizeFrom(
    List<Offset> reference,
    double heightCm,
    double widthCm,
  ) {
    if (_isFullPhoto) return null;
    final inner =
        ZQuadMath.isInside(_corners, reference, tolerance: _nestTolerance);
    if (!inner &&
        !ZQuadMath.isInside(reference, _corners, tolerance: _nestTolerance)) {
      return null;
    }
    final size = ZRectAspect.sizeOnPlane(
      reference: reference,
      referenceHeight: heightCm,
      referenceWidth: widthCm,
      quad: _corners,
    );
    if (size == null) return null;
    var h = math.max(1.0, size.height.roundToDouble());
    var w = math.max(1.0, size.width.roundToDouble());
    // A round outline is a circle: one diameter.
    if (_shape == ZFrameShape.round) {
      h = w = math.max(1.0, ((size.height + size.width) / 2).roundToDouble());
    }
    // Rounding (and the tolerance) must not turn the order around.
    if (inner) {
      h = math.min(h, heightCm);
      w = math.min(w, widthCm);
    } else {
      h = math.max(h, heightCm);
      w = math.max(w, widthCm);
    }
    return ZArtworkSize(
      heightCm: h,
      widthCm: w,
      source: ZSizeSource.estimated,
    );
  }

  String get _sizeButtonLabel {
    final s = _shownSize;
    final l = widget.labels;
    if (s == null) return l.sizeUnknownLabel;
    if (s.isExact) return '${s.hwText} cm';
    return '≈ ${s.hwText} cm${l.sizeCheckSuffix}';
  }

  Future<void> _openSizeSheet() async {
    final result = await showZArtworkSizeSheet(
      context,
      theme: _theme,
      labels: widget.sizeLabels,
      estimatedAspectHW: _estimatedAspectHW,
      initial: _shownSize,
    );
    if (!mounted || result == null) return;
    setState(() {
      _size = result;
      _sizeCorners = List.of(_corners);
    });
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
    _checkPhoto();
  }

  /// Runs the photo checker (after detection, with its outlines). Never
  /// blocks: Next stays available and failures show nothing.
  Future<void> _checkPhoto() async {
    final checker = widget.photoChecker;
    if (checker == null || _photoChecked) return;
    _photoChecked = true;
    ZPhotoIssue? issue;
    try {
      issue = await checker.check(widget.imageBytes, _candidates);
    } catch (_) {
      issue = null;
    }
    if (!mounted) return;
    setState(() => _issue = issue);
  }

  void _closeHint() => setState(() => _hintClosed = true);

  Future<void> _enhance() async {
    setState(() => _enhancing = true);
    Uint8List? fixed;
    try {
      fixed = await widget.enhancer!.apply(widget.imageBytes);
    } catch (_) {
      fixed = null;
    }
    if (!mounted) return;
    // Stay busy until the fixed image is decoded and usable, so Next can't
    // run in between and drop the enhancement.
    if (fixed != null) await _useEnhanced(fixed);
    if (!mounted) return;
    setState(() {
      _enhancing = false;
      _enhancerRan = true;
    });
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
        shape: c.shape,
        level: c.level,
        matAround: c.matAround,
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
    if (_tieMeasuredSize && _defaultBase != null) {
      _tieMeasuredSize = false;
      _sizeCorners = _candidateCorners(_defaultBase!);
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
      final tied = _sizeCorners;
      if (tied != null) _sizeCorners = ZQuadMath.rotateQuad(tied, 1);
    });
  }

  void _reset() {
    setState(() {
      _userTouched = true;
      final tied = _sizeCorners;
      if (tied != null) {
        _sizeCorners = ZQuadMath.rotateQuad(tied, (4 - _turns) % 4);
      }
      _turns = 0;
      _shapeOverrides = {};
      _base = _defaultBase;
      _edited = false;
      _corners =
          _base == null ? ZQuadMath.fullImage : _candidateCorners(_base!);
    });
  }

  void _moveCorner(int index, Offset delta, Rect fitted) {
    if (_applying) return;
    final moved = List.of(_corners);
    final d = Offset(delta.dx / fitted.width, delta.dy / fitted.height);
    // A round outline's handles sit on its sides (top, right, bottom,
    // left): dragging one moves that side.
    for (final i in _isEllipse ? [index, (index + 1) % 4] : [index]) {
      moved[i] = ZQuadMath.clampUnit(moved[i] + d);
    }
    // Keep a sane, non-mirrored outline of a minimum size.
    if (!ZQuadMath.isConvex(moved, clockwiseOnly: true) ||
        ZQuadMath.area(moved) < 0.0025) {
      return;
    }
    // The outline a size was given for keeps it while it is dragged.
    final tied = _sizeCorners;
    final dragsTied = tied != null && ZQuadMath.isSame(_corners, tied);
    setState(() {
      _userTouched = true;
      _corners = moved;
      _edited = true;
      if (dragsTied) _sizeCorners = List.of(moved);
    });
  }

  Future<void> _continue() async {
    if (_applying || _detecting || _enhancing || _image == null) return;
    final corners = List<Offset>.unmodifiable(_corners);
    final enhanced = _enhanceOn ? _enhancedBytes : null;
    final shape = _shape;
    final ellipse = shape != ZFrameShape.rectangle;
    final aspectHW =
        widget.sizeTools || _exactSize != null || ellipse ? _aspectHW : null;
    final exactSize = _exactSize;
    final shownSize = widget.sizeTools ? _shownSize : null;
    final aspectWH = aspectHW == null ? null : 1 / aspectHW;
    final fill = widget.outsideFill?.toARGB32();
    FrameCropResult result(Uint8List? out) => FrameCropResult(
          size: exactSize,
          anchorSize: _sizeCorners == null ? null : _size,
          anchorCorners:
              _sizeCorners == null ? null : List.unmodifiable(_sizeCorners!),
          shownSize: shownSize,
          outputAspectWH: out == null ? null : aspectWH,
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
          photoIssue: _issue,
          photoChecked: _photoChecked,
          hintClosed: _hintClosed,
          shape: shape,
          shapeOverrides: Map.unmodifiable(_shapeOverrides),
        );

    if (!ellipse && _turns == 0 && ZQuadMath.isFullImage(corners)) {
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
      final warp = widget.warp ??
          (Uint8List b, List<Offset> c) => ZPerspectiveWarp.warpBytes(b, c,
              aspectWH: aspectWH, ellipse: ellipse, outsideFill: fill);
      final bytes = await warp(enhanced ?? widget.imageBytes, source);
      if (!mounted) return;
      widget.onContinue(result(bytes));
    } catch (_) {
      if (!mounted) return;
      final labels = widget.labels;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(labels.processErrorTitle),
          content: Text(labels.processErrorMessage),
          actions: [
            CupertinoDialogAction(
              child: Text(labels.processErrorOk),
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
          if (_issue != null && !_hintClosed)
            // Capped so the photo keeps its room on small phones with large
            // text: the hint's text scrolls, its buttons stay in view.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(
                  132.0,
                  MediaQuery.sizeOf(context).height * 0.3,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ZPhotoHintBanner(
                  theme: _theme,
                  labels: widget.hintLabels,
                  issue: _issue!,
                  onRetake: widget.onRetake == null || _applying
                      ? null
                      : widget.onRetake,
                  onUseAnyway: _closeHint,
                  onDismiss: _closeHint,
                ),
              ),
            ),
          Expanded(child: _buildCanvas()),
          Container(
            color: _theme.panelColor,
            padding: EdgeInsets.only(
              top: 4,
              bottom: 8 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The pill and the chips are separate rows of a column with
                // a fixed gap, each in a box of its own height: they cannot
                // overlap, whatever the text scale.
                if (_showShapeLabel && !_detecting) ...[
                  ZFrameShapeLabel(
                    theme: _theme,
                    labels: labels,
                    shape: _shape,
                    onWrong: _applying ? null : _openShapeMenu,
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  height: math.max(_theme.chipTapHeight, _theme.chipHeight),
                  child: _buildChips(labels),
                ),
                const SizedBox(height: 12),
                FrameToolRow(
                  theme: _theme,
                  children: [
                    if (widget.sizeTools)
                      ZToolButton(
                        key: const Key('z_frame_size'),
                        theme: _theme,
                        icon: _exactSize != null
                            ? ZLineIconKind.sizeConfirmed
                            : ZLineIconKind.sizeEstimated,
                        label: _sizeButtonLabel,
                        active: _exactSize != null,
                        toggled: _exactSize != null,
                        onTap:
                            _applying || _image == null ? null : _openSizeSheet,
                      ),
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
                    if (widget.onRetake != null)
                      ZToolButton(
                        key: const Key('z_frame_retake'),
                        theme: _theme,
                        icon: ZLineIconKind.camera,
                        label: labels.retakeLabel,
                        onTap: _applying ? null : widget.onRetake,
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
          Flexible(
            child: Text(labels.detectingLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _theme.text(color: _theme.mutedTextColor)),
          ),
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
        // Corner handles stay out of the system back-swipe areas at the
        // screen's left and right edges (and at least 24 px in).
        final insets = MediaQuery.systemGestureInsetsOf(context);
        final gesture = math.max(insets.left, insets.right);
        final padX = math.max(pad, math.max(24.0, gesture + 12));
        final area = Size(
          math.max(1, constraints.maxWidth - padX * 2),
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
        Offset toScreen(Offset c) => Offset(
              fitted.left + c.dx * fitted.width,
              fitted.top + c.dy * fitted.height,
            );
        final alternatives = <List<Offset>>[];
        final alternativeEllipses = <bool>[];
        for (var i = 0; i < _candidates.length; i++) {
          if (i == _base && !_edited) continue;
          alternatives.add([for (final c in _candidateCorners(i)) toScreen(c)]);
          final shape = _shapeOverrides[i] ?? _candidates[i].shape;
          alternativeEllipses.add(shape != ZFrameShape.rectangle);
        }
        final ellipse = _isEllipse;
        final handles = ellipse ? ZQuadMath.ellipseTouchPoints(pts) : pts;
        final outlineBounds = ellipse
            ? _boundsOf(ZQuadMath.inscribedEllipse(pts, segments: 48))
            : _boundsOf(pts);

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
                    ellipse: ellipse,
                    alternatives: alternatives,
                    alternativeEllipses: alternativeEllipses,
                    dragging: _dragCorner != null,
                    theme: _theme,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < 4; i++)
              Positioned(
                left: handles[i].dx - hit / 2,
                top: handles[i].dy - hit / 2,
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
            if (widget.sizeTools && _theme.showMeasurements)
              if (_shownSize case final shown?)
                Positioned.fill(
                  child: FrameMeasurementLines(
                    theme: _theme,
                    outline: outlineBounds,
                    bounds: Size(constraints.maxWidth, constraints.maxHeight),
                    heightLabel:
                        '${shown.isExact ? '' : '≈ '}${formatCm(shown.heightCm)} cm',
                    widthLabel:
                        '${shown.isExact ? '' : '≈ '}${formatCm(shown.widthCm)} cm',
                  ),
                ),
            if (widget.enableMagnifyingGlass && _dragCorner != null)
              _buildLoupe(image, fitted, pts, handles[_dragCorner!], ellipse,
                  constraints),
          ],
        );
      },
    );
  }

  Widget _buildLoupe(
    ui.Image image,
    Rect fitted,
    List<Offset> pts,
    Offset focus,
    bool ellipse,
    BoxConstraints constraints,
  ) {
    final diameter = _theme.loupeDiameter;
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
            ellipse: ellipse,
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
    final topPadding = kIsWeb ? 0.0 : MediaQuery.paddingOf(context).top;
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
            border: theme.handleRingColor == null
                ? null
                : Border.all(
                    color: theme.handleRingColor!,
                    width: theme.handleRingWidth,
                  ),
            boxShadow: [
              if (active)
                BoxShadow(color: theme.handleHaloColor, spreadRadius: 6)
              else
                const BoxShadow(
                  color: Color(0x66000000),
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

  /// The outline is the ellipse inscribed in [quad] (round / oval frame).
  final bool ellipse;

  /// The other detected outlines (screen coordinates), drawn dashed.
  final List<List<Offset>> alternatives;

  /// Per alternative: drawn as its inscribed ellipse.
  final List<bool> alternativeEllipses;
  final bool dragging;
  final ZImageEditorTheme theme;

  FrameQuadPainter({
    required this.image,
    required this.quarterTurns,
    required this.fitted,
    required this.quad,
    this.ellipse = false,
    this.alternatives = const [],
    this.alternativeEllipses = const [],
    required this.dragging,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintTurnedImage(
        canvas, image, quarterTurns, fitted, FilterQuality.medium);

    final quadPath = outlinePath(quad, ellipse);
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

    if (theme.showGrid && !ellipse) {
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

    final altColor = theme.alternativeOutlineColor;
    if (altColor != null) {
      final alt = Paint()
        ..color = altColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.alternativeOutlineWidth;
      for (var i = 0; i < alternatives.length; i++) {
        final round = i < alternativeEllipses.length && alternativeEllipses[i];
        drawDashedPath(canvas, outlinePath(alternatives[i], round), alt,
            dash: 4, gap: 3);
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
      old.alternatives.length != alternatives.length ||
      old.ellipse != ellipse ||
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
  final bool ellipse;
  final Offset focus;
  final ZImageEditorTheme theme;

  FrameLoupePainter({
    required this.image,
    required this.quarterTurns,
    required this.fitted,
    required this.quad,
    this.ellipse = false,
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
      outlinePath(quad, ellipse),
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

/// The outline of [quad]: the quad itself, or with [ellipse] the ellipse
/// inscribed in it.
Path outlinePath(List<Offset> quad, bool ellipse) => ellipse
    ? (Path()..addPolygon(ZQuadMath.inscribedEllipse(quad), true))
    : (Path()..addPolygon(quad, true));

Rect _boundsOf(List<Offset> pts) {
  var l = pts.first.dx, t = pts.first.dy, r = l, b = t;
  for (final p in pts) {
    l = math.min(l, p.dx);
    t = math.min(t, p.dy);
    r = math.max(r, p.dx);
    b = math.max(b, p.dy);
  }
  return Rect.fromLTRB(l, t, r, b);
}

bool _sameQuad(List<Offset> a, List<Offset> b) {
  for (var i = 0; i < 4; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
