/// Verifies every frame rect in PetCharacter maps actually contains pixels.
/// Run: `dart run tool/verify_frames.dart`
import 'dart:io';

import 'package:image/image.dart' as img;

void check(String asset, String label, List<int> r) {
  final src =
      img.decodePng(File('assets/sprites/$asset').readAsBytesSync())!;
  var hit = 0;
  for (var y = r[1]; y < r[1] + r[3]; y++) {
    for (var x = r[0]; x < r[0] + r[2]; x++) {
      if (src.getPixel(x, y).a > 128) hit++;
    }
  }
  print('$asset $label rect(${r[0]},${r[1]},${r[2]},${r[3]}) pixels=$hit '
      '${hit > 20 ? "OK" : "EMPTY!"}');
}

void main() {
  final walkBoth = [
    [0, 96, 32, 32],
    [32, 96, 32, 32],
    [64, 96, 32, 32],
    [0, 0, 32, 32],
    [32, 0, 32, 32],
    [64, 0, 32, 32],
  ];
  for (var i = 0; i < walkBoth.length; i++) {
    check('cat.png', 'walk$i', walkBoth[i]);
    check('dog.png', 'walk$i', walkBoth[i]);
  }
  check('cat.png', 'front', [32, 32, 32, 32]);
  check('dog.png', 'front', [32, 32, 32, 32]);
  check('cat.png', 'tiredL', [96, 96, 32, 32]);
  check('dog.png', 'tiredL', [96, 96, 32, 32]);
  check('cat.png', 'tiredR', [96, 0, 32, 32]);
  check('dog.png', 'tiredR', [96, 0, 32, 32]);
  final walkBunny = List.generate(8, (i) => [i * 40, 0, 40, 36]);
  for (var i = 0; i < walkBunny.length; i++) {
    check('bunny_walk.png', 'walk$i', walkBunny[i]);
  }
  check('bunny.png', 'idle', [62, 51, 19, 27]);
}
