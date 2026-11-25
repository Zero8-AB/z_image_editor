library;

// Main widget
export 'src/z_image_editor_widget.dart' show ZImageEditor;

// Perspective "frame" step: detector interface, labels, quad math and warp
export 'src/frame/frame_detector.dart';
export 'src/theme/z_image_editor_theme.dart';
export 'src/frame/quad_math.dart';
export 'src/frame/rect_aspect.dart';
export 'src/frame/artwork_size.dart';
export 'src/frame/size_sheet.dart';
export 'src/frame/tip_sheet.dart';
export 'src/frame/photo_quality.dart';
export 'src/frame/photo_hint_banner.dart';
export 'src/frame/perspective_warp.dart';

// Models (for advanced usage)
export 'src/models/image_editor_state.dart';
export 'src/models/image_output_format.dart';
export 'src/models/crop_toolbar_settings.dart';
export 'src/models/crop_tab_settings.dart';
export 'src/models/adjust_tab_settings.dart';

// Controller
export 'src/controller/image_editor_controller.dart';

// Utilities (for advanced usage)
export 'src/utils/transformation_service.dart';
