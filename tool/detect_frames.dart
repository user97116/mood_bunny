/// Auto-detects animation frame boxes in a row band by scanning for
/// non-transparent column runs. Run: `dart run tool/detect_frames.dart`
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(
      File('assets/sprites/bunny.png').readAsBytesSync())!;
  const y0 = 288, y1 = 320;
  final runs = <List<int>>[];
  var start = -1;
  for (var x = 0; x < src.width; x++) {
    var hit = false;
    for (var y = y0; y < y1 && !hit; y++) {
      if (src.getPixel(x, y).a > 128) hit = true;
    }
    if (hit && start < 0) {
      start = x;
    } else if (!hit && start >= 0) {
      runs.add([start, x - 1]);
      start = -1;
    }
  }
  if (start >= 0) runs.add([start, src.width - 1]);
  // merge runs separated by tiny gaps (<3px)
  final merged = <List<int>>[];
  for (final r in runs) {
    if (merged.isNotEmpty && r[0] - merged.last[1] < 3) {
      merged.last[1] = r[1];
    } else {
      merged.add([r[0], r[1]]);
    }
  }
  print('frames: ${merged.length}');
  for (final r in merged) {
    print('  x=${r[0]}..${r[1]} w=${r[1] - r[0] + 1}');
  }
  // verification strip with exact boxes (+1px pad), 4x
  const scale = 4, pad = 1;
  final boxes =
      merged.map((r) => [r[0] - pad, y0, r[1] - r[0] + 1 + pad * 2, y1 - y0]).toList();
  final cw = boxes.map((b) => b[2] as int).reduce((a, b) => a > b ? a : b);
  final out = img.Image(
      width: (cw + 4) * boxes.length * scale, height: (32 + 8) * scale);
  final red = img.ColorRgb8(255, 0, 0);
  for (var i = 0; i < boxes.length; i++) {
    final b = boxes[i];
    final cell = img.copyCrop(src,
        x: b[0] as int, y: b[1] as int, width: b[2] as int, height: b[3] as int);
    final big = img.copyResize(cell,
        width: (b[2] as int) * scale,
        height: (b[3] as int) * scale,
        interpolation: img.Interpolation.nearest);
    img.compositeImage(out, big, dstX: i * (cw + 4) * scale, dstY: 4 * scale);
    final sx = (i * (cw + 4) + cw + 2) * scale;
    for (var y = 0; y < out.height; y++) {
      out.setPixel(sx, y, red);
    }
  }
  File('tool/strip_bunny_run_auto.png')
      .writeAsBytesSync(img.encodePng(out));
  print('wrote tool/strip_bunny_run_auto.png');
}
