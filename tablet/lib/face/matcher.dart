import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Vektor wajah (embedding) dinormalkan panjang 1.
Float32List normalize(List<double> v) {
  var sum = 0.0;
  for (final x in v) {
    sum += x * x;
  }
  final n = math.sqrt(sum);
  final out = Float32List(v.length);
  for (var i = 0; i < v.length; i++) {
    out[i] = n == 0 ? 0 : v[i] / n;
  }
  return out;
}

double dot(Float32List a, Float32List b) {
  var s = 0.0;
  final n = math.min(a.length, b.length);
  for (var i = 0; i < n; i++) {
    s += a[i] * b[i];
  }
  return s;
}

/// Embedding ↔ base64 float32 little-endian (format yang disimpan server).
String encodeEmbedding(Float32List v) {
  final bytes = ByteData(v.length * 4);
  for (var i = 0; i < v.length; i++) {
    bytes.setFloat32(i * 4, v[i], Endian.little);
  }
  return base64Encode(bytes.buffer.asUint8List());
}

Float32List? decodeEmbedding(String b64) {
  try {
    final bytes = base64Decode(b64);
    if (bytes.length % 4 != 0 || bytes.isEmpty) return null;
    final data = ByteData.sublistView(bytes);
    final out = List<double>.generate(bytes.length ~/ 4, (i) => data.getFloat32(i * 4, Endian.little));
    return normalize(out);
  } catch (_) {
    return null;
  }
}

class GalleryEntry {
  const GalleryEntry(this.employeeId, this.faces);
  final int employeeId;
  final List<Float32List> faces;
}

class MatchResult {
  const MatchResult({required this.employeeId, required this.score, required this.second, required this.accepted});

  /// Kandidat terbaik (null bila galeri kosong).
  final int? employeeId;
  final double score;

  /// Skor kandidat terbaik dari karyawan LAIN.
  final double second;
  final bool accepted;

  double get margin => score - second;
}

/// Cocokkan satu wajah dengan semua karyawan (1:N). Diterima bila skor ≥ ambang
/// DAN unggul ≥ margin dari karyawan lain (supaya dua orang mirip tidak tertukar).
MatchResult matchFace(Float32List probe, List<GalleryEntry> gallery, {required double threshold, required double margin}) {
  int? bestId;
  var best = -1.0, second = -1.0;

  for (final entry in gallery) {
    var mine = -1.0;
    for (final face in entry.faces) {
      if (face.length != probe.length) continue;
      final s = dot(probe, face);
      if (s > mine) mine = s;
    }
    if (mine > best) {
      second = best;
      best = mine;
      bestId = entry.employeeId;
    } else if (mine > second) {
      second = mine;
    }
  }

  final ok = bestId != null && best >= threshold && (best - math.max(second, 0)) >= margin;
  return MatchResult(employeeId: bestId, score: best, second: math.max(second, 0), accepted: ok);
}

/// Absen hanya terjadi bila orang yang sama cocok di [required] bingkai berturut-turut.
class ConsecutiveTracker {
  ConsecutiveTracker(this.required);
  final int required;

  int? _id;
  int _count = 0;
  final List<double> _scores = [];
  final List<double> _margins = [];
  final List<double> _liveness = [];

  int get count => _count;
  int? get candidate => _id;

  /// Kembalikan true saat jumlah bingkai berturut-turut tercapai.
  bool add(int employeeId, {required double score, required double margin, double? liveness}) {
    if (_id != employeeId) {
      reset();
      _id = employeeId;
    }
    _count++;
    _scores.add(score);
    _margins.add(margin);
    if (liveness != null) _liveness.add(liveness);
    return _count >= required;
  }

  double get meanScore => _mean(_scores);
  double get meanMargin => _mean(_margins);
  double? get meanLiveness => _liveness.isEmpty ? null : _mean(_liveness);

  void reset() {
    _id = null;
    _count = 0;
    _scores.clear();
    _margins.clear();
    _liveness.clear();
  }

  static double _mean(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
}
