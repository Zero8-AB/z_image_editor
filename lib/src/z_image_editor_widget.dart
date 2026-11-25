import 'dart:math' as math;
import 'dart:io'
    if (dart.library.html) 'package:z_image_editor/src/utils/platform_io_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:z_image_editor/src/controller/image_editor_controller.dart';
import 'package:z_image_editor/src/frame/artwork_size.dart';
import 'package:z_image_editor/src/frame/frame_crop_view.dart';
import 'package:z_image_editor/src/frame/size_sheet.dart';
import 'package:z_image_editor/src/frame/photo_hint_banner.dart';
import 'package:z_image_editor/src/frame/photo_quality.dart';
import 'package:z_image_editor/src/utils/auto_levels.dart';
import 'package:z_image_editor/src/widgets/themed_adjust_controls.dart';
import 'package:z_image_editor/src/frame/frame_detector.dart';
import 'package:z_image_editor/src/models/adjust_tab_settings.dart';
import 'package:z_image_editor/src/models/crop_tab_settings.dart';
import 'package:z_image_editor/src/models/crop_toolbar_settings.dart';
import 'package:z_image_editor/src/models/image_editor_state.dart';
import 'package:z_image_editor/src/models/image_output_format.dart';
import 'package:z_image_editor/src/theme/themed_controls.dart';
import 'package:z_image_editor/src/theme/z_image_editor_theme.dart';
import 'package:z_image_editor/src/utils/image_format_sniffer.dart';
import 'package:z_image_editor/src/utils/image_processing.dart';
import 'package:z_image_editor/src/widgets/adjustment_controls.dart';
import 'package:z_image_editor/src/widgets/crop_controls.dart';
import 'package:z_image_editor/src/widgets/image_canvas.dart';
import 'package:z_image_editor/src/widgets/web_editor_shell.dart';

/// iOS-style image editor widget
class ZImageEditor extends StatefulWidget {
  /// Images to edit, provided as files. Exactly one of [imageFiles] or
  /// [imageBytesList] must be provided.
  final List<File>? imageFiles;

  /// Images to edit, provided as raw bytes. Exactly one of [imageFiles] or
  /// [imageBytesList] must be provided.
  final List<Uint8List>? imageBytesList;

  /// Called with the full list of edited files once every image has been saved.
  /// A single-image session produces a one-element list.
  ///
  /// Used on mobile. On web, provide [onSaveAllBytes] instead.
  final Function(List<File> editedImages)? onSaveAll;

  /// Web equivalent of [onSaveAll]. Called with PNG bytes for each edited
  /// image. Required on web; ignored on mobile.
  final Function(List<Uint8List> editedBytes)? onSaveAllBytes;

  final VoidCallback onCancel;

  /// Whether to show a magnifying glass when dragging crop handles.
  /// Defaults to false.
  final bool enableMagnifyingGlass;

  /// Label for the cancel button. Defaults to 'Cancel'.
  final String cancelLabel;

  /// Label for the reset button. Defaults to 'Reset'.
  final String resetLabel;

  /// Label for the save/done button on the final (or only) image.
  /// Defaults to 'Done'.
  final String doneLabel;

  /// Label for the "advance to next image" button shown on all images except
  /// the last one when editing multiple images. Defaults to 'Next'.
  final String nextLabel;

  /// Whether to show the crop toolbar (rotate, flip, aspect ratio).
  /// Defaults to `true`.
  final bool showCropToolbar;

  /// Fine-grained control over which buttons appear in the crop toolbar.
  /// Only relevant when [showCropToolbar] is `true`.
  final CropToolbarSettings cropToolbarSettings;

  /// Whether to show the Crop tab. Defaults to `true`.
  final bool showCropTab;

  /// Fine-grained control over which badges appear in the Crop tab ruler.
  /// Only relevant when [showCropTab] is `true`.
  final CropTabSettings cropTabSettings;

  /// Whether to show the Adjust tab. Defaults to `true`.
  final bool showAdjustTab;

  /// Fine-grained control over which badges appear in the Adjust tab ruler.
  /// Only relevant when [showAdjustTab] is `true`.
  final AdjustTabSettings adjustTabSettings;

  /// Controls how the output image is encoded when the user presses Done.
  ///
  /// - [ImageOutputFormat.auto] *(default)*: skip re-encoding entirely when no
  ///   edits have been applied (fastest for unmodified images). Re-encodes as
  ///   PNG when edits are present.
  /// - [ImageOutputFormat.png]: always re-encode as PNG.
  /// - [ImageOutputFormat.jpeg]: always re-encode as JPEG.
  /// - [ImageOutputFormat.original]: preserve the original format. Skips
  ///   re-encoding when no edits have been applied; otherwise detects the
  ///   input format from magic bytes and re-encodes to match.
  final ImageOutputFormat outputFormat;

  /// Finds candidate outlines (frame, mat, artwork, ...) for the perspective
  /// "frame" step. Setting it opens the editor in that step first, with the
  /// candidates as chips. The package ships no detector; see
  /// [ZFrameDetector].
  final ZFrameDetector? frameDetector;

  /// Whether to open each image in the perspective "frame" step first.
  /// Defaults to `true` when [frameDetector] is set, `false` otherwise (the
  /// editor then behaves exactly as without this feature). Set it to `true`
  /// without a detector for a manual four-corner crop.
  final bool? startWithFrameCrop;

