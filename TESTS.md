# Tests for the frame step and the themed editor

Every button and interactive element of the screens added or changed on
`feat/frame-crop`, and the test that covers it. Widget tests run at
360 × 640 and 390 × 844 unless the name says otherwise
(`safe_area_test.dart` runs six phone profiles at text scale 1.3).
Run all with `flutter test`.

Items refer to the frame-crop plan: 1 Edit image opens the editor ·
2 frame step look · 3 measurement lines · 4 tip sheet · 5 right shape ·
6 size sheet · 7 photo hints · 8 Auto colour fix · 9 round / oval frames ·
10 safe areas · 11 live camera (app) · 12 depth sensor (app) ·
13 medium suggestion (evidence here, the form in the app).
"Edit image" (1), the live camera (11) and the depth sensor (12) are app
screens: see `TESTS.md` in the Monogram app.

## Frame step ("Choose what to keep")

| Item | Element | Test (file › name) |
|---|---|---|
| 2 | Title, chips in order (Artwork · No frame · With frame), With frame pre-selected | `frame/frame_step_design_test.dart` › title, chips in order, With frame pre-selected |
| 2 | Each chip selects its outline | `frame_step_design_test` › each chip selects its outline; `frame_crop_view_test` › tapping a chip moves the handles to that outline |
| 2 | Chips: 44 px tap area, 40 px pill | `frame_step_design_test` › chips have a 44 px tap area and a 40 px pill |
| 2 | "· edited" chip label after a drag | `frame_step_design_test` › edited chip reads "… · edited" |
| 2 | Corner drag + magnifier (red crosshair) | `frame_step_design_test` › corner drag shows the magnifier with a red crosshair; `frame_crop_view_test` › dragging a corner moves it…, shows the magnifier only while dragging, a corner cannot be dragged across another |
| 2 | Tap on the photo cycles outlines | `frame_step_design_test` › tap on the photo cycles the outlines; `frame_crop_view_test` › tapping the photo cycles chips, then full photo, then around |
| 2 | Red selected outline, dashed alternatives, ringed handles | `frame_step_design_test` › selected outline is red, others dashed; handles ringed |
| 2 | Tool row: Rotate, Full photo, Reset (disabled when clean) | `frame_step_design_test` › tool row: Rotate, Full photo, Reset (greyed when clean); `frame_crop_view_test` › Reset restores the default outline and is greyed when clean, Full photo puts the handles at the image corners, Rotate turns the view… |
| 2 | No reflections toggle | `frame_step_design_test` › No reflections toggle is red when on, tap compares; `frame_crop_view_test` › enhancer toggle group |
| 2 | Tool buttons ≥ 44 px | `frame_step_design_test` › tool buttons are at least 44 px tall |
| 2 | Next / Cancel | `frame_step_design_test` › Next and Cancel; `frame_crop_view_test` › Continue warps…, Cancel calls onCancel, Next is disabled and busy while the detector runs |
| 2 | Next waits for the enhanced image (decoded, also when reopened) | `frame_crop_view_test` › Next stays disabled until the enhanced image is decoded; reopened: Next waits for the cached enhanced image |
| 2 | Next with a photo the `image` package can't read (HEIC): engine decode, EXIF orientation and size cap as the Dart path; error dialog text from `ZFrameCropLabels` | `frame/engine_decode_fallback_test.dart` (all); `editor/image_processing_test` › decodes via the engine when the image package cannot (HEIC) |
| 3 | Size tool label (≈ … · Check / exact) | `frame/frame_size_tools_test.dart` › estimated: "≈ … · Check" and ≈ lines, known size: no ≈…, no matching size: a rough size in the outline’s shape |
| 3 | Nested outlines fit each other (Saturn print: "Artwork" < "No frame" < "With frame"); a confirmed or measured size is exact on its own outline and scales the others; reopen, Rotate, drags, the sheet's fields | `frame/nested_size_test.dart` › nested levels groups; `frame/nested_size_review_test.dart` › every source × outline (details, measured, confirmed, estimate), Reset after a drag, sheet heading, editor callbacks; `rect_aspect_test` › ZRectAspect.sizeOnPlane |
| 3 | No common size has the shape (TV, 16 : 9): "≈ 35 × 60 cm · Check" landscape, "≈ 60 × 35 cm" upright (height × width), with lines | `nested_size_test` › no common size has the shape; `nested_size_review_test` › a landscape 16 : 9 screen; `artwork_size_test` › estimate… |
| 3, 5 | Details size used only when its H : W is within 12 % of the outline's estimate; another shape or swapped H/W falls back to "≈ … · Check" | `frame_size_tools_test` › known size: no ≈… (A3 vs 4 : 3); known size of another shape (60 × 30) / height and width swapped (30 × 40): estimate, "≈ … · Check" |
| 3 | Measurement lines (≈ vs confirmed), inside the screen | `frame_size_tools_test` › estimated…, Size opens the sheet; Confirm locks the size, lines stay inside the screen for a full-width outline |
| 3 | Lines on a small outline (label only, scaled) | `frame/measurement_lines_test.dart` › a large outline…; an outline shorter than its label: label only, scaled down |
| 5 | Right shape (perspective + EXIF focal across the diagonal; without EXIF 26 mm, solved only for another lens; real photos of a TV, a felt board and a framed poster from the side within 1.5 %) | `frame/rect_aspect_test.dart` (all); `frame_size_tools_test` › known size: … Next gives it the real shape; `artwork_size_test` › warpOutputSize keeps the real shape when given |
| 7 | Photo hint banner: copy + icon per issue, only one | `frame/photo_hint_test.dart` › {issue}: exact copy, its icon, one banner; no issue: no banner |
| 7 | Retake | `photo_hint_test` › Retake calls back and keeps the hint; without onRetake there is no Retake |
| 7 | Use anyway | `photo_hint_test` › Use anyway closes the hint |
| 7 | Dismiss (×, 44 px) | `photo_hint_test` › the cross dismisses the hint (44 px target) |
| 7 | Hint state across Next / ‹ Frame; failing checker | `photo_hint_test` › Next works with the hint shown…, reopening the step…, a failing checker shows nothing |
| 7 | Classifiers | `frame/photo_quality_test.dart` (all) |
| 9 | "◯ Round frame found · Wrong?" label; no shape buttons; ellipse handles | `frame/round_frame_test.dart` › round outer frame: label, ellipse handles, no shape buttons; only rectangles: no shape label; an oval frame shows "Oval frame found" |
| 9 | Wrong? → menu → Oval / Rectangle / Round; Reset | `round_frame_test` › Wrong? → Oval changes the label, the result and Reset; Wrong? → Rectangle: plain outline, label stays to undo |
| 9 | Menu dismissed | `round_frame_test` › dismissing the menu changes nothing |
| 9 | Each level keeps its own shape | `round_frame_test` › each level keeps its own shape |
| 9 | Side handle drag + magnifier | `round_frame_test` › dragging the top handle moves the top side, with magnifier |
| 9 | Round = circle (size ≈ 50 × 50, square output) | `round_frame_test` › a round frame is measured as a circle |
| 9 | Transparent outside / #F5F0F0 for JPEG | `round_frame_test` › geometry group; editor group (PNG / auto … transparent, JPEG … #F5F0F0) |
| 10 | Safe areas, handles off the edges, text scale 1.3 | `frame/safe_area_test.dart` › frame step: inside the safe area, handles off the edges (6 phones) |
| 9 | Shape pill and chips never overlap (pill and chips in their own rows, 8 px apart; 360 × 640 … 430 × 932, text scale 1 and 1.3); a tap on the chip under the pill selects it | `frame/frame_bottom_bar_test.dart` › shape pill and chips never overlap ({phone} @ {scale}) |
| 9 | Wrong? opens the menu on the first tap every time: after a pick, after confirming the size, during the last menu's slide-out; a tap anywhere on the pill opens it | `frame_bottom_bar_test` › Wrong? → pick → Wrong? again opens on the first tap; after confirming the size, Wrong? opens on the first tap; a tap while the last menu still slides away opens it |
| 2, 3 | Bottom bar never shifts: chips keep their size when selected; tool icons on one line; "≈ 50 × 50 cm · Check" fits in two reserved lines; confirming the size moves no button | `frame_bottom_bar_test` › selecting chips and changing shapes moves no chip or tool; "≈ 50 × 50 cm · Check" fits in two lines; confirming the size moves no other button |

