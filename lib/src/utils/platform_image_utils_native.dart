import 'dart:io';
import 'package:flutter/widgets.dart';

/// Build an [Image] widget backed by a [dart:io] File.
Widget buildFileImageWidget(
  File file, {
  required BoxFit fit,
  Key? key,
  bool gaplessPlayback = false,
  ImageFrameBuilder? frameBuilder,
}) =>
    Image.file(
      file,
      key: key,
      fit: fit,
      gaplessPlayback: gaplessPlayback,
      frameBuilder: frameBuilder,
    );

/// Build an [ImageProvider] backed by a [dart:io] File.
ImageProvider buildFileImageProvider(File file) => FileImage(file);
