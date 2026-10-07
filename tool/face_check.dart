/// Enlarged single-frame viewer to check facing direction.
/// Run: `dart run tool/face_check.dart`, then open tool/face_*.png
import 'dart:io';

import 'package:image/image.dart' as img;

void one(String name, String srcPath, List<int> r) {
  final src = img.decodePng(File(srcPath).readAsBytesSync())!;
  final cell =
      img.copyCrop(src, x: r[0], y: r[1], width: r[2], height: r[3]);
  final big = img.copyResize(cell,
      width: r[2] * 8,
      height: r[3] * 8,
      interpolation: img.Interpolation.nearest);
  File('tool/face_$name.png').writeAsBytesSync(img.encodePng(big));
  print('wrote tool/face_$name.png');
}

void main() {
  one('bunny_idle', 'assets/sprites/bunny.png', [64, 32, 32, 32]);
}
