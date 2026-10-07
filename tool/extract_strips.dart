/// Extracts candidate animation strips into enlarged previews.
/// Run: `dart run tool/extract_strips.dart`, then open tool/strip_*.png
import 'dart:io';

import 'package:image/image.dart' as img;

void strip(String name, String srcPath, List<List<int>> cells) {
  final src = img.decodePng(File(srcPath).readAsBytesSync())!;
  const pad = 2;
  const scale = 4;
  final cw = cells.map((c) => c[2]).reduce((a, b) => a > b ? a : b);
  final ch = cells.map((c) => c[3]).reduce((a, b) => a > b ? a : b);
  final out = img.Image(
      width: (cw + pad) * cells.length * scale, height: (ch + pad * 2) * scale);
  final red = img.ColorRgb8(255, 0, 0);
  for (var i = 0; i < cells.length; i++) {
    final c = cells[i];
    final cell =
        img.copyCrop(src, x: c[0], y: c[1], width: c[2], height: c[3]);
    final big = img.copyResize(cell,
        width: c[2] * scale,
        height: c[3] * scale,
        interpolation: img.Interpolation.nearest);
    img.compositeImage(out, big,
        dstX: i * (cw + pad) * scale, dstY: pad * scale);
    // separator
    final sx = (i * (cw + pad) + cw + pad ~/ 2) * scale;
    for (var y = 0; y < out.height; y++) {
      out.setPixel(sx, y, red);
    }
  }
  File('tool/strip_$name.png').writeAsBytesSync(img.encodePng(out));
  print('wrote tool/strip_$name.png');
}

List<List<int>> row(int y, int x0, int n, {int w = 32, int h = 32}) =>
    List.generate(n, (i) => [x0 + i * w, y, w, h]);

void main() {
  strip('cat_walk', 'assets/sprites/cat.png', row(96, 0, 4));
  strip('cat_sit', 'assets/sprites/cat.png', [
    [96, 0, 32, 32]
  ]);
  strip('cat_sleep', 'assets/sprites/cat.png', row(128, 0, 4));
  strip('cat_front', 'assets/sprites/cat.png', [
    [32, 32, 32, 32]
  ]);
  strip('dog_walk', 'assets/sprites/dog.png', row(96, 0, 4));
  strip('dog_sit', 'assets/sprites/dog.png', [
    [96, 0, 32, 32]
  ]);
  strip('dog_sleep', 'assets/sprites/dog.png', row(128, 0, 4));
  strip('bunny_run7', 'assets/sprites/bunny.png', row(224, 0, 8));
  strip('bunny_run9', 'assets/sprites/bunny.png', row(288, 0, 8));
  strip('bunny_front', 'assets/sprites/bunny.png', [
    [64, 0, 32, 32],
    [32, 32, 32, 32],
    [64, 32, 32, 32],
  ]);
}