  /// Optional one-tap fix (e.g. reflection removal) offered as a toggle in the
  /// frame step, on by default. Only used when the frame step is shown.
  final ZImageEnhancer? imageEnhancer;

  /// Texts of the frame step.
  final ZFrameCropLabels frameCropLabels;

  /// Show the artwork-size tools in the frame step: the Size button, red
  /// measurement lines (with [ZImageEditorTheme.showMeasurements]) and the
  /// size sheet; the straightened image then keeps the real shape.
  final bool enableSizeTools;

  /// Size known up front (artwork details, or measured). Exact sizes are
  /// shown without "≈" and give the straightened image its shape. A
  /// measured size belongs to the pre-selected outline (other outlines are
  /// scaled from it, "≈"); one from the details to whichever outline its
  /// shape fits.
  final ZArtworkSize? artworkSize;

  /// Called (on Next) when the user confirmed a size in the size sheet and
  /// kept the outline it was confirmed for. On another outline of the same
  /// object only [onArtworkSize] is called, with the size scaled to it.
  final ValueChanged<ZArtworkSize>? onArtworkSizeConfirmed;

  /// Called on Next in the frame step with the size the step shows, whatever
  /// its source: exact (details, measured, confirmed) or the "≈" estimate
  /// ([ZSizeSource.estimated], no depth). E.g. to fill a form's empty size
  /// fields. Not called when no size is shown (size tools off, or nothing to
  /// estimate from).
  final ValueChanged<ZArtworkSize>? onArtworkSize;

  /// Called on Next in the frame step with what the step saw in the photo
  /// (frame, mat, glass reflections, shape), e.g. to suggest a medium. Not
  /// called when the detector did not run or found no outline.
  final ValueChanged<ZFrameEvidence>? onFrameEvidence;

  /// Texts of the size sheet.
  final ZSizeSheetLabels sizeSheetLabels;

  /// Checks the photo in the frame step and shows at most one calm hint
  /// (reflection, blur, darkness, cut-off frame); e.g. [ZPhotoQuality].
  final ZPhotoChecker? photoChecker;

  /// Texts of the photo hints.
  final ZPhotoHintLabels photoHintLabels;

  /// "Retake" in a photo hint: the app closes the editor and takes a new
  /// photo. Null hides Retake (Use anyway and the cross remain).
  final VoidCallback? onRetake;

  /// Offer "Auto" (black/white stretch, white balance from the white mat,
  /// mild contrast) first in the Adjust tab of the themed look
  /// ([ZImageEditorTheme.toolRowTabs]). It turns itself on when the photo
  /// looks hazy; one tap turns it off. Part of the export.
  final bool enableAutoFix;

  /// Texts of the themed Adjust tab and the Before/After compare.
  final ZAutoFixLabels autoFixLabels;

  /// Draw edge to edge: the status and navigation bars stay visible and
  /// transparent over the editor's dark background (light icons); the
  /// controls keep to the safe area. When false (the default) the status
  /// bar is hidden while the editor is open, as before.
  final bool edgeToEdge;

  /// Orientations to restore when the editor closes (it locks itself to
  /// portrait while open). The default `[]` allows every orientation;
  /// portrait-only apps pass `[DeviceOrientation.portraitUp]`.
  final List<DeviceOrientation> orientationsAfterClose;

  /// Round / oval frames: outside the ellipse is transparent, except when
  /// [outputFormat] is JPEG (no alpha), where it is filled with this.
  final Color roundFrameFill;

  /// Colours, fonts and sizes of the editor chrome and the frame step.
  /// The default reproduces the original look.
  final ZImageEditorTheme theme;

  const ZImageEditor({
    super.key,
    this.imageFiles,
    this.imageBytesList,
    this.onSaveAll,
    this.onSaveAllBytes,
    required this.onCancel,
    this.enableMagnifyingGlass = false,
    this.cancelLabel = 'Cancel',
    this.resetLabel = 'Reset',
    this.doneLabel = 'Done',
    this.nextLabel = 'Next',
    this.showCropToolbar = true,
    this.cropToolbarSettings = const CropToolbarSettings(),
    this.showCropTab = true,
    this.cropTabSettings = const CropTabSettings(),
    this.showAdjustTab = true,
    this.adjustTabSettings = const AdjustTabSettings(),
    this.outputFormat = ImageOutputFormat.auto,
    this.frameDetector,
    this.startWithFrameCrop,
    this.imageEnhancer,
    this.frameCropLabels = const ZFrameCropLabels(),
    this.theme = const ZImageEditorTheme(),
    this.enableSizeTools = false,
    this.artworkSize,
    this.onArtworkSizeConfirmed,
    this.onArtworkSize,
    this.onFrameEvidence,
    this.sizeSheetLabels = const ZSizeSheetLabels(),
    this.photoChecker,
    this.photoHintLabels = const ZPhotoHintLabels(),
    this.onRetake,
    this.enableAutoFix = false,
    this.autoFixLabels = const ZAutoFixLabels(),
    this.roundFrameFill = const Color(0xFFF5F0F0),
    this.edgeToEdge = false,
    this.orientationsAfterClose = const [],
  })  : assert(
          imageFiles != null || imageBytesList != null,
          'Provide imageFiles or imageBytesList.',
        ),
        assert(
          kIsWeb ? onSaveAllBytes != null : onSaveAll != null,
          kIsWeb
              ? 'Provide onSaveAllBytes on web.'
              : 'Provide onSaveAll on mobile.',
        );

