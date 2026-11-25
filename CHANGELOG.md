# Changelog

## Unreleased

### Features

* frame evidence (`onFrameEvidence`, `ZFrameEvidence`, `ZFrameLevel`, `ZFrameCandidate.level` / `matAround`, `FrameCropResult.evidence`): frame, mat, glass reflections and shape seen in the frame step, for medium suggestions
* size sheet restyle: labels Height / Width / Depth under "Dimensions, including frame (cm)", no × separators, 48 px fields and buttons, colours from `ZImageEditorTheme.size*` (neutral defaults)
* `FrameMeasurementLines` is exported (the app draws measured sizes on its live camera)
* safe areas (`edgeToEdge`, `orientationsAfterClose`): edge-to-edge with transparent bars and light icons, header buttons always below the status bar / Dynamic Island in the themed look, handles kept out of the system back-swipe areas (≥ 24 px), photo hint capped on small screens (its text scrolls, buttons stay), editor locks to portrait and restores the app's orientations
* round and oval frames (`ZFrameShape`, `ZFrameCandidate.shape`, `ZFrameShapeLabel`, `showZFrameShapeMenu`, `roundFrameFill`): the detector's shape per outline; elliptical outline with four side handles; "Round frame found · Wrong?" with a Rectangle / Round / Oval menu (no shape buttons); round outlines are rectified to a circle; outside the ellipse is transparent (filled with #F5F0F0 for JPEG output); square common sizes (50 × 50 …)
* "Auto" colour fix in the themed Adjust tab (`enableAutoFix`, `ZAutoLevels`, `ZAutoFixLabels`): per-channel black/white stretch, white balance from the white mat, mild contrast; turns itself on for hazy photos (lifted blacks with a short range, or a tinted mat), one tap turns it off, Before/After drag-compare, part of the export
* frame step restyled per the approved design: dashed alternative outlines, ringed handles, 44 px chip tap areas, new line icons
* artwork size tools (`enableSizeTools`, `artworkSize`, `onArtworkSizeConfirmed`): Size tool, red measurement lines (≈ estimated / exact), "Real size of the artwork" sheet with common sizes, auto-fill of the other side and depth picks
* photo hints in the frame step (`photoChecker`, `ZPhotoQuality`, `ZPhotoIssue`, `onRetake`, `ZPhotoHintLabels`): at most one calm banner for glare, cut-off frame, darkness or blur, with Retake / Use anyway / dismiss; never blocks
* tip sheet before the camera (`showZPhotoTipSheet`, `ZPhotoTipSheet`, `ZPhotoTipLabels`): three photo tips, "Take photo" and "Don’t show this again" (the app persists the choice)
* straightened images keep the real shape (`ZRectAspect`: perspective aspect ratio with the EXIF focal length; `warpOutputSize(aspectWH:)`)
* optional perspective "frame" step (`frameDetector`, `startWithFrameCrop`, `ZFrameCandidate`, `ZQuadMath`, `ZPerspectiveWarp`): choose a four-corner outline from up to three detector suggestions or drag the corners (with magnifier), rotate, then continue editing the straightened image
* optional enhancer toggle in the frame step (`imageEnhancer`, `ZImageEnhancer`), on by default
* `ZImageEditorTheme` for the editor chrome and the frame step; the default keeps the current look
* frame step: output capped at 6000 px (`ZPerspectiveWarp.defaultMaxOutputSide`), palette/1-bit sources supported, Next disabled while detection/enhancement runs, load errors shown with Cancel, edits kept when the outline is unchanged

### Bug Fixes

* measurement lines no longer overflow when the outline is shorter than its label (the label is shown alone, scaled down)
* unmodified images are returned as a byte-identical copy in a new temp file with the correct extension (from the magic bytes), never as the caller's own `File` and never as `.tmp`
* undo/redo map the crop rect to the current canvas size
* unmodified images are returned without re-encoding again (the initial fitted crop rect counted as an edit)
* the crop rect stays on the same image area when the canvas changes height (switching tabs, aspect-ratio strip)
* `TransformationService.clampPanOffset` no longer throws when the allowed pan range is empty
* the pixel fallback export applies brightness/contrast/saturation like the preview (brightness used to turn the image white or black)

## [0.9.0](https://github.com/Zero8-AB/z_image_editor/compare/v0.8.2...v0.9.0) (2026-05-25)


### Features

