import 'dart:math' as math;

/// Titik 2D sederhana (tanpa dependensi UI supaya bisa dipakai di isolate & tes).
class P {
  const P(this.x, this.y);
  final double x;
  final double y;

  @override
  String toString() => 'P(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Posisi 5 titik wajah standar ArcFace/InsightFace untuk gambar 112x112:
/// mata kiri-gambar, mata kanan-gambar, hidung, sudut mulut kiri, kanan.
const arcFaceTemplate = <P>[
  P(38.2946, 51.6963),
  P(73.5318, 51.5014),
  P(56.0252, 71.7366),
  P(41.5493, 92.3655),
  P(70.7299, 92.2041),
];

/// Transformasi kemiripan (skala + putar + geser): dst = [[a,-b],[b,a]]·src + t.
class Similarity {
  const Similarity(this.a, this.b, this.tx, this.ty);
  final double a;
  final double b;
  final double tx;
  final double ty;

  /// Kuadrat terkecil (Umeyama 2D) dari pasangan titik src → dst.
  factory Similarity.estimate(List<P> src, List<P> dst) {
    assert(src.length == dst.length && src.isNotEmpty);
    final n = src.length;
    var msx = 0.0, msy = 0.0, mdx = 0.0, mdy = 0.0;
    for (var i = 0; i < n; i++) {
      msx += src[i].x;
      msy += src[i].y;
      mdx += dst[i].x;
      mdy += dst[i].y;
    }
    msx /= n;
    msy /= n;
    mdx /= n;
    mdy /= n;

    var num1 = 0.0, num2 = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      final sx = src[i].x - msx, sy = src[i].y - msy;
      final dx = dst[i].x - mdx, dy = dst[i].y - mdy;
      num1 += sx * dx + sy * dy;
      num2 += sx * dy - sy * dx;
      den += sx * sx + sy * sy;
    }
    if (den == 0) return const Similarity(1, 0, 0, 0);

    final a = num1 / den, b = num2 / den;
    return Similarity(a, b, mdx - (a * msx - b * msy), mdy - (b * msx + a * msy));
  }

  P apply(P p) => P(a * p.x - b * p.y + tx, b * p.x + a * p.y + ty);

  /// Kebalikan: dari titik tujuan (mis. piksel 112x112) ke titik asal.
  P invert(P p) {
    final d = a * a + b * b;
    final x = p.x - tx, y = p.y - ty;
    return P((a * x + b * y) / d, (-b * x + a * y) / d);
  }

  double get scale => math.sqrt(a * a + b * b);
}

/// Urutkan 5 titik ML Kit ke urutan template: dua mata dan dua sudut mulut
/// diurutkan menurut x di gambar tegak, jadi tidak tergantung cermin kamera.
List<P> orderLandmarks({required P eyeA, required P eyeB, required P nose, required P mouthA, required P mouthB}) {
  final eyes = eyeA.x <= eyeB.x ? [eyeA, eyeB] : [eyeB, eyeA];
  final mouth = mouthA.x <= mouthB.x ? [mouthA, mouthB] : [mouthB, mouthA];
  return [eyes[0], eyes[1], nose, mouth[0], mouth[1]];
}

/// Peta koordinat gambar tegak (yang dipakai ML Kit) ke koordinat buffer kamera
/// mentah berukuran [rawW] x [rawH] dengan rotasi [rotation] derajat searah jarum jam.
P uprightToRaw(double x, double y, int rotation, int rawW, int rawH) {
  switch (rotation) {
    case 90:
      return P(y, rawH - 1 - x);
    case 180:
      return P(rawW - 1 - x, rawH - 1 - y);
    case 270:
      return P(rawW - 1 - y, x);
    default:
      return P(x, y);
  }
}

/// Ukuran gambar tegak dari ukuran buffer mentah.
(int, int) uprightSize(int rawW, int rawH, int rotation) =>
    (rotation == 90 || rotation == 270) ? (rawH, rawW) : (rawW, rawH);

/// Kotak potong untuk cek wajah asli (cara MiniFASNet/Minivision): kotak wajah
/// diperbesar [scale] kali di sekitar titik tengahnya, digeser agar tetap di dalam gambar.
({double left, double top, double right, double bottom}) antiSpoofBox({
  required double x,
  required double y,
  required double w,
  required double h,
  required double scale,
  required int imageW,
  required int imageH,
}) {
  final s = math.min((imageH - 1) / h, math.min((imageW - 1) / w, scale));
  final nw = w * s, nh = h * s;
  final cx = w / 2 + x, cy = h / 2 + y;
  var l = cx - nw / 2, t = cy - nh / 2, r = cx + nw / 2, b = cy + nh / 2;
  if (l < 0) {
    r -= l;
    l = 0;
  }
  if (t < 0) {
    b -= t;
    t = 0;
  }
  if (r > imageW - 1) {
    l -= r - imageW + 1;
    r = imageW - 1.0;
  }
  if (b > imageH - 1) {
    t -= b - imageH + 1;
    b = imageH - 1.0;
  }
  return (left: l, top: t, right: r, bottom: b);
}
