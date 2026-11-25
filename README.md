# Z Image Editor

`z_image_editor` is a Flutter package for in-app image editing with a polished, iOS-inspired editing surface. It provides crop, rotate, flip, brightness, contrast, and saturation controls with real-time preview — on both **mobile and web**.

## Features

- Crop with preset aspect ratios and freeform handles
- Rotate in 90-degree steps plus fine rotation control
- Flip horizontally and vertically
- Adjust brightness, contrast, and saturation
- Perspective tilt (vertical and horizontal)
- Optional magnifying glass on crop handle drag
- Optional perspective **frame step**: pick a four-corner outline (e.g. a framed painting) from detector suggestions or drag the corners, then continue editing the straightened image
- Optional one-tap enhancer toggle (e.g. reflection removal) in the frame step
- Themeable chrome (`ZImageEditorTheme`)
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

### Cross-platform builds — avoiding `dart:io File` compile errors

If your app compiles for **both mobile and web**, passing a `dart:io File` to
`imageFiles` will produce a compile error on web:

```
Error: The argument type 'File/*1*/' can't be assigned to the parameter type 'File/*2*/'.
 - 'File/*1*/' is from 'dart:io'.
 - 'File/*2*/' is from 'package:z_image_editor/src/utils/platform_io_web.dart'.
```

This happens because the package uses a conditional import for `File` internally
(`dart:io` on mobile, a lightweight stub on web), so the two `File` types are
distinct at compile time.

**Option 1 — use `imageBytesList` (recommended for cross-platform code)**

Read the file bytes yourself and pass them as `imageBytesList`. This API works
on both mobile and web with no type conflict:

```dart
Future<File> _openEditor(BuildContext context, File imageFile) async {
  final bytes = await imageFile.readAsBytes();
  if (!context.mounted) return imageFile;

  final editedFiles = await Navigator.of(context).push<List<File>>(
    MaterialPageRoute(
      builder: (ctx) => ZImageEditor(
        imageBytesList: [bytes],           // ✅ no File type involved
        onSaveAll: (f) => Navigator.of(ctx).pop(f),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
  return editedFiles?.first ?? imageFile;
}
```

**Option 2 — import `File` from the package instead of `dart:io`**

The package ships `lib/platform_types.dart`, a public conditional export that
resolves to `dart:io File` on mobile and the web stub on web. Importing it
makes the types match on every platform:

```dart
import 'package:z_image_editor/platform_types.dart'; // ← instead of 'dart:io'
```

Everything else stays the same — `imageFiles`, `onSaveAll`, etc. still work as
documented. Just remember that `imageFiles` must still be guarded so it is not
*used* at runtime on web:

```dart
if (!kIsWeb) {
  // safe to pass imageFiles here
}
```

## Configuration

All parameters are optional beyond the platform-appropriate image input and save callback.

### Output files (mobile)

`onSaveAll` always receives **new temp files**, never the `File` objects you
passed in, so you can delete or move them freely. With
`ImageOutputFormat.auto` / `original` and no edits, the file is a
byte-identical copy of the input, named after its real format from the magic
bytes (`.jpg`, `.png`, `.webp`, `.heic`, `.gif`, …; the input name's
extension when the format is unknown). Edited images are re-encoded (`.png`
or `.jpg`).

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

### Frame step (perspective crop)

Pass a `ZFrameDetector` and the editor opens in a "choose the frame" step
first: the photo with four draggable corners (with a magnifier), up to three
suggested outlines as chips, and tools for Rotate, Full photo and Reset.
"Next" straightens the chosen quad at full resolution (pure Dart, background
isolate on native) and continues in the regular crop/adjust editor. The
editor header then shows "‹ Frame" to go back.

The package ships **no detector** (it stays free of native dependencies);
implement the interface in your app, for example with OpenCV:

```dart
class MyDetector extends ZFrameDetector {
  @override
  Future<List<ZFrameCandidate>> detect(Uint8List imageBytes) async => [
        ZFrameCandidate(
          // Normalized 0..1, EXIF orientation applied: TL, TR, BR, BL.
          corners: const [Offset(.1, .1), Offset(.9, .1), Offset(.9, .9), Offset(.1, .9)],
          label: 'With frame',
          score: 0.9,
        ),
      ];
}

ZImageEditor(
  imageBytesList: [bytes],
  frameDetector: MyDetector(),      // opens in the frame step
  imageEnhancer: MyGlareRemover(),  // optional toggle, on by default
  frameCropLabels: const ZFrameCropLabels(title: 'Choose the frame'),
  onSaveAll: ...,
  onCancel: ...,
)
```