## Size sheet ("Real size of the artwork")

| Item | Element | Test |
|---|---|---|
| 6 | Opens from the Size tool | `frame_size_tools_test` › Size opens the sheet; Confirm locks the size |
| 6 | Best-fit preset pre-filled, orientation-aware presets | `frame/size_sheet_test.dart` › best fit: estimated shape, presets, 50 × 40 pre-filled; `artwork_size_test` › upright art gets upright sizes… |
| 6 | Each common size | `size_sheet_test` › each common size fills height and width |
| 6 | Each depth chip (Paper 0.1 · Canvas 2 · Deep canvas 4 · Framed 3) | `size_sheet_test` › each depth chip sets the depth |
| 6 | Fields; auto-fill of the other side | `size_sheet_test` › typing a side fills in the other (≈) from the shape; typed depth replaces the default |
| 6 | Confirm text / disabled | `size_sheet_test` › Confirm returns the size; disabled without both sides |
| 6 | "I don't know…" (keep estimate) | `size_sheet_test` and `frame_size_tools_test` (`z_size_keep`) |
| 6 | Keyboard state | `size_sheet_test` › keyboard open: Confirm pinned above it…; `safe_area_test` › size sheet: Confirm above the home bar and the keyboard |
| 6 | Keyboard: tapping Height / Width / Depth keeps focus and the same field while the keyboard opens (no blink); the field scrolls above Confirm, Confirm above the keyboard; typing updates Confirm (3 phones, text scale 1.3, estimated ≈ depth) | `frame/size_sheet_keyboard_test.dart` › keyboard @ {phone} group |
| 6 | Common sizes and depth chips do not move when one is picked, or when typing clears the pick (button and label rects) | `size_sheet_keyboard_test` › presets stay put group |
| 6 | Look (app's rose form style via theme): headings and Height / Width / Depth labels Jost 18 #282525 under "Dimensions, including frame (cm)", no "(cm)" on labels, no × separators; helper "Depth: Default 2 cm · change if needed" 14 #6F6767 | `frame/size_sheet_style_test.dart` › headings and labels: 18 px charcoal, no "(cm)", no × |
| 6 | Fields: #FCD6D7 fill, #B63B3B Jost 18, 48 px, radius 4, constant 2 px border in the fill colour (no idle border), text 12 px inside, 16 px between fields | `size_sheet_style_test` › fields: rose, 48 px, falu 18, 16 px apart, no idle border |
| 6 | Estimated value ("≈ 2"): 2 px dashed #B63B3B; focused: 2 px solid #B63B3B; the field keeps its size | `size_sheet_style_test` › estimated depth: 2 px dashed falu; focus: 2 px solid falu; the field keeps its size |
| 6 | Common-size buttons: 48 px, Jost 16, unselected #FCD6D7 / #B63B3B, selected #B63B3B / #FCFCFC with "Best fit" #FCD6D7 12; same border and weight in both states | `size_sheet_style_test` › common sizes: 48 px, Jost 16; rose / falu, selected falu / light…; no jump: `size_sheet_keyboard_test` › presets stay put group |
| 6 | Depth chips: Jost 16 pills, same colours, as wide as their label, side by side in wrapping rows | `size_sheet_style_test` › depth chips: pills in Jost 16…; `size_sheet_keyboard_test` › presets stay put group |
| 6 | Theme colours (`ZImageEditorTheme.size*`), package defaults neutral | `size_sheet_style_test` › package defaults stay neutral |
| 6 | Typing clears / re-selects the common size; a preset fills both fields; a typed depth deselects the chip; Confirm reads H × W × D | `size_sheet_keyboard_test` › manual entry and presets group |
| 6 | Known size, small phone scroll | `size_sheet_test` › known size: fields filled, depth kept; the sheet scrolls on a small phone |
| 6 | Confirmed size reported | `frame_size_tools_test` › editor reports a confirmed size after Next |
| 6 | "Estimated shape" is the photo's, not the confirmed size's | `frame_size_tools_test` › the sheet shows the photo’s estimate after a confirm |

## Frame evidence (medium suggestion in the app)

| Item | Element | Test |
|---|---|---|
| 13 | `ZFrameEvidence.fromCandidates`: artwork only → no frame; frame + artwork; frame + light mat; mat without a frame is no mat; no levels: 2+ nested outlines = frame; shape of the outermost outline incl. "Wrong?" | `frame/frame_evidence_test.dart` › ZFrameEvidence.fromCandidates group |
| 13 | `FrameCropResult.evidence`: none before detection / without outlines; glass from the reflection fix or the glare hint | `frame_evidence_test` › FrameCropResult.evidence group |
| 13 | `ZImageEditor.onFrameEvidence` on Next (levels and mat kept through the frame step); nothing found: not called | `frame_evidence_test` › ZImageEditor.onFrameEvidence group |

## Tip sheet ("Photograph your artwork")

| Item | Element | Test |
|---|---|---|
| 4 | Title, three tips, actions | `frame/tip_sheet_test.dart` › shows the title, the three tips and the actions |
| 4 | Take photo | `tip_sheet_test` › Take photo closes the sheet: dontShowAgain false |
| 4 | Don't show again | `tip_sheet_test` › ticking "Don’t show this again"… (persisting: app tests) |
| 4 | Dismiss | `tip_sheet_test` › dismissing the sheet gives null (no photo) |
| 4, 10 | Safe area, text scale 1.3 | `tip_sheet_test` › safe area…, text scale 1.3 on 360 x 640…; `safe_area_test` › tip sheet: Take photo above the home bar |

## Shape menu (Rectangle / Round / Oval)

| Item | Element | Test |
|---|---|---|
| 9 | Each option, current one ticked | `round_frame_test` › Wrong? → Oval…, Wrong? → Rectangle…, dismissing the menu changes nothing |
| 10 | Above the home bar, 44 px rows | `safe_area_test` › shape menu: options above the home bar |

## Editor after the frame step ("Edit photo")

| Item | Element | Test |
|---|---|---|
| 1, 2 | Title "Edit photo", ‹ Frame, Save | `frame/editor_themed_test.dart` › Next: "Edit photo", ‹ Frame and Save in the header |
| 1, 2 | ‹ Frame back and Next again | `editor_themed_test` › ‹ Frame goes back to the frame step and Next returns; `editor_frame_integration_test` › Next warps, continues in the editor, and Frame goes back |
| 1, 6 | ‹ Frame → change the size → Next re-cuts to the new shape | `frame_size_tools_test` › reopen → change the size → Next uses the new shape |
| 1, 2 | Cancel in the first frame step | `editor_themed_test` › Cancel in the frame step cancels the editor; `editor_frame_integration_test` › Cancel in the first frame step cancels the editor |
| 2 | Crop / Adjust tool-row tabs | `editor_themed_test` › Crop and Adjust tabs switch; Adjust shows its chips; `editor_frame_integration_test` › themed tool-row tabs switch tabs |
| 2 | Save | `editor_themed_test` › Save hands back one edited image |
| 8 | Auto chip first, on for hazy photos, hint | `editor/auto_fix_test.dart` › hazy photo: Auto first and on, compare with hint |
| 8 | Auto one tap off / on | `auto_fix_test` › one tap turns Auto off, another turns it back on |
| 8 | Before/After compare slider | `auto_fix_test` › dragging moves the compare line |
| 8 | Brightness / Contrast / Colour chips + ruler | `auto_fix_test` › Brightness / Contrast / Colour show the ruler, no compare |
| 8 | Clear photo: Auto offered but off | `auto_fix_test` › a clear photo: Auto offered but off |
| 8 | Auto in the export (WYSIWYG) | `auto_fix_test` › Auto is baked into the export (WYSIWYG); Save exports with Auto applied |
| 8 | Hazy detection, white balance | `auto_fix_test` › ZAutoLevels group |
| 10 | Header below the status bar / Dynamic Island, edge to edge | `safe_area_test` › editor: header and tools inside the safe area |