  @override
  State<ZImageEditor> createState() => _ZImageEditorState();
}

class _ZImageEditorState extends State<ZImageEditor> {
  bool _isSaving = false;
  bool _showingAspectRatioPicker = false;
  bool _isCropPortrait = false;
  late ImageEditorController _controller;
  OverlayEntry? _editMenuOverlay;

  // ── Multi-image state ─────────────────────────────────────────────────────

  int _currentIndex = 0;

  // ── Auto fix ─────────────────────────────────────────────────────────────
  /// Auto levels for the current image (null: none / not analysed yet).
  ZAutoLevels? _autoFix;
  bool _autoForHaze = false;
  int _autoToken = 0;
  ZAdjustPanel _adjustPanel = ZAdjustPanel.brightness;

  /// Images on which the user turned Auto off (it then stays off).
  final Set<int> _autoOffByUser = {};
  final List<File> _processedImages = [];
  // Web: accumulates PNG bytes across multi-image sessions.
  final List<Uint8List> _processedImageBytes = [];

  int get _totalImages =>
      widget.imageFiles?.length ?? widget.imageBytesList?.length ?? 1;

  bool get _isLastImage => _currentIndex >= _totalImages - 1;

  // ── Frame (perspective) step state ───────────────────────────────────────

  bool get _frameCropEnabled =>
      widget.startWithFrameCrop ?? widget.frameDetector != null;

  /// Whether the current image is shown in the frame step.
  bool _inFrameStep = false;

  /// Whether the frame step was reopened from the editor (Cancel then returns
  /// to the editor instead of closing it).
  bool _frameReopened = false;

  /// Original bytes of the current image, loaded for the frame step.
  Future<Uint8List>? _frameSourceBytes;

  /// Rectified image per index, replacing the original in the editor.
  final Map<int, Uint8List> _frameOutputs = {};

  /// Last frame-step result per index, so reopening restores it.
  final Map<int, FrameCropResult> _frameResults = {};

  File? get _currentImageFile => _frameOutputs.containsKey(_currentIndex)
      ? null
      : widget.imageFiles?[_currentIndex];

  Uint8List? get _currentImageBytes =>
      _frameOutputs[_currentIndex] ?? widget.imageBytesList?[_currentIndex];

  void _enterFrameStep({bool reopened = false}) {
    _dismissEditMenu();
    _frameReopened = reopened;
    final index = _currentIndex;
    final bytes = widget.imageBytesList?[index];
    _frameSourceBytes = bytes != null
        ? Future.value(bytes)
        : widget.imageFiles![index].readAsBytes();
    _inFrameStep = true;
  }

  void _onFrameContinue(FrameCropResult result) {
    final previous = _frameResults[_currentIndex];
    final size = result.size;
    if (size != null &&
        size.source == ZSizeSource.confirmed &&
        size != previous?.size) {
      widget.onArtworkSizeConfirmed?.call(size);
    }
    final shown = result.shownSize;
    if (shown != null) widget.onArtworkSize?.call(shown);
    final evidence = result.evidence;
    if (evidence != null) widget.onFrameEvidence?.call(evidence);
    // Reopened and nothing changed: keep the editor's crop/adjust edits.
    final unchanged = _frameReopened &&
        previous != null &&
        previous.quarterTurns == result.quarterTurns &&
        previous.enhanceOn == result.enhanceOn &&
        previous.shape == result.shape &&
        _sameAspect(previous.outputAspectWH, result.outputAspectWH) &&
        _sameCorners(previous.corners, result.corners);
    if (unchanged) {
      setState(() {
        _frameResults[_currentIndex] = result;
        _inFrameStep = false;
      });
      return;
    }
    // The image changed: crop/rotation no longer apply, but keep the colour
    // adjustments.
    final kept = _controller.state;
    setState(() {
      _frameResults[_currentIndex] = result;
      final warped = result.outputBytes;
      if (warped != null) {
        _frameOutputs[_currentIndex] = warped;
      } else {
        _frameOutputs.remove(_currentIndex);
      }
      _inFrameStep = false;
      _isCropPortrait = false;
      _showingAspectRatioPicker = false;
    });
    _controller.initialize(
      imageFile: _currentImageFile,
      imageBytes: _currentImageBytes,
    );
    if (_frameReopened) {
      _controller.setBrightness(kept.brightness);
      _controller.setContrast(kept.contrast);
      _controller.setSaturation(kept.saturation);
    }
    _analyzeAuto(keepOn: _frameReopened && kept.autoLevels != null);
    if (!widget.showCropTab && widget.showAdjustTab) {
      _controller.setTab(EditorTab.adjust);
    }
  }

  /// Analyses the current image for Auto; turns it on when the photo looks
  /// hazy (unless the user turned it off on this image) or when [keepOn].
  Future<void> _analyzeAuto({bool keepOn = false}) async {
    if (!widget.enableAutoFix) return;
    final token = ++_autoToken;
    final index = _currentIndex;
    // Callers rebuild anyway (also called from initState: no setState).
    _autoFix = null;
    _autoForHaze = false;
    Uint8List? bytes = _currentImageBytes;
    try {
      bytes ??= await _currentImageFile?.readAsBytes();
    } catch (_) {
      bytes = null;
    }
    final fix = bytes == null ? null : await ZAutoLevels.fromBytes(bytes);
    if (!mounted || token != _autoToken || index != _currentIndex) return;
    if (fix == null || fix.isNoop) return;
    final turnOn = keepOn || (fix.hazy && !_autoOffByUser.contains(index));
    setState(() {
      _autoFix = fix;
      if (turnOn) {
        _autoForHaze = !keepOn;
        _adjustPanel = ZAdjustPanel.auto;
      }
    });
    if (turnOn) _controller.setAutoLevels(fix.values, undoable: false);
  }

