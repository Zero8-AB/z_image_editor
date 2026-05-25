/// Controls how the editor encodes the output image when the user presses Done.
///
/// ## Adding new formats
///
/// To add a new format in the future (e.g. WebP):
/// 1. Add a new value to this enum.
/// 2. Add magic-byte detection in `ImageProcessing._detectInputFormat` so that
///    [original] mode can detect the new format from input bytes.
/// 3. Add an encode branch for the new format in
///    `ImageProcessing._renderWysiwygToBytes`,
///    `ImageProcessing._processImageFallbackToBytes`, and
///    `ImageProcessing._processImageFallbackFromBytes`.
enum ImageOutputFormat {
  /// Return the original bytes/file unchanged when no edits have been applied.
  /// Re-encode as PNG when edits are applied.
  ///
  /// This is the default and gives the best performance for unmodified images
  /// while still producing a reliable PNG when the image has been changed.
  auto,

  /// Always re-encode the output as PNG, regardless of whether the image was
  /// modified.
  png,

  /// Always re-encode the output as JPEG, regardless of whether the image was
  /// modified.
  jpeg,

  /// Preserve the original image format where possible.
  ///
  /// Returns the original bytes/file unchanged when no edits have been applied.
  ///
  /// When edits are applied the original format is detected from the input
  /// bytes' magic-byte signature:
  /// - JPEG (`FF D8`) → re-encoded as JPEG
  /// - Anything else (PNG, WebP, HEIC, etc.) → re-encoded as PNG
  ///
  /// **Note:** WebP and HEIC inputs that have been edited will be output as PNG
  /// because the underlying `image` package does not currently support encoding
  /// those formats. The original bytes are still returned unchanged when no
  /// edits are applied. Support for more formats can be added in the future —
  /// see the class-level doc comment above.
  original,
}
