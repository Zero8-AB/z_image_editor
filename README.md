Image Editor

A beautiful iOS-style image editor for Flutter with crop, rotate, and color adjustment features.

## Features

- 🎨 **iOS-Native Design** - Authentic iOS aesthetics with dark theme
- ✂️ **Crop** - Multiple aspect ratio presets (Free, Square, 4:3, 16:9) with visual grid overlay
- 🔍 **Pinch-to-Zoom** - Zoom in/out with pinch gestures on mobile, zoom and pan the image behind the crop overlay
- 🔄 **Rotate** - 90° rotation, horizontal/vertical flip, and fine-tune rotation slider
- 🌈 **Color Adjustments** - Brightness, contrast, and saturation controls with real-time preview
- 📱 **Platform Aware** - Optimized for iOS with CupertinoActionSheet integration
- ⚡ **Real-time Preview** - See changes instantly as you adjust

## Screenshots

[Add screenshots here]

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  image_editor: ^0.1.0
```

Or reference it locally:

```yaml
dependencies:
  image_editor:
  path: ../image_editor
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Usage

```dart
import 'package:image_editor/image_editor.dart';
import 'dart:io';

// Show the image editor
final editedImage = await Navigator.of(context).push<File>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => ImageEditor(
      imageFile: File('path/to/image.jpg'),
      onSave: (File editedFile) {
        Navigator.of(context).pop(editedFile);
      },
      onCancel: () {
        Navigator.of(context).pop();
      },
    ),
  ),
);

if (editedImage != null) {
  // Use the edited image
  print('Image edited: ${editedImage.path}');
}
```

### With Image Picker Integration

```dart
import 'package:image_picker/image_picker.dart';
import 'package:image_editor/image_editor.dart';

final picker = ImagePicker();

// Take a photo
final photo = await picker.pickImage(source: ImageSource.camera);

if (photo != null) {
  // Show editor
  final editedImage = await Navigator.of(context).push<File>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => ImageEditor(
        imageFile: File(photo.path),
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
    // Use edited image
  }
}
```

### With iOS Action Sheet

```dart
import 'package:flutter/cupertino.dart';
import 'package:image_editor/image_editor.dart';

Future<void> showImageSourcePicker(BuildContext context) async {
  final result = await showCupertinoModalPopup<String>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: const Text('Add Image'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext, 'camera'),
          child: const Text('Take Photo'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext, 'gallery'),
          child: const Text('Choose from Gallery'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: const Text('Cancel'),
      ),
    ),
  );

  if (result == 'camera' && context.mounted) {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (photo != null && context.mounted) {
      final edited = await Navigator.of(context).push<File>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => ImageEditor(
            imageFile: File(photo.path),
            onSave: (file) => Navigator.pop(context, file),
            onCancel: () => Navigator.pop(context),
          ),
        ),
      );
      // Use edited image
    }
  }
}
```

## API Reference

### ImageEditor

Main widget for the image editor.

#### Properties

- `imageFile` (File?) - The image file to edit
- `imageBytes` (Uint8List?) - Alternative: image as bytes
- `onSave` (Function(File)) - Callback when user saves the edited image
- `onCancel` (VoidCallback) - Callback when user cancels editing

### Editing Features

#### Crop Tab

- **Aspect Ratios**: Free, Square (1:1), 4:3, 16:9
- **Visual Grid**: Rule of thirds overlay
- **Pinch-to-Zoom**: Use pinch gestures to zoom in/out on mobile
- **Pan**: Pan the zoomed image with drag gestures
- **Reset Zoom**: Quickly reset to 100% zoom (button appears when zoomed)
- **Zoom Indicator**: Shows current zoom level as percentage
- **Reset**: Quick reset to original crop

> **Note**: When you save the image, only the portion visible within the crop overlay will be saved, taking into account the zoom and pan position. The image zooms behind the overlay, allowing you to precisely select the area you want to keep.

#### Adjust Tab

- **Brightness**: -100 to +100
- **Contrast**: 0.5 to 2.0
- **Saturation**: 0.0 to 2.0
- **Real-time Preview**: See changes instantly

#### Rotate Tab

- **90° Rotation**: Quick rotate button
- **Flip Horizontal**: Mirror image horizontally
- **Flip Vertical**: Mirror image vertically
- **Fine Rotation**: -45° to +45° with slider

## Requirements

- Flutter SDK: >=3.1.3
- Dart SDK: >=3.1.3
- iOS 12.0+ (for iOS platform)
- Android 21+ (for Android platform)

## Dependencies

- `image` - Image processing and manipulation

## Development

### Running the example

```bash
cd example
flutter run
```

### Running tests

```bash
flutter test
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Credits

Developed by [Image Editor Team](https://github.com/Image-Editor-Team)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
