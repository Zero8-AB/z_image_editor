import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:z_image_editor/src/utils/image_format_sniffer.dart';

Uint8List bytes(List<int> head) =>
    Uint8List.fromList([...head, ...List.filled(16, 0)]);

void main() {
  test('detects common image formats from magic bytes', () {
    final i = img.Image(width: 2, height: 2);
    expect(
        imageExtensionFromBytes(Uint8List.fromList(img.encodeJpg(i))), 'jpg');
    expect(
        imageExtensionFromBytes(Uint8List.fromList(img.encodePng(i))), 'png');
    expect(
        imageExtensionFromBytes(Uint8List.fromList(img.encodeGif(i))), 'gif');
    expect(
        imageExtensionFromBytes(Uint8List.fromList(img.encodeBmp(i))), 'bmp');
    expect(
        imageExtensionFromBytes(Uint8List.fromList(img.encodeTiff(i))), 'tiff');
    expect(
      imageExtensionFromBytes(
          bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])),
      'webp',
    );
    expect(
      imageExtensionFromBytes(
          bytes([0, 0, 0, 24, ...'ftyp'.codeUnits, ...'heic'.codeUnits])),
      'heic',
    );
    expect(
      imageExtensionFromBytes(
          bytes([0, 0, 0, 24, ...'ftyp'.codeUnits, ...'avif'.codeUnits])),
      'avif',
    );
    expect(imageExtensionFromBytes(bytes([1, 2, 3])), isNull);
    expect(imageExtensionFromBytes(Uint8List(0)), isNull);
  });
}
