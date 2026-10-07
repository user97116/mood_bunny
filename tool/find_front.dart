/// Ranks upright bunny blobs by pink (inner-ear/face) pixels to find
/// the true front-facing idle frame.
/// Run: `dart run tool/find_front.dart`
import 'dart:io';

import 'package:image/image.dart' as img;

bool pink(img.Pixel p) {
  final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
  return p.a > 128 && r > 190 && g > 130 && g < 210 && b > 130 && b < 210 && r > b + 15;
}

void main() {
  final src =
      img.decodePng(File('assets/sprites/bunny.png').readAsBytesSync())!;
  final scored = <String, int>{};
  void scan(String label, int x, int y, int w, int h) {
    var n = 0;
    for (var yy = y; yy < y + h; yy++) {
      for (var xx = x; xx < x + w; xx++) {
        if (pink(src.getPixel(xx, yy))) n++;
      }
    }
    scored['$label [$x,$y,${w}x$h]'] = n;
  }

  // upright candidates: top row, r1 row, r3 row
  scan('top0', 62, 15, 19, 28);
  scan('top1', 138, 19, 21, 23);
  for (final b in [
    [29, 52, 19, 26],
    [62, 51, 19, 27],
    [103, 47, 19, 31],
    [139, 50, 19, 25],
    [179, 52, 19, 26],
    [211, 53, 19, 23],
    [245, 52, 19, 23],
    [278, 52, 19, 23],
  ]) {
    scan('r1', b[0], b[1], b[2], b[3]);
  }
  scan('r3a', 63, 95, 21, 30);
  scan('r3b', 142, 96, 19, 28);
  final ranked = scored.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in ranked) {
    print('${e.value} ${e.key}');
  }
}
