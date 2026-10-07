import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  for (final name in ['bunny_walk.png', 'bunny.png', 'cat.png']) {
    final src = img.decodePng(
        File('assets/sprites/$name').readAsBytesSync())!;
    print('$name numChannels=${src.numChannels} format=${src.format}');
    var t = 0, o = 0;
    for (var y = 0; y < src.height; y += 3) {
      for (var x = 0; x < src.width; x += 3) {
        if (src.getPixel(x, y).a < 128) {
          t++;
        } else {
          o++;
        }
      }
    }
    print('  sampled transparent=$t opaque=$o');
  }
}
