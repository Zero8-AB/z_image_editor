import 'dart:typed_data';

/// Detects an encoded image's format from its magic bytes and returns the
/// usual file extension (without dot): `jpg`, `png`, `webp`, `gif`, `heic`,
/// `avif`, `bmp`, `tiff`, or null when unknown.
String? imageExtensionFromBytes(Uint8List b) {
  bool at(int offset, List<int> sig) {
    if (b.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'png';
  }
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'webp';
  if (at(0, 'GIF87a'.codeUnits) || at(0, 'GIF89a'.codeUnits)) return 'gif';
  if (at(0, 'BM'.codeUnits)) return 'bmp';
  if (at(0, const [0x49, 0x49, 0x2A, 0x00]) ||
      at(0, const [0x4D, 0x4D, 0x00, 0x2A])) {
    return 'tiff';
  }
  // ISO-BMFF: "ftyp" box at offset 4, major brand at 8.
  if (at(4, 'ftyp'.codeUnits) && b.length >= 12) {
    final brand = String.fromCharCodes(b.sublist(8, 12));
    if (brand == 'avif' || brand == 'avis') return 'avif';
    if (const {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1'}
        .contains(brand)) {
      return 'heic';
    }
  }
  return null;
}
