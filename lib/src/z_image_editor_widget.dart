import 'dart:io'
    if (dart.library.html) 'package:z_image_editor/src/utils/platform_io_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:z_image_editor/src/controller/image_editor_controller.dart';
import 'package:z_image_editor/src/models/adjust_tab_settings.dart';
import 'package:z_image_editor/src/models/crop_tab_settings.dart';
import 'package:z_image_editor/src/models/crop_toolbar_settings.dart';
import 'package:z_image_editor/src/models/image_editor_state.dart';
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
  final List<File> _processedImages = [];
  // Web: accumulates PNG bytes across multi-image sessions.
  final List<Uint8List> _processedImageBytes = [];

  int get _totalImages =>
      widget.imageFiles?.length ?? widget.imageBytesList?.length ?? 1;

  bool get _isLastImage => _currentIndex >= _totalImages - 1;

  File? get _currentImageFile => widget.imageFiles?[_currentIndex];

  Uint8List? get _currentImageBytes => widget.imageBytesList?[_currentIndex];

  @override
  void initState() {
    super.initState();
    _controller = ImageEditorController();
    _controller.initialize(
      imageFile: _currentImageFile,
      imageBytes: _currentImageBytes,
    );
    // Default to the first visible tab.
    if (!widget.showCropTab && widget.showAdjustTab) {
      _controller.setTab(EditorTab.adjust);
    }
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom],
      );
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
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      // Restore all orientations when the editor is closed.
      SystemChrome.setPreferredOrientations([]);
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

    File processedFile;

    if (!state.hasChanges && currentFile != null) {
      processedFile = currentFile;
    } else if (currentFile != null) {
      processedFile = await ImageProcessing.processImage(
        originalFile: currentFile,
        state: state,
      );
    } else if (currentBytes != null) {
      processedFile = await ImageProcessing.processImageFromBytes(
        bytes: currentBytes,
        state: state,
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

  Future<void> _handleSaveWeb() async {
    final state = _controller.state;
    final currentBytes = _currentImageBytes;
    if (currentBytes == null) return;

    final pngBytes = state.hasChanges
        ? await ImageProcessing.processImageToBytes(
            bytes: currentBytes,
            state: state,
          )
        : currentBytes;

    if (_isLastImage) {
      _processedImageBytes.add(pngBytes);
      widget.onSaveAllBytes!(_processedImageBytes);
    } else {
      _processedImageBytes.add(pngBytes);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final state = _controller.state;

        final editorContent = Material(
          color: Colors.black,
          child: Column(
            children: [
              _buildHeader(context, state),

              Expanded(
                child: ImageCanvas(
                  imageFile: _currentImageFile,
                  imageBytes: _currentImageBytes,
                  controller: _controller,
                  enableMagnifyingGlass: widget.enableMagnifyingGlass,
                  portraitOrientation: _isCropPortrait,
                ),
              ),

              // Bottom controls
              Container(
                color: const Color(0xFF1C1C1E),
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
    final useAndroidLayout = isAndroid || !hasDynamicIsland;
    return Container(
      color: const Color(0xFF1C1C1E),
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
            padding: useAndroidLayout
                ? const EdgeInsets.symmetric(horizontal: 40, vertical: 20)
                : const EdgeInsets.symmetric(horizontal: 40),
            height: useAndroidLayout ? null : topPadding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 80,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    sizeStyle: CupertinoButtonSize.small,
                    onPressed: _isSaving ? null : widget.onCancel,
                    child: Text(
                      widget.cancelLabel,
                      style: const TextStyle(
                        color: CupertinoColors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    onPressed: _isSaving ? null : _handleSave,
                    color: CupertinoColors.systemYellow,
                    borderRadius: BorderRadius.circular(50),
                    sizeStyle: CupertinoButtonSize.small,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CupertinoActivityIndicator(),
                          )
                        : Text(
                            _totalImages > 1 && !_isLastImage
                                ? widget.nextLabel
                                : widget.doneLabel,
                            style: const TextStyle(
                              color: CupertinoColors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
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
      color: const Color(0xFF1C1C1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 90,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    sizeStyle: CupertinoButtonSize.small,
                    onPressed: _isSaving ? null : widget.onCancel,
                    child: Text(
                      widget.cancelLabel,
                      style: const TextStyle(
                        color: CupertinoColors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (_totalImages > 1)
                  Text(
                    '${_currentIndex + 1} / $_totalImages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                SizedBox(
                  width: 90,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    onPressed: _isSaving ? null : _handleSave,
                    color: CupertinoColors.systemYellow,
                    borderRadius: BorderRadius.circular(50),
                    sizeStyle: CupertinoButtonSize.small,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CupertinoActivityIndicator(),
                          )
                        : Text(
                            _totalImages > 1 && !_isLastImage
                                ? widget.nextLabel
                                : widget.doneLabel,
                            style: const TextStyle(
                              color: CupertinoColors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
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
                decoration: const BoxDecoration(
                  color: Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.all(Radius.circular(50)),
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
              style: const TextStyle(
                color: CupertinoColors.systemYellow,
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
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.all(Radius.circular(50)),
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
                  style: const TextStyle(
                    color: CupertinoColors.systemYellow,
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
                      decoration: const BoxDecoration(
                        color: Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.all(Radius.circular(50)),
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
                                  ? CupertinoColors.systemYellow
                                  : state.aspectRatioPreset !=
                                          AspectRatioPreset.free
                                      ? CupertinoColors.systemBlue
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
                  color: const Color(0xFF2C2C2E),
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
                return Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CupertinoColors.systemGrey2
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: GestureDetector(
                    onTap: () => _controller.setAspectRatioPreset(preset),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Text(
                        effectiveLabel,
                        style: TextStyle(
                          color: isSelected
                              ? CupertinoColors.black
                              : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
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
          color: isSelected ? CupertinoColors.systemGrey2 : Colors.transparent,
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
              color: const Color(0xFF2C2C2E),
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
              color: isSelected ? CupertinoColors.systemBlue : Colors.white70,
              size: 20,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? CupertinoColors.systemBlue : Colors.white70,
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
        AdjustmentControls(
          controller: _controller,
          settings: widget.adjustTabSettings,
        ),
        CropControls(
          controller: _controller,
          settings: widget.cropTabSettings,
        ),
      ],
    );
  }
}
