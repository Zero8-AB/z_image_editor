/// Cross-platform [File] and [Directory] types for use with [ZImageEditor].
///
/// Import this file instead of `dart:io` when you pass [File] objects to
/// [ZImageEditor.imageFiles] in a codebase that also compiles for web.
///
/// ```dart
/// import 'package:z_image_editor/platform_types.dart';
/// ```
///
/// On mobile this re-exports the real `dart:io` types, so behaviour is
/// identical. On web it exports the package's lightweight stubs, which keeps
/// the code compilable even though `imageFiles` must not be used at runtime on
/// web (pass `imageBytesList` instead).
library;

export 'dart:io' if (dart.library.html) 'src/utils/platform_io_web.dart'
    show File, Directory;
