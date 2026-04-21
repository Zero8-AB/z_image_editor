# Z Image Editor

`z_image_editor` is a Flutter package for in-app image editing with a polished, iOS-inspired editing surface. It provides crop, rotate, flip, brightness, contrast, and saturation controls with real-time preview — on both **mobile and web**.

## Features

- Crop with preset aspect ratios and freeform handles
- Rotate in 90-degree steps plus fine rotation control
- Flip horizontally and vertically
- Adjust brightness, contrast, and saturation
- Perspective tilt (vertical and horizontal)
- Optional magnifying glass on crop handle drag
- Multi-image editing (step through a batch in one session)
- Scroll-to-zoom on desktop/web (mouse wheel and trackpad)
- Web UI: centered floating panel, or full-screen — your choice
- Fully configurable UI — hide tabs, toolbar buttons, and ruler badges
- Ship a runnable demo in [`example/`](./example)

## Platform Support

| Platform | Supported |
|----------|-----------|
| iOS | ✅ |
| Android | ✅ |
| Web (Chrome, Safari, Firefox, Edge) | ✅ |
| macOS / Linux / Windows | ✅ |

## Installation

This repository is not publishing to pub.dev yet. Until that happens, depend on it directly from Git:

```yaml
dependencies:
  z_image_editor:
    git:
      url: https://github.com/Zero8-AB/z_image_editor.git
```

After the package is published, you can switch to:

```bash
flutter pub add z_image_editor
```

## Usage

### Mobile (iOS & Android)

Pass image files and receive edited files back via `onSaveAll`. You bring your own image source, such as `image_picker`.

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:z_image_editor/image_editor.dart';

final editedImages = await Navigator.of(context).push<List<File>>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => ZImageEditor(
      imageFiles: [File(pickedFile.path)],
      onSaveAll: (List<File> edited) {
        Navigator.of(context).pop(edited);
      },
      onCancel: () => Navigator.of(context).pop(),
    ),
  ),
);
```

### Web — centered floating panel (default)

On web, pass raw bytes and receive edited bytes back via `onSaveAllBytes`. The editor renders in a centered, width-constrained panel inside a `MaterialPageRoute`.

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:z_image_editor/image_editor.dart';

final imageBytes = await pickedFile.readAsBytes();

final resultBytes = await Navigator.of(context).push<Uint8List>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => ZImageEditor(
      imageBytesList: [imageBytes],
      onSaveAllBytes: (List<Uint8List> edited) {
        Navigator.of(context).pop(edited.first);
      },
      onCancel: () => Navigator.of(context).pop(),
    ),
  ),
);
```

### Web — blurred dialog

To show the editor as a floating dialog with the app visible and blurred behind it, use `showDialog` directly and size the panel yourself:

```dart
import 'dart:ui' show ImageFilter;

Uint8List? resultBytes;

await showDialog(
  context: context,
  barrierColor: Colors.transparent,
  barrierDismissible: false,
  builder: (context) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
    child: Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: SizedBox(
            width: (MediaQuery.of(context).size.width * 0.82).clamp(0, 960),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ZImageEditor(
                imageBytesList: [imageBytes],
                onSaveAllBytes: (edited) {
                  resultBytes = edited.first;
                  Navigator.of(context).pop();
                },
                onCancel: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
```

For a complete integration example covering all platforms, see [`example/lib/main.dart`](./example/lib/main.dart).

## Web API Contract

| Parameter | Mobile | Web |
|-----------|--------|-----|
| `imageFiles` | ✅ Required (or `imageBytesList`) | ❌ Not supported |
| `imageBytesList` | ✅ Optional | ✅ Required |
| `onSaveAll` | ✅ Required | ❌ Not supported |
| `onSaveAllBytes` | ❌ Not used | ✅ Required |

Passing the wrong combination throws an `ArgumentError` at startup with a clear message.

## Configuration

All parameters are optional beyond the platform-appropriate image input and save callback.

### Button labels

Localise or customise the header buttons:

```dart
ZImageEditor(
  // ...
  cancelLabel: 'Avbryt',
  resetLabel: 'Återställ',
  doneLabel: 'Klar',
  nextLabel: 'Nästa',   // shown between images in multi-image sessions
)
```

### Magnifying glass

Show a magnifying glass above the finger while dragging crop handles (off by default):

```dart
ZImageEditor(
  // ...
  enableMagnifyingGlass: true,
)
```

### Web layout

On web the editor is automatically centered in a panel that is 82% of the viewport width (max 960 px) and fills the full height. On viewports narrower than 620 dp it falls back to full-screen. No configuration needed — this is always the default web behaviour.

If you open the editor with `showDialog` (for a blurred-background effect), the same shell handles horizontal centering inside the dialog. You only need to add vertical padding and the blur overlay on the dialog side — see the [blurred dialog example](#web--blurred-dialog) above.

### Crop toolbar

```dart
ZImageEditor(
  // ...
  // Hide the whole toolbar:
  showCropToolbar: false,

  // — or keep the toolbar but hide specific buttons:
  cropToolbarSettings: CropToolbarSettings(
    showRotate: true,
    showFlipHorizontal: true,
    showFlipVertical: false,
    showAspectRatio: true,
  ),
)
```

### Tabs

```dart
ZImageEditor(
  // ...
  showAdjustTab: false,   // hide a tab entirely

  cropTabSettings: CropTabSettings(
    showStraighten: true,
    showTiltVertical: true,
    showTiltHorizontal: true,
  ),

  adjustTabSettings: AdjustTabSettings(
    showBrightness: true,
    showContrast: true,
    showSaturation: false,
  ),
)
```

When only one tab is enabled the tab bar is hidden automatically.

## Local Quality Checks

Run the same checks used in CI before opening a pull request:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter pub publish --dry-run
(cd example && flutter pub get && flutter analyze)
```

## Releases and Versioning

This repository uses `release-please` for changelog and version automation.

- `fix:` creates a patch release
- `feat:` creates a minor release while the package is still in `0.x`
- `BREAKING CHANGE:` marks a breaking release

Use Conventional Commits for merge commits and squash commit messages so release automation can generate accurate release PRs.