* skip re-encoding unmodified images and add output format control ([#112](https://github.com/Zero8-AB/z_image_editor/issues/112)) ([55bc024](https://github.com/Zero8-AB/z_image_editor/commit/55bc0246c5e55b4de1c4cb5ffff2702f54bdfbbc))

## [0.8.2](https://github.com/Zero8-AB/z_image_editor/compare/v0.8.1...v0.8.2) (2026-04-21)


### Bug Fixes

* use native PNG encoder on web to fix save freeze ([#76](https://github.com/Zero8-AB/z_image_editor/issues/76)) ([8ac1a53](https://github.com/Zero8-AB/z_image_editor/commit/8ac1a5394077772bc11fd01a9bc9996e902e804d))

## [0.8.1](https://github.com/Zero8-AB/z_image_editor/compare/v0.8.0...v0.8.1) (2026-04-21)


### Bug Fixes

* add platform_types.dart to resolve dart:io File type conflict on web ([#74](https://github.com/Zero8-AB/z_image_editor/issues/74)) ([e10b8cd](https://github.com/Zero8-AB/z_image_editor/commit/e10b8cd6531b7261384417238d03961b765e1b7a))

## [0.8.0](https://github.com/Zero8-AB/z_image_editor/compare/v0.7.0...v0.8.0) (2026-04-21)


### Features

* Add web support ([#73](https://github.com/Zero8-AB/z_image_editor/issues/73)) ([06b01b4](https://github.com/Zero8-AB/z_image_editor/commit/06b01b49915063460a85dc8bfe2bb75360727e8f))


### Bug Fixes

* update tab selector to include context and adjust layout for safe areas on iOS and Android ([#71](https://github.com/Zero8-AB/z_image_editor/issues/71)) ([1e10fb9](https://github.com/Zero8-AB/z_image_editor/commit/1e10fb9123dbbb34e7e726a4f4b9db6b9c9c76b7))

## [0.7.0](https://github.com/Zero8-AB/z_image_editor/compare/v0.6.1...v0.7.0) (2026-04-16)


### Features

* batch image editing ([#63](https://github.com/Zero8-AB/z_image_editor/issues/63)) ([#65](https://github.com/Zero8-AB/z_image_editor/issues/65)) ([76f5605](https://github.com/Zero8-AB/z_image_editor/commit/76f5605c147c64b9fd18fcf34c6984fae9d11055))

## [0.6.1](https://github.com/Zero8-AB/z_image_editor/compare/v0.6.0...v0.6.1) (2026-03-27)


### Bug Fixes

* update button text color for better visibility in iOS-style editor ([#40](https://github.com/Zero8-AB/z_image_editor/issues/40)) ([a5991da](https://github.com/Zero8-AB/z_image_editor/commit/a5991da1396a63913d566578be4d3edbdc5577e8))

## [0.6.0](https://github.com/Zero8-AB/z_image_editor/compare/v0.5.1...v0.6.0) (2026-03-27)


### Features

* add portrait orientation support for aspect-ratio presets ([#39](https://github.com/Zero8-AB/z_image_editor/issues/39)) ([ada52c6](https://github.com/Zero8-AB/z_image_editor/commit/ada52c69de9f05a192bf31d3b0837b928b20c77a))
* Feature/undo redo ([#37](https://github.com/Zero8-AB/z_image_editor/issues/37)) ([36ff926](https://github.com/Zero8-AB/z_image_editor/commit/36ff926c64e15a37e01f4e33f1f6a2f22483866d))

## [0.5.1](https://github.com/Zero8-AB/z_image_editor/compare/v0.5.0...v0.5.1) (2026-03-18)


### Bug Fixes

* Fix/magnifying glass precision ([#26](https://github.com/Zero8-AB/z_image_editor/issues/26)) ([0ba0f13](https://github.com/Zero8-AB/z_image_editor/commit/0ba0f136b39ca24fb80e81c2fe2aed303fd00edf))

## [0.5.0](https://github.com/Zero8-AB/z_image_editor/compare/v0.4.1...v0.5.0) (2026-03-18)


### Features

* implement magnifying-glass loupe for precise crop boundary alig… ([#25](https://github.com/Zero8-AB/z_image_editor/issues/25)) ([e80cad0](https://github.com/Zero8-AB/z_image_editor/commit/e80cad0ceb4942e18b02c0a852257a0beef75ffe))


### Bug Fixes

* Fix/red blue dots ([#23](https://github.com/Zero8-AB/z_image_editor/issues/23)) ([daa77fe](https://github.com/Zero8-AB/z_image_editor/commit/daa77fe5f22caa6ad257097eefc646bc62725b42))

## [0.4.1](https://github.com/Zero8-AB/z_image_editor/compare/v0.4.0...v0.4.1) (2026-03-12)


### Bug Fixes

* update to newer matrix transformation methods for compatibility ([#16](https://github.com/Zero8-AB/z_image_editor/issues/16)) ([202b016](https://github.com/Zero8-AB/z_image_editor/commit/202b0162774c3293615be3becf766da99ddd0b81))

## [0.4.0](https://github.com/Zero8-AB/z_image_editor/compare/v0.3.0...v0.4.0) (2026-03-12)


### Features

* add Android support with initial configuration and UI adjustments ([#15](https://github.com/Zero8-AB/z_image_editor/issues/15)) ([97280c8](https://github.com/Zero8-AB/z_image_editor/commit/97280c82e806b0d2af8fc2dbfc114ba08d83377b))
* UI updates ([#11](https://github.com/Zero8-AB/z_image_editor/issues/11)) ([90255ab](https://github.com/Zero8-AB/z_image_editor/commit/90255ab8b024e22a8dee70263b5ec88b945f33c9))

## [0.3.0](https://github.com/Zero8-AB/z_image_editor/compare/v0.2.0...v0.3.0) (2026-03-11)


### Features

* Add comprehensive architecture documentation for Monogram Image Editor ([3102120](https://github.com/Zero8-AB/z_image_editor/commit/31021204c6e0c7d763d4b648f914be0e25810d96))
* Enhance crop overlay with animated background fade during handle drag ([2ae22e9](https://github.com/Zero8-AB/z_image_editor/commit/2ae22e9a3c5f0a4795de56514e2b147048efe5ab))
* Implement TransformationService for image transformations ([e090ef0](https://github.com/Zero8-AB/z_image_editor/commit/e090ef098d371932060bc0970a2fa7a5c4219686))
* Improve CropOverlay with aspect ratio constraints ([e090ef0](https://github.com/Zero8-AB/z_image_editor/commit/e090ef098d371932060bc0970a2fa7a5c4219686))


### Bug Fixes

* Enhance ImageCanvas for better image handling and transformations ([e090ef0](https://github.com/Zero8-AB/z_image_editor/commit/e090ef098d371932060bc0970a2fa7a5c4219686))
* refactor to a pub package ([#2](https://github.com/Zero8-AB/z_image_editor/issues/2)) ([62c0e75](https://github.com/Zero8-AB/z_image_editor/commit/62c0e75f5acb5558e0f0d7df6b3dbbea355bd785))
* update release-please configuration to include component in tag ([#9](https://github.com/Zero8-AB/z_image_editor/issues/9)) ([d08b05c](https://github.com/Zero8-AB/z_image_editor/commit/d08b05c96fc7d413212ba17719978e0c7e923a82))
* update release-please-action to version 4.4.0 and add .gitignore for workflow logs ([#6](https://github.com/Zero8-AB/z_image_editor/issues/6)) ([4e37179](https://github.com/Zero8-AB/z_image_editor/commit/4e37179c02fab13185b780c55b2f591528dd9ef7))

## [0.2.0](https://github.com/Zero8-AB/z_image_editor/compare/z_image_editor-v0.1.0...z_image_editor-v0.2.0) (2026-03-11)


### Features

* Add comprehensive architecture documentation for Monogram Image Editor ([3102120](https://github.com/Zero8-AB/z_image_editor/commit/31021204c6e0c7d763d4b648f914be0e25810d96))
* Enhance crop overlay with animated background fade during handle drag ([2ae22e9](https://github.com/Zero8-AB/z_image_editor/commit/2ae22e9a3c5f0a4795de56514e2b147048efe5ab))
* Implement TransformationService for image transformations ([e090ef0](https://github.com/Zero8-AB/z_image_editor/commit/e090ef098d371932060bc0970a2fa7a5c4219686))
* Improve CropOverlay with aspect ratio constraints ([e090ef0](https://github.com/Zero8-AB/z_image_editor/commit/e090ef098d371932060bc0970a2fa7a5c4219686))


### Bug Fixes

* Enhance ImageCanvas for better image handling and transformations ([e090ef0](https://github.com/Zero8-AB/z_image_editor/commit/e090ef098d371932060bc0970a2fa7a5c4219686))
* refactor to a pub package ([#2](https://github.com/Zero8-AB/z_image_editor/issues/2)) ([62c0e75](https://github.com/Zero8-AB/z_image_editor/commit/62c0e75f5acb5558e0f0d7df6b3dbbea355bd785))
* update release-please-action to version 4.4.0 and add .gitignore for workflow logs ([#6](https://github.com/Zero8-AB/z_image_editor/issues/6)) ([4e37179](https://github.com/Zero8-AB/z_image_editor/commit/4e37179c02fab13185b780c55b2f591528dd9ef7))

## 0.1.0

- Initial release
- iOS-style image editor with dark theme
- Crop feature with aspect ratio presets (Free, Square, 4:3, 16:9)
- Rotate feature with 90° rotation, flip horizontal/vertical, and fine-tune slider
- Adjust feature with brightness, contrast, and saturation controls
- Real-time preview for all adjustments
- Integration with image_picker for camera and gallery selection