- Candidates are shown in the order returned (max. 3). The one with
  `preselected: true` (else the first) is selected at start and by Reset. Tapping the photo cycles through them and the full photo.
- Errors or an empty list fall back to dragging the corners by hand.
- `startWithFrameCrop: true` shows the step without a detector (manual
  corners); `false` hides it even with a detector. Without either, the editor
  behaves exactly as before.
- `ZImageEnhancer.apply` returns the fixed image or `null` ("nothing to fix",
  toggle hidden). Its output must keep the input's displayed orientation and
  aspect ratio.
- The straightened image is capped at 6000 px on its long side
  (`ZPerspectiveWarp.defaultMaxOutputSide`); larger sources are scaled down
  before the warp to bound memory. Palette/indexed and 1-bit images work.
- "Next" is disabled (with a spinner) while the detector or the enhancer is
  still running.
- Going back to the frame step and pressing Next without changing the outline
  keeps the editor's crop/adjust edits; a new outline keeps the colour
  adjustments only.
- Web: works (the warp is pure Dart); pass no native detector there.
- `ZQuadMath` and `ZPerspectiveWarp` are exported for detectors and tests.

### Artwork size and the right shape

With `enableSizeTools: true` the frame step shows a **Size** tool first in
the tool row, red measurement lines next to the outline
(`ZImageEditorTheme.showMeasurements`) and a "Real size of the artwork"
sheet (height × width × depth, common sizes, depth quick picks).

- The straightened image keeps the artwork's **real shape**: from an exact
  size (`artworkSize`, e.g. from the artwork details, or one the user
  confirms), else estimated from the outline's perspective
  (`ZRectAspect`, Zhang–He; focal length from EXIF
  `FocalLengthIn35mmFilm`, else solved from the outline, else a 26 mm
  phone lens), else from the average side lengths.
- Estimates show "≈" ("≈ 50 × 40 cm · Check", "≈ 50 cm"): the best-fitting
  common size (40×30, 50×40, 70×50, 100×70, A3, A4; landscape versions
  for wide art) when its shape matches within 5 %; when no common size has
  the shape (a 16 : 9 screen, a long strip), the outline's own shape at
  the area of a typical 50 × 40, sides rounded to 5 cm (always height × width: "≈ 35 × 60 cm" for a landscape
  screen, "≈ 60 × 35 cm" for an upright one;
  `ZCommonSizes.estimate`). Exact sizes show without "≈" and a lock icon.
- Nested outlines fit each other: only one outline gets its size from the
  common sizes (the detector's outermost, e.g. "With frame"); the outlines
  inside it are measured against it on the straightened plane
  (`ZRectAspect.sizeOnPlane`), so "Artwork" is never larger than "With
  frame", whatever the size's source. A size confirmed in the sheet, a
  measured `artworkSize` (tied to the pre-selected outline) or one from
  the artwork's details (tied to the outermost outline that has its
  shape) is exact for its own outline only; the other outlines are scaled
  from it and stay "≈". The sheet's fields are headed "Dimensions,
  including frame (cm)" on the outermost outline and "Dimensions, without
  frame (cm)" (`ZSizeSheetLabels.dimensionsWithoutFrame`) on an outline
  inside it, so the heading says which outline the confirmed size is for.
  The full photo is not a level: a size confirmed on it is not a
  reference for other outlines.
- `onArtworkSizeConfirmed` reports the size the user confirmed in the
  sheet (after Next, once per confirmed size), whichever outline is
  selected on Next; `onArtworkSize` then carries the selected outline's
  own size.
- `onArtworkSize` reports the size the frame step shows on Next, whatever its
  source: exact, or the "≈" estimate (`ZSizeSource.estimated`, no depth).
- The sheet's fields, common sizes and depth chips take their colours from
  `ZImageEditorTheme.size*` (`sizeFieldColor`, `sizeFieldTextColor`,
  `sizeFieldFocusColor`, `sizeFieldEstimatedColor`, `sizeLabelColor`,
  `sizeHelperColor`, `sizeOption*`); fields are 48 px with a constant 2 px
  border (solid when focused, dashed for an estimate), buttons 48 px.
- `onFrameEvidence` reports what the frame step saw on Next
  (`ZFrameEvidence`: `hasFrame`, `hasMat`, `glassReflections`, `shape`),
  e.g. to suggest the artwork's medium. It comes from the detector's levels
  (`ZFrameCandidate.level`, `matAround`) and the reflection fix / glare hint.

