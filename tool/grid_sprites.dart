/// Draws a 32px grid + labels over sprite sheets for layout mapping.
/// Run: `dart run tool/grid_sprites.dart` then open tool/preview_*.png
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  for (final name in ['cat', 'dog', 'bunny']) {
    final file = File('assets/sprites/$name.png');
    final src = img.decodePng(file.readAsBytesSync())!;
    const cell = 32;
    final scale = src.width > 400 ? 2 : 3;
    final out = img.copyResize(src,
        width: src.width * scale,
        height: src.height * scale,
        interpolation: img.Interpolation.nearest);
    final red = img.ColorRgb8(255, 0, 0);
    // vertical lines every cell
    for (var cx = 0; cx <= src.width; cx += cell) {
      img.drawLine(out,
          x1: cx * scale,
          y1: 0,
          x2: cx * scale,
          y2: out.height - 1,
          color: red);
    }
    // horizontal lines + row index label
    var row = 0;
    for (var cy = 0; cy <= src.height; cy += cell) {
      img.drawLine(out,
          x1: 0,
          y1: cy * scale,
          x2: out.width - 1,
          y2: cy * scale,
          color: red);
      img.drawString(out, 'r$row', font: img.arial14,
          x: 2, y: cy * scale + 2, color: red);
      row++;
    }
    File('tool/preview_${name}_grid.png').writeAsBytesSync(
        img.encodePng(out));
    print('wrote tool/preview_${name}_grid.png (${out.width}x${out.height})');
  }
}
