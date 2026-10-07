/// Renders every frame of the reference walk gif as a strip.
/// Run: `dart run tool/gif_frames.dart`, then open tool/strip_walkref.png
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final gif = img.decodeGif(
      File('tool/walkref.gif').readAsBytesSync())!;
  print('gif frames: ${gif.numFrames} '
      '${gif.width}x${gif.height}');
  const scale = 6;
  final out = img.Image(
      width: (gif.width + 4) * gif.numFrames * scale,
      height: (gif.height + 4) * scale);
  final red = img.ColorRgb8(255, 0, 0);
  for (var i = 0; i < gif.numFrames; i++) {
    final f = gif.frames[i];
    final big = img.copyResize(f,
        width: f.width * scale,
        height: f.height * scale,
        interpolation: img.Interpolation.nearest);
    img.compositeImage(out, big,
        dstX: i * (gif.width + 4) * scale, dstY: 2 * scale);
    final sx = (i * (gif.width + 4) + gif.width + 2) * scale;
    for (var y = 0; y < out.height; y++) {
      out.setPixel(sx, y, red);
    }
  }
  File('tool/strip_walkref.png').writeAsBytesSync(img.encodePng(out));
  print('wrote tool/strip_walkref.png');
}
