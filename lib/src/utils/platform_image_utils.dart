// Conditional export: native uses real dart:io, web uses stub.
export 'platform_image_utils_native.dart'
    if (dart.library.html) 'platform_image_utils_web.dart';
