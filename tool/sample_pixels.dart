/// Samples pixel values to check if the bunny "blue" is opaque or not.
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final src =
      img.decodePng(File('assets/sprites/bunny.png').readAsBytesSync())!;
  for (final xy in [
    [0, 0],
    [100, 100],
    [26, 288],
    [30, 295],
    [70, 40],
    [200, 200],
    [320, 326],
  ]) {
    final p = src.getPixel(xy[0], xy[1]);
    print('(${xy[0]},${xy[1]}) rgb(${p.r.toInt()},${p.g.toInt()},'
        '${p.b.toInt()}) a=${p.a.toInt()}');
  }
  // most common opaque color
  final counts = <String, int>{};
  for (var y = 0; y < src.height; y += 2) {
    for (var x = 0; x < src.width; x += 2) {
      final p = src.getPixel(x, y);
      if (p.a > 128) {
        final k = '${p.r.toInt()},${p.g.toInt()},${p.b.toInt()}';
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
  }
  final top = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  print('top opaque colors: ${top.take(8).map((e) => '${e.key}:${e.value}')}');
}
