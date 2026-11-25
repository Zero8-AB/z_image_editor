import 'dart:typed_data';
import 'dart:ui' show Offset;

/// Shape of a detected outline. For [round] and [oval] the outline is the
/// ellipse inscribed in the four corners (touching each side at its
/// middle, through the same perspective as the corners).
enum ZFrameShape { rectangle, round, oval }

/// What a detected outline is, when the detector knows it.
enum ZFrameLevel {
  /// Not said by the detector.
  unknown,

  /// The outer edge of a frame.
  frame,

  /// A level between the frame and the artwork (inner frame edge, mat
  /// window).
  inner,

  /// The artwork itself (the innermost level).
  artwork,
}

/// One outline the frame step can offer: four corners of a (possibly
/// perspective-distorted) rectangle in the photo, plus a label for its chip.
///
/// [corners] are **normalized** image coordinates (0..1 on both axes, relative
/// to the image as displayed, i.e. after EXIF orientation is applied), in the
/// order top-left, top-right, bottom-right, bottom-left.
class ZFrameCandidate {
  /// Four normalized corners: top-left, top-right, bottom-right, bottom-left.
  final List<Offset> corners;

  /// Chip label shown to the user, e.g. "With frame", "With mat", "Painting".
  final String label;

  /// Detector confidence (higher is better). Informational only; the editor
  /// keeps the order in which the detector returned the candidates.
  final double score;

  /// Whether this outline is selected when the frame step opens (and what
  /// Reset returns to). When no candidate sets it, the first one is used.
  final bool preselected;

  /// Shape of this outline. The outermost candidate's shape is shown as
  /// "Round frame found" / "Oval frame found"; each level keeps its own.
  final ZFrameShape shape;

  /// Which level this outline is (frame, inner, artwork), when known.
  final ZFrameLevel level;

  /// Whether a mat (a light, even band) lies between this outline and the
  /// next outer one, as seen by the detector.
  final bool matAround;

  ZFrameCandidate({
    required List<Offset> corners,
    required this.label,
    this.score = 0,
    this.preselected = false,
    this.shape = ZFrameShape.rectangle,
    this.level = ZFrameLevel.unknown,
    this.matAround = false,
  }) : corners = List.unmodifiable(corners) {
    if (corners.length != 4) {
      throw ArgumentError.value(
        corners.length,
        'corners',
        'A frame candidate needs exactly 4 corners',
      );
    }
  }

  @override
  String toString() => 'ZFrameCandidate($label, ${shape.name}, '
      '${level.name}${matAround ? ', mat' : ''}, score: $score, $corners)';
}

/// What the frame step saw in the photo, for guesses such as the artwork's
/// medium: cheap, from the detector's levels and the reflection fix.
class ZFrameEvidence {
  /// A frame was found around the artwork.
  final bool hasFrame;

  /// A mat (light, even band) lies between the frame and the artwork.
  final bool hasMat;

  /// Reflections (glass) were found: the enhancer had something to remove
  /// or the photo check reported glare.
  final bool glassReflections;

  /// Shape of the outermost outline (after a "Wrong?" correction).
  final ZFrameShape shape;

  const ZFrameEvidence({
    required this.hasFrame,
    this.hasMat = false,
    this.glassReflections = false,
    this.shape = ZFrameShape.rectangle,
  });

  /// Reads the evidence from the detector's [candidates]. Without levels
  /// from the detector, two or more nested outlines count as a frame.
  /// [shapeOverrides] are the shapes picked with "Wrong?", by candidate
  /// index.
  factory ZFrameEvidence.fromCandidates(
    List<ZFrameCandidate> candidates, {
    bool glassReflections = false,
    Map<int, ZFrameShape> shapeOverrides = const {},
  }) {
    final knowsLevels = candidates.any((c) => c.level != ZFrameLevel.unknown);
    final hasFrame = knowsLevels
        ? candidates.any((c) => c.level == ZFrameLevel.frame)
        : candidates.length >= 2;
    var outer = -1;
    var area = -1.0;
    for (var i = 0; i < candidates.length; i++) {
      final a = _area(candidates[i].corners);
      if (a > area) {
        area = a;
        outer = i;
      }
    }
    return ZFrameEvidence(
      hasFrame: hasFrame,
      hasMat: hasFrame && candidates.any((c) => c.matAround),
      glassReflections: glassReflections,
      shape: outer < 0
          ? ZFrameShape.rectangle
          : shapeOverrides[outer] ?? candidates[outer].shape,
    );
  }

  static double _area(List<Offset> q) {
    var s = 0.0;
    for (var i = 0; i < q.length; i++) {
      final a = q[i], b = q[(i + 1) % q.length];
      s += a.dx * b.dy - b.dx * a.dy;
    }
    return s.abs() / 2;
  }

  @override
  bool operator ==(Object other) =>
      other is ZFrameEvidence &&
      other.hasFrame == hasFrame &&
      other.hasMat == hasMat &&
      other.glassReflections == glassReflections &&
      other.shape == shape;

