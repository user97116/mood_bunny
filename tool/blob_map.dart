/// Connected-component labeling of the bunny sheet: lists every blob
/// with its bounding box so frames can be picked objectively.
/// Run: `dart run tool/blob_map.dart`
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final src =
      img.decodePng(File('assets/sprites/bunny.png').readAsBytesSync())!;
  final w = src.width, h = src.height;
  final seen = List.filled(w * h, false);
  final blobs = <List<int>>[];
  bool solid(int x, int y) => src.getPixel(x, y).a > 128;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!solid(x, y) || seen[y * w + x]) continue;
      // flood fill
      var x0 = x, x1 = x, y0 = y, y1 = y, n = 0;
      final stack = <int>[y * w + x];
      seen[y * w + x] = true;
      while (stack.isNotEmpty) {
        final i = stack.removeLast();
        final px = i % w, py = i ~/ w;
        n++;
        if (px < x0) x0 = px;
        if (px > x1) x1 = px;
        if (py < y0) y0 = py;
        if (py > y1) y1 = py;
        for (final d in [-1, 1, -w, w]) {
          final j = i + d;
          final qx = j % w, qy = j ~/ w;
          if (qx < 0 || qx >= w || qy < 0 || qy >= h) continue;
          if ((qx - px).abs() + (qy - py).abs() != 1) continue;
          if (!seen[j] && solid(qx, qy)) {
            seen[j] = true;
            stack.add(j);
          }
        }
      }
      if (n > 40) blobs.add([x0, y0, x1 - x0 + 1, y1 - y0 + 1, n]);
    }
  }
  blobs.sort((a, b) =>
      a[1] != b[1] ? a[1].compareTo(b[1]) : a[0].compareTo(b[0]));
  print('${blobs.length} blobs (x,y,w,h,px):');
  for (final b in blobs) {
    print('  $b');
  }
}
