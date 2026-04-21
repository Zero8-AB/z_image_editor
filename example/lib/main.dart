import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:z_image_editor/image_editor.dart';

// Use the same conditional File as the package so types are compatible.
// On native this resolves to dart:io; on web to the package's File stub.
// ignore: uri_does_not_exist
import 'dart:io'
    if (dart.library.html) 'package:z_image_editor/src/utils/platform_io_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Z Image Editor Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // All results stored as bytes for display (avoids Image.file on web).
  Uint8List? _editedImageBytes;
  List<Uint8List> _editedImagesBytes = [];

  final ImagePicker _picker = ImagePicker();

  // ── Single image ────────────────────────────────────────────────────────────

  Future<void> _pickAndEditImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null || !mounted) return;

      if (kIsWeb) {
        final imageBytes = await pickedFile.readAsBytes();
        if (!mounted) return;

        final resultBytes = await showDialog<Uint8List>(
          context: context,
          barrierColor: Colors.transparent,
          barrierDismissible: false,
          builder: (context) => _BlurredEditorDialog(
            verticalMargin: 40, // px of space above & below the panel
            maxWidth: 900, // WebEditorShell takes 82% of this → ~900 px
            child: ZImageEditor(
              showAdjustTab: true,
              showCropTab: true,
              showCropToolbar: true,
              adjustTabSettings: const AdjustTabSettings(
                showBrightness: true,
                showContrast: true,
                showSaturation: true,
              ),
              cropTabSettings: const CropTabSettings(
                showStraighten: true,
                showTiltVertical: true,
                showTiltHorizontal: true,
              ),
              cropToolbarSettings: const CropToolbarSettings(
                showRotate: true,
                showFlipHorizontal: true,
                showFlipVertical: true,
                showAspectRatio: true,
              ),
              cancelLabel: 'Cancel',
              resetLabel: 'Reset',
              doneLabel: 'Save',
              enableMagnifyingGlass: true,
              imageBytesList: [imageBytes],
              onSaveAllBytes: (List<Uint8List> edited) {
                Navigator.of(context).pop(edited.first);
              },
              onCancel: () => Navigator.of(context).pop(),
            ),
          ),
        );

        if (resultBytes != null) {
          setState(() {
            _editedImageBytes = resultBytes;
            _editedImagesBytes = [];
          });
        }
      } else {
        // Mobile: pass File path, then read bytes for display.
        Uint8List? resultBytes;
        await Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => ZImageEditor(
              showAdjustTab: true,
              showCropTab: true,
              showCropToolbar: true,
              adjustTabSettings: const AdjustTabSettings(
                showBrightness: true,
                showContrast: true,
                showSaturation: true,
              ),
              cropTabSettings: const CropTabSettings(
                showStraighten: true,
                showTiltVertical: true,
                showTiltHorizontal: true,
              ),
              cropToolbarSettings: const CropToolbarSettings(
                showRotate: true,
                showFlipHorizontal: true,
                showFlipVertical: true,
                showAspectRatio: true,
              ),
              cancelLabel: 'Cancel',
              resetLabel: 'Reset',
              doneLabel: 'Save',
              enableMagnifyingGlass: true,
              imageFiles: [File(pickedFile.path)],
              onSaveAll: (List<File> edited) async {
                resultBytes = await edited.first.readAsBytes();
                if (context.mounted) Navigator.of(context).pop();
              },
              onCancel: () => Navigator.of(context).pop(),
            ),
          ),
        );

        if (resultBytes != null) {
          setState(() {
            _editedImageBytes = resultBytes;
            _editedImagesBytes = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Multi-image ─────────────────────────────────────────────────────────────

  Future<void> _pickAndEditMultipleImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isEmpty || !mounted) return;

      if (kIsWeb) {
        final bytesList =
            await Future.wait(pickedFiles.map((f) => f.readAsBytes()));
        if (!mounted) return;

        final resultBytes = await showDialog<List<Uint8List>>(
          context: context,
          barrierColor: Colors.transparent,
          barrierDismissible: false,
          builder: (context) => _BlurredEditorDialog(
            child: ZImageEditor(
              showAdjustTab: true,
              showCropTab: true,
              showCropToolbar: true,
              adjustTabSettings: const AdjustTabSettings(
                showBrightness: true,
                showContrast: true,
                showSaturation: true,
              ),
              cropTabSettings: const CropTabSettings(
                showStraighten: true,
                showTiltVertical: true,
                showTiltHorizontal: true,
              ),
              cropToolbarSettings: const CropToolbarSettings(
                showRotate: true,
                showFlipHorizontal: true,
                showFlipVertical: true,
                showAspectRatio: true,
              ),
              cancelLabel: 'Cancel',
              resetLabel: 'Reset',
              doneLabel: 'Save',
              nextLabel: 'Next',
              enableMagnifyingGlass: true,
              imageBytesList: bytesList,
              onSaveAllBytes: (List<Uint8List> edited) {
                Navigator.of(context).pop(edited);
              },
              onCancel: () => Navigator.of(context).pop(),
            ),
          ),
        );

        if (resultBytes != null && resultBytes.isNotEmpty) {
          setState(() {
            _editedImagesBytes = resultBytes;
            _editedImageBytes = resultBytes.last;
          });
        }
      } else {
        final files = pickedFiles.map((f) => File(f.path)).toList();
        List<Uint8List>? resultBytes;

        await Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => ZImageEditor(
              showAdjustTab: true,
              showCropTab: true,
              showCropToolbar: true,
              adjustTabSettings: const AdjustTabSettings(
                showBrightness: true,
                showContrast: true,
                showSaturation: true,
              ),
              cropTabSettings: const CropTabSettings(
                showStraighten: true,
                showTiltVertical: true,
                showTiltHorizontal: true,
              ),
              cropToolbarSettings: const CropToolbarSettings(
                showRotate: true,
                showFlipHorizontal: true,
                showFlipVertical: true,
                showAspectRatio: true,
              ),
              cancelLabel: 'Cancel',
              resetLabel: 'Reset',
              doneLabel: 'Save',
              nextLabel: 'Next',
              enableMagnifyingGlass: true,
              imageFiles: files,
              onSaveAll: (List<File> edited) async {
                resultBytes =
                    await Future.wait(edited.map((f) => f.readAsBytes()));
                if (context.mounted) Navigator.of(context).pop();
              },
              onCancel: () => Navigator.of(context).pop(),
            ),
          ),
        );

        if (resultBytes != null && resultBytes!.isNotEmpty) {
          setState(() {
            _editedImagesBytes = resultBytes!;
            _editedImageBytes = resultBytes!.last;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Z Image Editor'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: _editedImageBytes != null
                  ? GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => _FullscreenImagePreview(
                              bytes: _editedImageBytes!),
                        ),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        margin: const EdgeInsets.all(12),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Image.memory(_editedImageBytes!,
                                fit: BoxFit.contain),
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                shadows: [Shadow(blurRadius: 4)],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'No image selected',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
            ),
            if (_editedImagesBytes.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _editedImagesBytes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => _FullscreenImagePreview(
                              bytes: _editedImagesBytes[index]),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _editedImagesBytes[index],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: 1,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (!kIsWeb)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _pickAndEditImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 15),
                              ),
                            ),
                          ),
                        if (!kIsWeb) const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _pickAndEditImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text(
                              'Choose from Gallery',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickAndEditMultipleImages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Edit Multiple Images'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenImagePreview extends StatelessWidget {
  const _FullscreenImagePreview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Preview'),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 8.0,
        child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
      ),
    );
  }
}

/// Full-screen overlay that blurs the content beneath it, then centers the
/// Blurred backdrop dialog for the web editor.
///
/// [verticalMargin] controls how much empty space appears above and below
/// the editor panel (default 40 px each side).
///
/// Width is handled by WebEditorShell inside ZImageEditor (82 % of the
/// available space, capped at 960 px by default). Override [maxWidth] to
/// give WebEditorShell a narrower canvas — it will then take 82 % of that.
///
/// Example — fixed ~800 px wide, 60 px vertical breathing room:
///   _BlurredEditorDialog(maxWidth: 980, verticalMargin: 60, child: editor)
class _BlurredEditorDialog extends StatelessWidget {
  final Widget child;

  /// Space above and below the floating panel in logical pixels.
  final double verticalMargin;

  /// Maximum width given to WebEditorShell. The shell will center the editor
  /// at 82 % of this value (up to its own 960 px cap).
  final double maxWidth;

  const _BlurredEditorDialog({
    required this.child,
    this.verticalMargin = 40.0,
    this.maxWidth = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        padding: EdgeInsets.symmetric(vertical: verticalMargin),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
