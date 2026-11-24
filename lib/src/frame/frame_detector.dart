import 'dart:typed_data';
import 'dart:ui' show Offset;

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

  ZFrameCandidate({
    required List<Offset> corners,
    required this.label,
    this.score = 0,
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
  String toString() => 'ZFrameCandidate($label, score: $score, $corners)';
}

/// Finds candidate outlines (frame, mat window, artwork, ...) in a photo.
///
/// The package ships no implementation, so it stays free of native
/// dependencies: apps plug in their own (for example an OpenCV contour
/// detector) and pass it to `ZImageEditor.frameDetector`.
///
/// The editor shows the candidates as chips **in the returned order** and
/// pre-selects the first one, so return the preferred outline first.
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

  /// Appended to the selected chip once its corners were dragged.
  final String editedSuffix;

  /// Shown while the detector runs.
  final String detectingLabel;

  /// Shown when the detector found nothing (or none is set).
  final String manualHint;

  const ZFrameCropLabels({
    this.title = 'Choose the frame',
    this.editorTitle = 'Edit photo',
    this.continueLabel = 'Next',
    this.backToFrameLabel = 'Frame',
    this.fullPhotoLabel = 'Full photo',
    this.rotateLabel = 'Rotate',
    this.editedSuffix = ' · edited',
    this.detectingLabel = 'Finding the edges…',
    this.manualHint = 'Drag the corners to the edges you want to keep.',
  });
}
