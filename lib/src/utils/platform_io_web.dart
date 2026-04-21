import 'dart:typed_data';

/// Web stubs for the [dart:io] types used by this package.
///
/// Loaded only on web via conditional imports; native builds use the real
/// dart:io. These stubs exist solely for compilation — the code paths that
/// reach File/Directory/Platform are never executed on web because the widget
/// requires [imageBytesList] on web instead of [imageFiles].
class File {
  final String path;
  const File(this.path);

  Future<Uint8List> readAsBytes() => throw UnsupportedError(
        'dart:io File is not supported on web. '
        'Pass imageBytesList instead of imageFiles.',
      );

  Future<File> writeAsBytes(List<int> bytes, {bool flush = false}) =>
      throw UnsupportedError('dart:io File write is not supported on web.');
}

class Directory {
  final String path;
  const Directory(this.path);
  static Directory get systemTemp => const Directory('/tmp');
}

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
}
