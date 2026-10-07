/// Renders each walk frame exactly as _SpritePainter draws it
/// (140x128 box, 3.5x, bottom-center anchored) to expose jitter.
/// Run: `dart run tool/sprite_layout.dart`, open tool/layout_*.png
import 'dart:io';

import 'package:image/image.dart' as img;

void layout(String name, String asset, List<List<num>> frames) {
  final src = img.decodePng(File(asset).readAsBytesSync())!;
  const scale = 3.5, boxW = 140.0, boxH = 128.0;
  const n = 8;
  final cols = frames.length > 4 ? 4 : frames.length;
  final rows = (frames.length / cols).ceil();
  final out = img.Image(
      width: (boxW * scale + 8).toInt() * cols,
      height: (boxH * scale + 8).toInt() * rows);
  img.fill(out, color: img.ColorRgb8(20, 20, 30));
  final cross = img.ColorRgb8(255, 0, 0);
  for (var i = 0; i < frames.length; i++) {
    final f = frames[i];
    final cell = img.copyCrop(src,
        x: f[0].toInt(), y: f[1].toInt(), width: f[2].toInt(), height: f[3].toInt());
    final dw = (f[2] * scale).toInt(), dh = (f[3] * scale).toInt();
    final big = img.copyResize(cell,
        width: dw, height: dh, interpolation: img.Interpolation.nearest);
    final ox = (i % cols) * (boxW * scale + 8).toInt();
    final oy = (i ~/ cols) * (boxH * scale + 8).toInt();
    // app math: dst centered in 140x128 box, bottom anchored
    final dx = ox + ((boxW - f[2] * scale) / 2 * scale).toInt();
    final dy = oy + ((boxH - f[3] * scale) * scale).toInt();
    img.compositeImage(out, big, dstX: dx, dstY: dy);
    // box center crosshair
    final cx = ox + (boxW * scale / 2).toInt();
    final cy = oy + (boxH * scale / 2).toInt();
    for (var x = ox; x < ox + boxW * scale; x++) {
      out.setPixel(x.toInt(), cy, cross);
    }
    for (var y = oy; y < oy + boxH * scale; y++) {
      out.setPixel(cx, y.toInt(), cross);
    }
  }
  File('tool/layout_$name.png').writeAsBytesSync(img.encodePng(out));
  print('wrote tool/layout_$name.png');
}

void main() {
  layout('bunny', 'assets/sprites/bunny.png', [
    [26, 288, 27, 32],
    [60, 288, 28, 32],
    [95, 288, 35, 32],
    [137, 288, 31, 32],
    [177, 288, 28, 32],
    [207, 288, 29, 32],
    [239, 288, 30, 32],
    [274, 288, 30, 32],
  ]);
  layout('cat', 'assets/sprites/cat.png', [
    [0, 96, 32, 32],
    [32, 96, 32, 32],
    [64, 96, 32, 32],
    [0, 0, 32, 32],
  ]);
}
