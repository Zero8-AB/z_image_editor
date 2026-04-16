import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:z_image_editor/image_editor.dart';

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
  File? _editedImage;
  List<File> _editedImages = [];
  final ImagePicker _picker = ImagePicker();

  void _openFullscreenPreview(BuildContext context, File imageFile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImagePreview(imageFile: imageFile),
      ),
    );
  }

  Future<void> _pickAndEditImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null && mounted) {
        final editedImage = await Navigator.of(context).push<File>(
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
              imageFile: File(pickedFile.path),
              onSave: (File edited) {
                Navigator.of(context).pop(edited);
              },
              onCancel: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );

        if (editedImage != null) {
          setState(() {
            _editedImage = editedImage;
            _editedImages = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _pickAndEditMultipleImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isEmpty || !mounted) return;

      final files = pickedFiles.map((f) => File(f.path)).toList();

      final editedImages = await Navigator.of(context).push<List<File>>(
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
            onSaveAll: (List<File> edited) {
              Navigator.of(context).pop(edited);
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );

      if (editedImages != null && editedImages.isNotEmpty) {
        setState(() {
          _editedImages = editedImages;
          _editedImage = editedImages.last;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

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
              child: _editedImage != null
                  ? GestureDetector(
                      onTap: () =>
                          _openFullscreenPreview(context, _editedImage!),
                      child: Container(
                        alignment: Alignment.center,
                        margin: const EdgeInsets.all(12),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Image.file(_editedImage!, fit: BoxFit.contain),
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
            if (_editedImages.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _editedImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () =>
                          _openFullscreenPreview(context, _editedImages[index]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _editedImages[index],
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _pickAndEditImage(ImageSource.camera);
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
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
  const _FullscreenImagePreview({required this.imageFile});

  final File imageFile;

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
        child: Center(
          child: Image.file(imageFile, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
