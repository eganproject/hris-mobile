import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'geometry.dart';

/// Satu bingkai kamera NV21 (Android) beserta rotasinya. Murni Dart supaya bisa
/// dikirim ke isolate untuk membuat foto bukti.
class FrameData {
  FrameData({required this.bytes, required this.width, required this.height, required this.stride, required this.rotation});

  final Uint8List bytes;
  final int width;
  final int height;

  /// Lebar baris dalam byte (bisa lebih besar dari [width]).
  final int stride;

  /// Derajat searah jarum jam agar gambar tegak (0/90/180/270).
  final int rotation;

  (int, int) get upright => uprightSize(width, height, rotation);

  /// Ambil warna RGB di koordinat buffer mentah (bilinear pada Y, terdekat pada UV).
  void sampleRaw(double rx, double ry, Uint8List out, int offset) {
    if (rx < 0) rx = 0;
    if (ry < 0) ry = 0;
    if (rx > width - 1) rx = width - 1.0;
    if (ry > height - 1) ry = height - 1.0;

    final x0 = rx.floor(), y0 = ry.floor();
    final x1 = x0 + 1 < width ? x0 + 1 : x0, y1 = y0 + 1 < height ? y0 + 1 : y0;
    final fx = rx - x0, fy = ry - y0;

    final yv = (bytes[y0 * stride + x0] * (1 - fx) + bytes[y0 * stride + x1] * fx) * (1 - fy) +
        (bytes[y1 * stride + x0] * (1 - fx) + bytes[y1 * stride + x1] * fx) * fy;

    final uvIndex = stride * height + (y0 >> 1) * stride + (x0 & ~1);
    final v = uvIndex < bytes.length ? bytes[uvIndex] - 128 : 0;
    final u = uvIndex + 1 < bytes.length ? bytes[uvIndex + 1] - 128 : 0;

    out[offset] = _clamp(yv + 1.402 * v);
    out[offset + 1] = _clamp(yv - 0.344136 * u - 0.714136 * v);
    out[offset + 2] = _clamp(yv + 1.772 * u);
  }

  void sampleUpright(double x, double y, Uint8List out, int offset) {
    final p = uprightToRaw(x, y, rotation, width, height);
    sampleRaw(p.x, p.y, out, offset);
  }

  /// Rata-rata kecerahan (0..255) di dalam kotak gambar tegak.
  double meanLuma(double left, double top, double w, double h) {
    var sum = 0.0;
    var n = 0;
    const steps = 12;
    for (var i = 0; i < steps; i++) {
      for (var j = 0; j < steps; j++) {
        final p = uprightToRaw(left + w * (i + 0.5) / steps, top + h * (j + 0.5) / steps, rotation, width, height);
        final x = p.x.round().clamp(0, width - 1), y = p.y.round().clamp(0, height - 1);
        sum += bytes[y * stride + x];
        n++;
      }
    }
    return n == 0 ? 0 : sum / n;
  }

  /// Wajah 112x112 RGB yang diluruskan ke template ArcFace, dinormalkan ke -1..1
  /// (masukan MobileFaceNet w600k_mbf, format NHWC).
  Float32List alignedFace(List<P> landmarks) {
    final t = Similarity.estimate(landmarks, arcFaceTemplate);
    final out = Float32List(112 * 112 * 3);
    final px = Uint8List(3);
    var k = 0;
    for (var y = 0; y < 112; y++) {
      for (var x = 0; x < 112; x++) {
        final src = t.invert(P(x.toDouble(), y.toDouble()));
        sampleUpright(src.x, src.y, px, 0);
        out[k++] = (px[0] - 127.5) / 127.5;
        out[k++] = (px[1] - 127.5) / 127.5;
        out[k++] = (px[2] - 127.5) / 127.5;
      }
    }
    return out;
  }

  /// Potongan 80x80 BGR 0..255 untuk MiniFASNet (cek wajah asli).
  Float32List antiSpoofPatch({required double x, required double y, required double w, required double h, required double scale}) {
    final (uw, uh) = upright;
    final box = antiSpoofBox(x: x, y: y, w: w, h: h, scale: scale, imageW: uw, imageH: uh);
    final out = Float32List(80 * 80 * 3);
    final px = Uint8List(3);
    final bw = box.right - box.left, bh = box.bottom - box.top;
    var k = 0;
    for (var j = 0; j < 80; j++) {
      for (var i = 0; i < 80; i++) {
        sampleUpright(box.left + bw * (i + 0.5) / 80, box.top + bh * (j + 0.5) / 80, px, 0);
        out[k++] = px[2].toDouble();
        out[k++] = px[1].toDouble();
        out[k++] = px[0].toDouble();
      }
    }
    return out;
  }

  static int _clamp(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());
}

/// Foto bukti JPEG (tegak, sisi terpanjang maks [maxSide]). Dijalankan di isolate.
Uint8List encodeFrameJpeg(FrameData frame, {int maxSide = 720, int quality = 75}) {
  final (uw, uh) = frame.upright;
  final scale = uw > uh ? (uw > maxSide ? maxSide / uw : 1.0) : (uh > maxSide ? maxSide / uh : 1.0);
  final ow = (uw * scale).round(), oh = (uh * scale).round();
  final image = img.Image(width: ow, height: oh);
  final px = Uint8List(3);
  for (var y = 0; y < oh; y++) {
    for (var x = 0; x < ow; x++) {
      frame.sampleUpright(x / scale, y / scale, px, 0);
      image.setPixelRgb(x, y, px[0], px[1], px[2]);
    }
  }
  return img.encodeJpg(image, quality: quality);
}