  /// Same output shape (a size changed in the reopened step changes it).
  static bool _sameAspect(double? a, double? b) {
    if (a == null || b == null) return a == b;
    return (a - b).abs() < 1e-6;
  }

  static bool _sameCorners(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).distance > 1e-6) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();

    // Runtime API validation (asserts are stripped in release builds).
    if (kIsWeb) {
      if (widget.onSaveAllBytes == null) {
        throw ArgumentError('ZImageEditor: onSaveAllBytes is required on web.');
      }
      if (widget.imageBytesList == null) {
        throw ArgumentError('ZImageEditor: imageBytesList is required on web. '
            'Use imageBytesList instead of imageFiles.');
      }
      if (widget.imageFiles != null) {
        throw ArgumentError(
          'ZImageEditor: imageFiles is not supported on web. '
          'Use imageBytesList instead.',
        );
      }
    } else {
      if (widget.onSaveAll == null) {
        throw ArgumentError('ZImageEditor: onSaveAll is required on mobile.');
      }
    }

    _controller = ImageEditorController();
    _controller.initialize(
      imageFile: _currentImageFile,
      imageBytes: _currentImageBytes,
    );
    // Default to the first visible tab.
    if (!widget.showCropTab && widget.showAdjustTab) {
      _controller.setTab(EditorTab.adjust);
    }
    if (_frameCropEnabled) {
      _enterFrameStep();
    } else {
      _analyzeAuto();
    }
    if (!kIsWeb) {
      if (widget.edgeToEdge) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.bottom],
        );
      }
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  void dispose() {
    _editMenuOverlay?.remove();
    if (!kIsWeb) {
      if (widget.edgeToEdge) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      }
      SystemChrome.setPreferredOrientations(widget.orientationsAfterClose);
    }
    _controller.dispose();
    _showingAspectRatioPicker = false;
    super.dispose();
  }

  /// In batch mode (mobile), save the current image, store it, and load the next.
  Future<void> _advanceToNextImage(File processedFile) async {
    _processedImages.add(processedFile);
    setState(() {
      _currentIndex++;
      _isCropPortrait = false;
      _showingAspectRatioPicker = false;
    });
    _dismissEditMenu();
    _controller.initialize(
      imageFile: _currentImageFile,
      imageBytes: _currentImageBytes,
    );
    if (!widget.showCropTab && widget.showAdjustTab) {
      _controller.setTab(EditorTab.adjust);
    }
    if (_frameCropEnabled) {
      setState(_enterFrameStep);
    } else {
      _analyzeAuto();
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (kIsWeb) {
        await _handleSaveWeb();
      } else {
        await _handleSaveMobile();
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
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
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSaveMobile() async {
    final state = _controller.state;
    final currentFile = _currentImageFile;
    final currentBytes = _currentImageBytes;
    final outputFormat = widget.outputFormat;

    File processedFile;

    // For auto/original formats, skip re-encoding entirely when the image
    // has not been modified — return the original source directly.
    final skipConversion = !state.hasChanges &&
        (outputFormat == ImageOutputFormat.auto ||
            outputFormat == ImageOutputFormat.original);

    if (skipConversion && (currentFile != null || currentBytes != null)) {
      // Unmodified: hand back a byte-identical copy in a new temp file with
      // the right extension, never the caller's own File.
      final bytes = currentBytes ?? await currentFile!.readAsBytes();
      processedFile = await _writeUnmodifiedCopy(bytes, currentFile?.path);
    } else if (currentFile != null) {
      processedFile = await ImageProcessing.processImage(
        originalFile: currentFile,
        state: state,
        outputFormat: outputFormat,
      );
    } else if (currentBytes != null) {
      processedFile = await ImageProcessing.processImageFromBytes(
        bytes: currentBytes,
        state: state,
        outputFormat: outputFormat,
      );
    } else {
      return;
    }

    if (_isLastImage) {
      _processedImages.add(processedFile);
      widget.onSaveAll!(_processedImages);
    } else {
      await _advanceToNextImage(processedFile);
    }
  }

  /// Writes [bytes] unchanged to a new temp file named after their format
  /// (magic bytes; falls back to [originalPath]'s extension, then `img`).
  Future<File> _writeUnmodifiedCopy(
      Uint8List bytes, String? originalPath) async {
    var ext = imageExtensionFromBytes(bytes);
    if (ext == null && originalPath != null) {
      final dot = originalPath.lastIndexOf('.');
      final slash = originalPath.lastIndexOf('/');
      if (dot > slash && dot < originalPath.length - 1) {
        ext = originalPath.substring(dot + 1).toLowerCase();
      }
    }
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final file =
        File('${Directory.systemTemp.path}/edited_$timestamp.${ext ?? 'img'}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _handleSaveWeb() async {
    final state = _controller.state;
    final currentBytes = _currentImageBytes;
    if (currentBytes == null) return;
    final outputFormat = widget.outputFormat;

    final Uint8List outputBytes;

    // For auto/original formats, skip re-encoding entirely when the image
    // has not been modified — return the original bytes directly.
    final skipConversion = !state.hasChanges &&
        (outputFormat == ImageOutputFormat.auto ||
            outputFormat == ImageOutputFormat.original);

    if (skipConversion) {
      outputBytes = currentBytes;
    } else {
      outputBytes = await ImageProcessing.processImageToBytes(
        bytes: currentBytes,
        state: state,
        outputFormat: outputFormat,
      );
    }

    if (_isLastImage) {
      _processedImageBytes.add(outputBytes);
      widget.onSaveAllBytes!(_processedImageBytes);
    } else {
      _processedImageBytes.add(outputBytes);
      setState(() {
        _currentIndex++;
        _isCropPortrait = false;
        _showingAspectRatioPicker = false;
      });
      _dismissEditMenu();
      _controller.initialize(imageBytes: _currentImageBytes);
      if (!widget.showCropTab && widget.showAdjustTab) {
        _controller.setTab(EditorTab.adjust);
      }
      if (_frameCropEnabled) setState(_enterFrameStep);
    }
  }

  Widget _buildFrameStep() {
    final previous = _frameResults[_currentIndex];
    return FutureBuilder<Uint8List>(
      // Keyed by index so a new image gets a fresh step.
      key: ValueKey('z_frame_step_$_currentIndex'),
      future: _frameSourceBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (snapshot.hasError) {
          return _FrameLoadError(
            theme: widget.theme,
            cancelLabel: widget.cancelLabel,
            onCancel: _frameReopened
                ? () => setState(() => _inFrameStep = false)
                : widget.onCancel,
          );
        }
        if (bytes == null) {
          return const Material(
            color: Colors.black,
            child: Center(
              child: CupertinoActivityIndicator(color: Colors.white),
            ),
          );
        }
        return FrameCropView(
          imageBytes: bytes,
          detector: widget.frameDetector,
          enhancer: widget.imageEnhancer,
          labels: widget.frameCropLabels,
          theme: widget.theme,
          cancelLabel: widget.cancelLabel,
          resetLabel: widget.resetLabel,
          enableMagnifyingGlass: true,
          previous: previous,
          sizeTools: widget.enableSizeTools,
          knownSize: widget.artworkSize,
          sizeLabels: widget.sizeSheetLabels,
          photoChecker: widget.photoChecker,
          hintLabels: widget.photoHintLabels,
          onRetake: widget.onRetake,
          outsideFill: widget.outputFormat == ImageOutputFormat.jpeg
              ? widget.roundFrameFill
              : null,
          onCancel: _frameReopened
              ? () => setState(() => _inFrameStep = false)
              : widget.onCancel,
          onContinue: _onFrameContinue,
        );
      },
    );
  }

  /// Side margin that keeps handles out of the system gesture areas.
  double get _gestureSafeMargin {
    final insets = MediaQuery.of(context).systemGestureInsets;
    return math.max(24.0, math.max(insets.left, insets.right) + 12);
  }

  /// Bars over the dark editor in [ZImageEditor.edgeToEdge]: transparent,
  /// light icons.
  static const SystemUiOverlayStyle edgeToEdgeStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0x00000000),
    systemNavigationBarDividerColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    if (!widget.edgeToEdge || kIsWeb) return body;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: edgeToEdgeStyle,
      child: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_inFrameStep) {
      final step = _buildFrameStep();
      return kIsWeb ? WebEditorShell(child: step) : step;
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final state = _controller.state;

        final editorContent = Material(
          color: widget.theme.backgroundColor,
          child: Column(
            children: [
              _buildHeader(context, state),

              Expanded(
                child: Padding(
                  // Edge to edge: crop handles stay out of the system
                  // back-swipe areas (and at least 24 px in).
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.edgeToEdge ? _gestureSafeMargin : 0,
                  ),
                  child: ImageCanvas(
                    imageFile: _currentImageFile,
                    imageBytes: _currentImageBytes,
                    controller: _controller,
                    enableMagnifyingGlass: widget.enableMagnifyingGlass,
                    portraitOrientation: _isCropPortrait,
                    showCompare: widget.theme.toolRowTabs &&
                        _adjustPanel == ZAdjustPanel.auto,
                    beforeLabel: widget.autoFixLabels.before,
                    afterLabel: widget.autoFixLabels.after,
                    fontFamily: widget.theme.fontFamily,
                  ),
                ),
              ),

              // Bottom controls
              Container(
                color: widget.theme.panelColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tool-specific controls — constrained width on web
                    if (kIsWeb)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: _buildToolControls(state),
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          child: _buildToolControls(state),
                        ),
                      ),
                    _buildTabSelector(context, state),
                  ],
                ),
              ),
            ],
          ),
        );

        if (kIsWeb) {
          return WebEditorShell(child: editorContent);
        }
        return editorContent;
      },
    );
  }

  /// Cancel (or "‹ Frame" back to the frame step), optional title, and
  /// Done/Next.
  Widget _buildHeaderButtons({required bool web}) {
    final t = widget.theme;
    final backToFrame = _frameCropEnabled;
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ZSecondaryButton(
          key: const Key('z_editor_cancel'),
          theme: t,
          label: backToFrame
              ? widget.frameCropLabels.backToFrameLabel
              : widget.cancelLabel,
          showBackChevron: backToFrame,
          onPressed: _isSaving
              ? null
              : backToFrame
                  ? () => setState(() => _enterFrameStep(reopened: true))
                  : widget.onCancel,
        ),
        if (web && _totalImages > 1 && !t.showTitle)
          Text(
            '${_currentIndex + 1} / $_totalImages',
            style: t.text(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ZPrimaryButton(
          key: const Key('z_editor_done'),
          theme: t,
          busy: _isSaving,
          label: _totalImages > 1 && !_isLastImage
              ? widget.nextLabel
              : widget.doneLabel,
          onPressed: _isSaving ? null : _handleSave,
        ),
      ],
    );
    if (!t.showTitle) return row;
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          _frameCropEnabled ? widget.frameCropLabels.editorTitle : '',
          style: TextStyle(
            color: t.textColor,
            fontFamily: t.titleFontFamily ?? t.fontFamily,
            fontSize: t.titleFontSize,
            letterSpacing: 0.5,
          ),
        ),
        row,
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ImageEditorState state) {
    // Web gets a clean, flat header — no safe-area / Dynamic Island logic.
    if (kIsWeb) return _buildWebHeader(context, state);

    final topPadding = MediaQuery.of(context).padding.top;
    final isAndroid = Platform.isAndroid;
    // Dynamic Island iPhones (14 Pro / 15 / 16 series) have a safe-area top
    // inset of ~59 dp. The pill is narrow enough that buttons placed within
    // that height on either side are fully visible.
    // Notch iPhones (up to iPhone 14 / 13 / 12 …) have ~44–47 dp and the
    // notch spans the full width, hiding buttons at that level. Treat them
    // the same as Android: push buttons below the safe-area with a spacer.
    final hasDynamicIsland = !isAndroid && topPadding >= 50;
    // The themed look (title in the middle) and edge-to-edge keep every
    // button below the status bar / Dynamic Island, like the frame step.
    final safeHeader = widget.edgeToEdge || widget.theme.showTitle;
    final useAndroidLayout = isAndroid || !hasDynamicIsland || safeHeader;
    return Container(
      color: widget.theme.panelColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // On Android and notch iPhones, add a status-bar-height spacer so
          // the buttons sit below the status bar / notch. On Dynamic Island
          // iPhones the buttons are positioned inside the safe-area height,
          // visible on either side of the pill.
          if (useAndroidLayout) SizedBox(height: topPadding),
          Container(
            padding: safeHeader
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 6)
                : useAndroidLayout
                    ? const EdgeInsets.symmetric(horizontal: 40, vertical: 20)
                    : const EdgeInsets.symmetric(horizontal: 40),
            height: useAndroidLayout ? null : topPadding,
            child: _buildHeaderButtons(web: false),
          ),
          // Progress counter shown below the button row so it is never
          // hidden behind the iOS notch/Dynamic Island.
          if (_totalImages > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / $_totalImages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Always keep the crop toolbar in the layout so the canvas height
          // stays constant across tabs (changing it would shift the image
          // position under BoxFit.contain).
          Visibility(
            visible:
                widget.showCropToolbar && state.currentTab == EditorTab.adjust,
            maintainSize: false,
            maintainAnimation: true,
            maintainState: true,
            child: _buildUndoToolbar(state),
          ),
          Visibility(
            visible:
                widget.showCropToolbar && state.currentTab == EditorTab.crop,
            maintainSize: false,
            maintainAnimation: true,
            maintainState: true,
            child: _buildCropToolbar(state),
          ),
        ],
      ),
    );
  }

  /// Clean, flat header for desktop web — no safe-area or Dynamic Island logic.
  Widget _buildWebHeader(BuildContext context, ImageEditorState state) {
    return Container(
      color: widget.theme.panelColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: _buildHeaderButtons(web: true),
          ),
          Visibility(
            visible:
                widget.showCropToolbar && state.currentTab == EditorTab.adjust,
            maintainSize: false,
            maintainAnimation: true,
            maintainState: true,
            child: _buildUndoToolbar(state),
          ),
          Visibility(
            visible:
                widget.showCropToolbar && state.currentTab == EditorTab.crop,
            maintainSize: false,
            maintainAnimation: true,
            maintainState: true,
            child: _buildCropToolbar(state),
          ),
        ],
      ),
    );
  }

  Widget _buildUndoToolbar(ImageEditorState state) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Row(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8, left: 16, top: 6),
                decoration: BoxDecoration(
                  color: widget.theme.surfaceColor,
                  borderRadius: const BorderRadius.all(Radius.circular(50)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                height: 38,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    InkWell(
                      onTap:
                          _controller.canUndo ? () => _controller.undo() : null,
                      child: Icon(
                        CupertinoIcons.arrow_uturn_left,
                        color: _controller.canUndo
                            ? CupertinoColors.white
                            : CupertinoColors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 22),
                    InkWell(
                      onTap:
                          _controller.canRedo ? () => _controller.redo() : null,
                      child: Icon(
                        CupertinoIcons.arrow_uturn_right,
                        color: _controller.canRedo
                            ? CupertinoColors.white
                            : CupertinoColors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: _isSaving
                ? null
                : () {
                    _controller.reset();
                    setState(() => _isCropPortrait = false);
                  },
            child: Text(
              widget.resetLabel,
              style: widget.theme.text(
                color: widget.theme.accentColor,
                fontSize: 17,
              ),
            ),
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget _buildCropToolbar(ImageEditorState state) {
    final s = widget.cropToolbarSettings;
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: widget.theme.surfaceColor,
                      borderRadius: const BorderRadius.all(Radius.circular(50)),
                    ),
                    height: 38,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => _controller.flipHorizontal(),
                            child: const Icon(
                              CupertinoIcons.arrow_left_right,
                              color: CupertinoColors.white,
                            ),
                          ),
                          const SizedBox(width: 22),
                          InkWell(
                            onTap: () => _controller.rotate90(),
                            child: const Icon(
                              CupertinoIcons.rotate_left,
                              color: CupertinoColors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: _isSaving
                    ? null
                    : () {
                        _controller.reset();
                        setState(() => _isCropPortrait = false);
                      },
                child: Text(
                  widget.resetLabel,
                  style: widget.theme.text(
                    color: widget.theme.accentColor,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            if (s.showAspectRatio) ...[
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: widget.theme.surfaceColor,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(50)),
                      ),
                      height: 38,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showingAspectRatioPicker =
                                    !_showingAspectRatioPicker;
                                // Sync the portrait toggle when the picker is
                                // opened while ratio9x16 is active in state so
                                // the 16:9 chip appears selected + highlighted.
                                if (_showingAspectRatioPicker &&
                                    _controller.state.aspectRatioPreset ==
                                        AspectRatioPreset.ratio9x16) {
                                  _isCropPortrait = true;
                                }
                              });
                            },
                            child: Icon(
                              CupertinoIcons.crop,
                              size: 22,
                              color: _showingAspectRatioPicker
                                  ? widget.theme.accentColor
                                  : state.aspectRatioPreset !=
                                          AspectRatioPreset.free
                                      ? widget.theme.tabSelectedColor
                                      : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 22),
                          Builder(
                            builder: (btnCtx) => InkWell(
                              onTap: () => _showEditMenu(btnCtx),
                              child: const Icon(
                                CupertinoIcons.ellipsis,
                                size: 22,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _dismissEditMenu() {
    _editMenuOverlay?.remove();
    _editMenuOverlay = null;
  }

  void _showEditMenu(BuildContext btnCtx) {
    _dismissEditMenu();
    final box = btnCtx.findRenderObject()! as RenderBox;
    final overlayState = Overlay.of(context);
    final overlayBox = overlayState.context.findRenderObject()! as RenderBox;
    final pos = box.localToGlobal(Offset.zero, ancestor: overlayBox);

    const menuWidth = 220.0;

    // Align menu top-right to button top-right, opening downward.
    final left = (pos.dx + 12) + box.size.width - menuWidth;
    final top = pos.dy - 8;

    _editMenuOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissEditMenu,
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.theme.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEditMenuItem(
                      CupertinoIcons.arrow_uturn_left,
                      'Undo',
                      _controller.canUndo
                          ? () {
                              _dismissEditMenu();
                              _controller.undo();
                            }
                          : null,
                    ),
                    const Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.white24,
                      indent: 22,
                      endIndent: 22,
                    ),
                    _buildEditMenuItem(
                      CupertinoIcons.arrow_uturn_right,
                      'Redo',
                      _controller.canRedo
                          ? () {
                              _dismissEditMenu();
                              _controller.redo();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlayState.insert(_editMenuOverlay!);
  }

  Widget _buildEditMenuItem(IconData icon, String label, VoidCallback? onTap) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Icon(icon,
                  color: disabled
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white,
                  size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      color: disabled
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white,
                      fontSize: 17,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAspectRatioStrip(ImageEditorState state) {
    // 9:16 is covered by portrait orientation + 16:9, so hide it from the strip.
    final presets = AspectRatioPreset.values
        .where((p) => p != AspectRatioPreset.ratio9x16)
        .toList();

    return SizedBox(
      height: 142,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Portrait / Landscape orientation toggle ──────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildOrientationToggle(portrait: true),
              const SizedBox(width: 6),
              _buildOrientationToggle(portrait: false),
            ],
          ),
          const SizedBox(height: 10),
          // ── Aspect ratio preset chips ─────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: presets.map((preset) {
                // ratio9x16 is hidden from the list but maps to ratio16x9 in
                // portrait mode — treat ratio16x9 as selected in that case.
                final isSelected = state.aspectRatioPreset == preset ||
                    (preset == AspectRatioPreset.ratio16x9 &&
                        state.aspectRatioPreset == AspectRatioPreset.ratio9x16);
                // Show the actually-applied ratio in the label so the user is
                // never misled. Landscape-canonical presets (ratio > 1) are
                // inverted in portrait mode, so flip the label to match.
                final ratio = preset.ratio;
                final effectiveLabel =
                    (_isCropPortrait && ratio != null && ratio > 1.0)
                        ? preset.label.split(':').reversed.join(':')
                        : preset.label;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ZChip(
                    theme: widget.theme,
                    label: effectiveLabel,
                    selected: isSelected,
                    onTap: () => _controller.setAspectRatioPreset(preset),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// A single portrait-or-landscape toggle button showing a phone-shape icon.
  Widget _buildOrientationToggle({required bool portrait}) {
    final isSelected = _isCropPortrait == portrait;
    final iconColor =
        isSelected ? CupertinoColors.black : CupertinoColors.white;
    // Phone dimensions: portrait = narrow & tall, landscape = wide & short.
    final double iconW = portrait ? 10.0 : 18.0;
    final double iconH = portrait ? 18.0 : 10.0;

    return GestureDetector(
      onTap: () {
        if (_isCropPortrait != portrait) {
          setState(() => _isCropPortrait = portrait);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? widget.theme.chipSelectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Container(
          width: iconW,
          height: iconH,
          decoration: BoxDecoration(
            border: Border.all(color: iconColor, width: 1.5),
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context, ImageEditorState state) {
    if (widget.theme.toolRowTabs) return _buildToolRowTabs(context, state);
    final tabs = [
      if (widget.showAdjustTab)
        _buildTab(
          icon: CupertinoIcons.slider_horizontal_3,
          label: 'Adjust',
          isSelected: state.currentTab == EditorTab.adjust,
          onTap: () {
            _controller.setTab(EditorTab.adjust);
            setState(() => _showingAspectRatioPicker = false);
          },
        ),
      if (widget.showCropTab)
        _buildTab(
          icon: CupertinoIcons.crop,
          label: 'Crop',
          isSelected: state.currentTab == EditorTab.crop,
          onTap: () => _controller.setTab(EditorTab.crop),
        ),
    ];

    // Fewer than two tabs means there's nothing to switch between.
    if (tabs.length < 2) return const SizedBox(height: 22);

    // Add the system bottom inset (gesture bar / navigation bar height) so
    // the tab pill is never hidden on devices that have a bottom system bar.
    // On devices without one, padding.bottom is 0 and the +16 keeps the
    // existing visual spacing.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 6, 24, 16 + bottomInset),
      child: Center(
        child: IntrinsicWidth(
          child: Container(
            decoration: BoxDecoration(
              color: widget.theme.surfaceColor,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: tabs,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tabs as a flat row of line icons with labels (themed look).
  Widget _buildToolRowTabs(BuildContext context, ImageEditorState state) {
    final t = widget.theme;
    final tabs = [
      if (widget.showCropTab)
        ZToolButton(
          key: const Key('z_editor_tab_crop'),
          theme: t,
          icon: ZLineIconKind.crop,
          label: 'Crop',
          labelLines: 1,
          active: state.currentTab == EditorTab.crop,
          activeColor: t.tabSelectedColor,
          onTap: () => _controller.setTab(EditorTab.crop),
        ),
      if (widget.showAdjustTab)
        ZToolButton(
          key: const Key('z_editor_tab_adjust'),
          theme: t,
          icon: ZLineIconKind.adjust,
          label: 'Adjust',
          labelLines: 1,
          active: state.currentTab == EditorTab.adjust,
          activeColor: t.tabSelectedColor,
          onTap: () {
            _controller.setTab(EditorTab.adjust);
            setState(() => _showingAspectRatioPicker = false);
          },
        ),
    ];
    if (tabs.length < 2) return const SizedBox(height: 22);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 64,
      margin: EdgeInsets.fromLTRB(16, 6, 16, 8 + bottomInset),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs,
      ),
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? widget.theme.tabSelectedColor
                  : widget.theme.mutedTextColor,
              size: 20,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? widget.theme.tabSelectedColor
                    : widget.theme.mutedTextColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolControls(ImageEditorState state) {
    if (state.currentTab == EditorTab.crop && _showingAspectRatioPicker) {
      return _buildAspectRatioStrip(state);
    }
    final index = switch (state.currentTab) {
      EditorTab.adjust => 0,
      EditorTab.crop => 1,
    };
    // IndexedStack keeps all panels in the layout tree simultaneously, so the
    // canvas always receives the same height regardless of which tab is active.
    return IndexedStack(
      index: index,
      children: [
        if (widget.theme.toolRowTabs)
          ThemedAdjustControls(
            key: const Key('z_adjust_controls'),
            theme: widget.theme,
            controller: _controller,
            settings: widget.adjustTabSettings,
            labels: widget.autoFixLabels,
            autoLevels: _autoFix?.values,
            autoTurnedOnForHaze: _autoForHaze,
            panel: _adjustPanel,
            onPanel: (p) => setState(() => _adjustPanel = p),
            onAutoChanged: (on) => setState(() {
              _autoForHaze = false;
              if (on) {
                _autoOffByUser.remove(_currentIndex);
              } else {
                _autoOffByUser.add(_currentIndex);
              }
            }),
          )
        else
          AdjustmentControls(
            accentColor: widget.theme.accentColor,
            controller: _controller,
            settings: widget.adjustTabSettings,
          ),
        CropControls(
          accentColor: widget.theme.accentColor,
          controller: _controller,
          settings: widget.cropTabSettings,
        ),
      ],
    );
  }
}

/// Shown when the image for the frame step cannot be read.
class _FrameLoadError extends StatelessWidget {
  final ZImageEditorTheme theme;
  final String cancelLabel;
  final VoidCallback onCancel;

  const _FrameLoadError({
    required this.theme,
    required this.cancelLabel,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.backgroundColor,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not open the image',
                key: const Key('z_frame_load_error'),
                style: theme.text(color: theme.mutedTextColor),
              ),
              const SizedBox(height: 16),
              ZSecondaryButton(
                key: const Key('z_frame_error_cancel'),
                theme: theme,
                label: cancelLabel,
                onPressed: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