  @override
  int get hashCode => Object.hash(hasFrame, hasMat, glassReflections, shape);

  @override
  String toString() => 'ZFrameEvidence(frame: $hasFrame, mat: $hasMat, '
      'glass: $glassReflections, ${shape.name})';
}

/// Finds candidate outlines (frame, mat window, artwork, ...) in a photo.
///
/// The package ships no implementation, so it stays free of native
/// dependencies: apps plug in their own (for example an OpenCV contour
/// detector) and pass it to `ZImageEditor.frameDetector`.
///
/// The editor shows the candidates as chips **in the returned order** (at
/// most three) and pre-selects the one marked [ZFrameCandidate.preselected],
/// else the first.
/// Return an empty list when nothing reliable was found; the user then drags
/// the corners by hand. Errors thrown here are caught and treated as "nothing
/// found".
abstract class ZFrameDetector {
  const ZFrameDetector();

  /// Detects candidate outlines in [imageBytes] (the encoded image, e.g.
  /// JPEG/PNG, exactly as passed to the editor).
  Future<List<ZFrameCandidate>> detect(Uint8List imageBytes);
}

/// Optional one-tap image fix offered in the frame step, e.g. reflection
/// (glare) removal. Shown as a toggle that is on by default; the step keeps
/// the original and the fixed version and switches between them instantly.
///
/// Like [ZFrameDetector] the package ships no implementation (no native
/// dependencies); the app provides one.
abstract class ZImageEnhancer {
  const ZImageEnhancer();

  /// Tool-row label while the fix is on, e.g. "No reflections".
  String get label;

  /// Tool-row label while the fix is off, e.g. "Reflections shown".
  String get offLabel => label;

  /// Returns the fixed image (encoded, e.g. JPEG/PNG), or null when there is
  /// nothing worth fixing; the toggle is then hidden.
  ///
  /// The result must have the same aspect ratio and orientation as [imageBytes]
  /// as displayed (EXIF orientation applied), because the frame outline is
  /// shared between both versions. Errors are treated as "nothing to fix".
  Future<Uint8List?> apply(Uint8List imageBytes);
}

/// Texts of the frame step (and of the editor header when the frame step is
/// enabled). All have English defaults.
class ZFrameCropLabels {
  /// Screen title of the frame step (shown when the theme shows titles).
  final String title;

  /// Screen title of the editor after the frame step.
  final String editorTitle;

  /// Button that applies the outline and continues to the regular editor.
  final String continueLabel;

  /// Editor header button that goes back to the frame step.
  final String backToFrameLabel;

  /// Tool that keeps the whole photo (no perspective crop).
  final String fullPhotoLabel;

  /// Tool that turns the photo a quarter turn clockwise.
  final String rotateLabel;

  /// Tool that closes the frame step to take a new photo (shown only when
  /// the editor has an `onRetake`).
  final String retake;

  /// Appended to the selected chip once its corners were dragged.
  final String editedSuffix;

  /// Shown while the detector runs.
  final String detectingLabel;

  /// Shown when the detector found nothing (or none is set).
  final String manualHint;

  /// Appended to an estimated size on the Size tool ("≈ 50 × 40 cm · Check").
  final String sizeCheckSuffix;

  /// Size tool label when no size can be estimated.
  final String sizeUnknownLabel;

  /// Shape label when the outline is round / oval / a rectangle (the
  /// rectangle text only appears after "Wrong?" changed a round shape).
  final String roundFoundLabel;
  final String ovalFoundLabel;
  final String rectangleShapeLabel;

  /// Link next to the shape label that opens the shape menu.
  final String wrongShapeLabel;

  /// Title and options of the shape menu.
  final String shapeMenuTitle;
  final String shapeRectangle;
  final String shapeRound;
  final String shapeOval;

  /// Dialog shown when Next can't produce the cropped image.
  final String processErrorTitle;
  final String processErrorMessage;
  final String processErrorOk;

  const ZFrameCropLabels({
    this.title = 'Choose the frame',
    this.editorTitle = 'Edit photo',
    this.continueLabel = 'Next',
    this.backToFrameLabel = 'Frame',
    this.fullPhotoLabel = 'Full photo',
    this.rotateLabel = 'Rotate',
    this.retake = 'Retake',
    this.editedSuffix = ' · edited',
    this.detectingLabel = 'Finding the edges…',
    this.manualHint = 'Drag the corners to the edges you want to keep.',
    this.sizeCheckSuffix = ' · Check',
    this.sizeUnknownLabel = 'Size · Check',
    this.roundFoundLabel = 'Round frame found',
    this.ovalFoundLabel = 'Oval frame found',
    this.rectangleShapeLabel = 'Rectangle',
    this.wrongShapeLabel = 'Wrong?',
    this.shapeMenuTitle = 'Shape of the frame',
    this.shapeRectangle = 'Rectangle',
    this.shapeRound = 'Round',
    this.shapeOval = 'Oval',
    this.processErrorTitle = 'Error',
    this.processErrorMessage = 'Failed to process image',
    this.processErrorOk = 'OK',
  });
}
