/// Builds a normalized bunny hop strip: uniform cells, feet planted,
/// body mass centered — kills the per-frame sway of raw crops.
/// Run: `dart run tool/normalize_sprites.dart`
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final src =
      img.decodePng(File('assets/sprites/bunny.png').readAsBytesSync())!;
  // auto-detected hop boxes (x, w), band y=288 h=32
  final boxes = [
    [26, 27],
    [60, 28],
    [95, 35],
    [137, 31],
    [177, 28],
    [207, 29],
    [239, 30],
    [274, 30],
  ];
  const cellW = 40, cellH = 36;
  final strip = img.Image(
      width: cellW * boxes.length, height: cellH, numChannels: 4);
  for (var i = 0; i < boxes.length; i++) {
    final bx = boxes[i][0], bw = boxes[i][1];
    // opaque bbox inside the raw box
    var x0 = bx + bw, x1 = bx, y0 = 288 + 32, y1 = 288;
    for (var y = 288; y < 288 + 32; y++) {
      for (var x = bx; x < bx + bw; x++) {
        if (src.getPixel(x, y).a > 128) {
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
      }
    }
    final content =
        img.copyCrop(src, x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1);
    // feet planted 2px above cell bottom, mass centered horizontally
    final dx = i * cellW + ((cellW - content.width) ~/ 2);
    final dy = cellH - 2 - content.height;
    img.compositeImage(strip, content, dstX: dx, dstY: dy);
    print('frame $i bbox=($x0,$y0,${x1 - x0 + 1},${y1 - y0 + 1})');
  }
  File('assets/sprites/bunny_walk.png')
      .writeAsBytesSync(img.encodePng(strip));
  print('wrote assets/sprites/bunny_walk.png '
      '(${strip.width}x${strip.height})');
}
