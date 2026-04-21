import 'package:flutter/widgets.dart';
import 'platform_io_web.dart';

/// Web stubs — these code paths are unreachable at runtime because
/// [ImageCanvas] only calls them when [imageFile] is non-null, and on web
/// callers must always supply [imageBytesList] instead.

Widget buildFileImageWidget(
  File file, {
  required BoxFit fit,
  Key? key,
  bool gaplessPlayback = false,
  ImageFrameBuilder? frameBuilder,
}) =>
    throw UnsupportedError('File-backed images are not supported on web. '
        'Use imageBytesList instead.');

ImageProvider buildFileImageProvider(File file) =>
    throw UnsupportedError('File-backed images are not supported on web. '
        'Use imageBytesList instead.');
