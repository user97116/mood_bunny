/// Renders candidate front/back blobs for visual identification.
/// Run: `dart run tool/blob_strip.dart`, then open tool/strip_blobs.png
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final src =
      img.decodePng(File('assets/sprites/bunny.png').readAsBytesSync())!;
  // r1 row (y~47) + top row + r3 row candidates
  final boxes = [
    [62, 15, 19, 28],
    [138, 19, 21, 23],
    [29, 52, 19, 26],
    [62, 51, 19, 27],
    [103, 47, 19, 31],
    [63, 95, 21, 30],
    [142, 96, 19, 28],
  ];
  const scale = 8;
  const cw = 40, ch = 40;
  final out = img.Image(width: cw * scale * boxes.length, height: ch * scale);
  final red = img.ColorRgb8(255, 0, 0);
  for (var i = 0; i < boxes.length; i++) {
    final b = boxes[i];
    final cellImg =
        img.copyCrop(src, x: b[0], y: b[1], width: b[2], height: b[3]);
    final big = img.copyResize(cellImg,
        width: b[2] * scale,
        height: b[3] * scale,
        interpolation: img.Interpolation.nearest);
    img.compositeImage(out, big,
        dstX: i * cw * scale + (cw * scale - b[2] * scale) ~/ 2,
        dstY: ch * scale - b[3] * scale);
    final sx = (i + 1) * cw * scale - 1;
    for (var y = 0; y < out.height; y++) {
      out.setPixel(sx, y, red);
    }
  }
  File('tool/strip_blobs.png').writeAsBytesSync(img.encodePng(out));
  print('wrote tool/strip_blobs.png');
}