```dart
ZImageEditor(
  enableSizeTools: true,
  artworkSize: const ZArtworkSize(
      heightCm: 50, widthCm: 40, depthCm: 2, source: ZSizeSource.details),
  onArtworkSizeConfirmed: (size) => saveToForm(size),
  ...
)
```

### Photo hints

Pass `photoChecker: const ZPhotoQuality()` to check the photo in the frame
step. At most one banner is shown (in this order): a strong reflection on
the glass, part of the frame outside the photo, too dark, blurry. "Retake"
appears when `onRetake` is set (the app closes the editor and opens the
camera again); "Use anyway" and the cross close the banner. Nothing is ever
blocked. With `onRetake` set, the frame step's tool row also always shows a
Retake tool (camera icon, `ZFrameCropLabels.retakeLabel`), so a good photo can be
retaken too. Texts: `photoHintLabels` (`ZPhotoHintLabels`). Implement
`ZPhotoChecker` for your own checks.

### Safe areas

Pass `edgeToEdge: true` to draw under transparent system bars (light
icons, `SystemUiMode.edgeToEdge`); the controls use the real
`MediaQuery` padding, and in the themed look (or edge to edge) the header
buttons always sit below the status bar / Dynamic Island. Frame and crop
handles keep at least 24 px (or the system back-swipe inset + 12 px) from
the left and right edges. The editor locks to portrait while open and
restores `orientationsAfterClose` (default: all) when it closes. All sheets
use `isScrollControlled` and `useSafeArea`. Tested at 360 × 640 (24/48
insets, and with gesture insets), 375 × 667, 393 × 852 (59/34), 412 × 915
(3-button, 48) and 430 × 932, all at text scale 1.3.

### Round and oval frames

A detector can mark an outline as round or oval
(`ZFrameCandidate(shape: ZFrameShape.round, corners: ...)`); the corners
are then the four corners of the quad the ellipse is inscribed in (it
touches each side at its middle, through the same perspective). The frame
step draws the ellipse with four handles on its sides (dragging one moves
that side) and shows "◯ Round frame found · Wrong?" above the chips while
any outline is round or oval. A tap on that label ("Wrong?" or its text)
opens a Rectangle / Round / Oval menu for the current outline; there are
no shape buttons. Each outline
keeps its own shape (a round mat opening inside a rectangular frame is
fine). On Next a round outline is rectified to a circle (square output),
an oval keeps its measured shape, and outside the ellipse is transparent
(PNG), or `roundFrameFill` (#F5F0F0) when `outputFormat` is JPEG.

### Auto colour fix

With the themed look (`theme.toolRowTabs`), `enableAutoFix: true` puts an
"Auto" chip first in the Adjust tab. The photo is analysed at 256 px
(`ZAutoLevels`): per-channel black/white point stretch (0.5 % clipped,
gain ≤ 2.5), white balance from the brightest near-neutral area (the white
mat or paper, ±15 %) and a mild contrast boost (×1.06). Auto turns itself
on when the photo looks hazy (lifted blacks with a short tonal range, or a
visibly tinted mat) and stays off once the user turns it off. While Auto is
selected a Before/After line can be dragged across the photo. The fix is a
colour matrix, so the preview and the export match (WYSIWYG). Texts:
`autoFixLabels` (`ZAutoFixLabels`).

### Tip sheet before the camera

`showZPhotoTipSheet(context, theme: ...)` shows "Photograph your artwork"
with three tips. It resolves to a `ZPhotoTipResult` when "Take photo" is
tapped (with `dontShowAgain` if the box was ticked) or to `null` when the
sheet is dismissed, in which case no photo should be taken. Persisting
"Don’t show this again" is up to the app. The tips scroll on small phones;
"Take photo" and the checkbox stay in view above the home indicator.

### Theme

`ZImageEditorTheme` holds every colour, font and size of the chrome (header
buttons, chips, tool rows, tabs) and of the frame step (outline, handles,
magnifier). The default reproduces the original iOS-style look; set
`toolRowTabs: true` and `showTitle: true` for a flat tool-row layout.

```dart
ZImageEditor(
  theme: const ZImageEditorTheme(
    backgroundColor: Color(0xFF1C1A1A),
    accentColor: Color(0xFFCE5151),
    primaryButtonColor: Color(0xFFCE5151),
    primaryButtonRadius: 4,
    primaryButtonHeight: 36,
    cancelButtonColor: null, // text button
    fontFamily: 'Jost',
    showTitle: true,
    toolRowTabs: true,
  ),
  ...
)
```

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
