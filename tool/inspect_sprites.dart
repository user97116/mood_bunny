/// One-off sprite sheet inspector. Run: `dart run tool/inspect_sprites.dart`
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  for (final name in ['cat', 'dog', 'bunny']) {
    final file = File('assets/sprites/$name.png');
    final data = img.decodePng(file.readAsBytesSync())!;
    var transparent = 0;
    var total = data.width * data.height;
    final corners = <String>[];
    for (final p in [
      data.getPixel(0, 0),
      data.getPixel(data.width - 1, 0),
      data.getPixel(0, data.height - 1),
      data.getPixel(data.width - 1, data.height - 1),
    ]) {
      corners.add(
          'rgb(${p.r.toInt()},${p.g.toInt()},${p.b.toInt()}) a=${p.a.toInt()}');
    }
    for (var y = 0; y < data.height; y++) {
      for (var x = 0; x < data.width; x++) {
        if (data.getPixel(x, y).a < 128) transparent++;
      }
    }
    print('$name: ${data.width}x${data.height} '
        'transparent=${(transparent / total * 100).toStringAsFixed(1)}%');
    print('  corners: $corners');
  }
}
