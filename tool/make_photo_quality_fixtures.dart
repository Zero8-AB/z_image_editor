// Writes the photo-hint test fixtures (test/fixtures/photo_quality/*.jpg):
// a framed artwork on a wall, and variants with glare, blur, darkness and a
// cut-off frame. Deterministic; run from the package root with
//   dart run tool/make_photo_quality_fixtures.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const w = 512, h = 384;
const dir = 'test/fixtures/photo_quality';

img.Image scene({int dx = 0, bool flat = false, bool white = false}) {
  final rnd = math.Random(7);
  final im = img.Image(width: w, height: h);
  int n(int v, int amp) => (v + rnd.nextInt(2 * amp + 1) - amp).clamp(0, 255);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Wall, then frame, mat and painting (stripes, a sun, texture).
      final fx = x - dx;
      int r = 207, g = 202, b = 194;
      if (fx >= 136 && fx < 376 && y >= 32 && y < 352) {
        r = 30;
        g = 28;
        b = 28; // frame
        if (fx >= 148 && fx < 364 && y >= 44 && y < 340) {
          r = 228;
          g = 224;
          b = 216; // mat
          if (fx >= 172 && fx < 340 && y >= 70 && y < 314) {
            if (white) {
              r = 236;
              g = 234;
              b = 228;
            } else if (flat) {
              r = 70;
              g = 90;
              b = 120;
            } else {
              final stripe = (fx ~/ 4).isEven;
              r = stripe ? 58 : 228;
              g = stripe ? 58 : 224;
              b = stripe ? 64 : 216;
              final cx = fx - 256, cy = y - 170;
              if (cx * cx / 1800 + cy * cy / 900 < 1) {
                r = 217;
                g = 154;
                b = 80;
              }
            }
          }
        }
      }
      im.setPixelRgb(x, y, n(r, 4), n(g, 4), n(b, 4));
    }
  }
  return im;
}

void save(String name, img.Image im) =>
    File('$dir/$name.jpg').writeAsBytesSync(img.encodeJpg(im, quality: 92));

void main() {
  Directory(dir).createSync(recursive: true);
  final good = scene();
  save('good', good);
  save('flat_painting', scene(flat: true));
  save('white_painting', scene(white: true));

  // Glare: a clipped, colourless reflection across the glass.
  final glare = scene();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final cx = (x - 230) / 70, cy = (y - 240) / 45;
      final d = cx * cx + cy * cy;
      if (d < 1) {
        glare.setPixelRgb(x, y, 255, 255, 255);
      } else if (d < 2.2) {
        final p = glare.getPixel(x, y);
        final a = (2.2 - d) / 1.2;
        glare.setPixelRgb(x, y, (p.r + (255 - p.r) * a).round(),
            (p.g + (255 - p.g) * a).round(), (p.b + (255 - p.b) * a).round());
      }
    }
  }
  save('glare', glare);

  save('blurry', img.gaussianBlur(scene(), radius: 6));
  save('dark', img.adjustColor(scene(), brightness: 0.16));
  // The frame runs off the left edge (the outer candidate touches it).
  save('corners_missing', scene(dx: -170));
}
