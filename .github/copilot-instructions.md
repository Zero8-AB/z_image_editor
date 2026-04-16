# Project Guidelines

## Code Style

- Follow the Flutter lint baseline in `analysis_options.yaml` and preserve the existing style in `lib/` and `test/`.
- Keep `ImageEditorState` immutable and value-based. State changes should flow through `copyWith()` in the controller rather than mutating fields in widgets.
- Prefer the existing `ChangeNotifier` + `ListenableBuilder` pattern over adding a new state-management layer for package work.
- Keep the public API deliberate. Only update exports in `lib/image_editor.dart` and `lib/z_image_editor.dart` when the task intentionally changes package surface area.

## Architecture

- Read `ARCHITECTURE.md` before changing crop, pan/zoom, rotation, or export behavior. The transform pipeline and invariants are documented there and are part of the implementation contract.
- Keep responsibilities split by layer:
  - `lib/src/controller/image_editor_controller.dart` owns mutations, animation coordination, and editor invariants.
  - `lib/src/utils/transformation_service.dart` owns coordinate conversion, clamping, and rotation-aware scale math.
  - `lib/src/utils/image_processing.dart` owns export rendering.
  - `lib/src/widgets/` owns UI composition and gesture handling.
- Do not duplicate transform or coordinate-space math in widgets when it belongs in `TransformationService`.
- Preserve WYSIWYG export behavior: on-screen transforms and exported output must stay aligned.

## Build and Test

- Run these repo-level checks for package changes:
  - `flutter pub get`
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test`
- Run a single test file: `flutter test test/widget_test.dart`
- Run a single test by name: `flutter test --name "ImageEditorState copyWith"`
- When changing the example app, also run in `example/`:
  - `flutter pub get`
  - `flutter analyze`
- Run `flutter pub publish --dry-run` when changing package metadata, assets, or public API.

## Coordinate Spaces

Three distinct spaces are used throughout the geometry code — confusing them causes subtle bugs:

| Space | Units | Origin |
|---|---|---|
| **Viewport space** | Screen pixels | Top-left of `ImageCanvas` widget |
| **Image space** | Source image pixels | Top-left of the source image |
| **Crop-rect space** | Viewport fractions 0.0–1.0 | Top-left of the viewport |

`CropRect` stores `{left, top, width, height}` as **viewport fractions**, not pixels. `panOffset` and focal points are in **viewport space**. `TransformationService` is the only place that converts between spaces.

The canvas transform matrix is `M = T(pan) × S(minScaleForRotation × userScale) × R(totalRotation) × S(flip)`. `minScaleForRotation` is the minimum scale that keeps the rotated image covering the full viewport; `userScale` is the additional user zoom on top.

## Conventions

- This package currently targets non-web Flutter platforms and depends on `dart:io`. Do not introduce web assumptions unless the task explicitly adds web support.
- Crop behavior is constraint-driven: clamp image movement and transforms to keep the crop window covered instead of silently changing the user’s crop selection.
- In crop mode, pan/zoom clamping uses exact raycasting (`clampPanToCoverCrop`); outside crop mode, the faster AABB clamp (`clampPanOffset`) is used instead.
- After 1 second of idle the crop box animates to fill the full viewport (snap animation). A `Timer` in `ImageCanvas` drives this; it is cancelled on gesture start and rescheduled on gesture end.
- Treat `build/`, `example/build/`, `example/ios/Pods/`, and Flutter-generated platform artifacts as generated output. Do not edit them unless the task is explicitly about native/project generation.
- The example app demonstrates integration, but package implementation changes belong under `lib/`.
- Use Conventional Commits in commit or PR titles when asked to prepare releaseable changes: `fix:` for patch, `feat:` for minor pre-1.0, and `BREAKING CHANGE:` for breaking releases.
