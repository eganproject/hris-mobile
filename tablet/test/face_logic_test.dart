import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hris_tablet/core/models.dart';
import 'package:hris_tablet/core/pin.dart';
import 'package:hris_tablet/core/predict.dart';
import 'package:hris_tablet/face/frame.dart';
import 'package:hris_tablet/face/geometry.dart';
import 'package:hris_tablet/face/matcher.dart';

Float32List vec(List<double> v) => normalize(v);

Employee emp({DateTime? open, DateTime? todayIn, DateTime? todayOut, Schedule? schedule}) => Employee(
      id: 1,
      name: 'Rina Wulandari',
      nik: 'COK1126-KP0001',
      position: 'Staf Keuangan',
      initials: 'RW',
      faces: const [],
      pinHash: null,
      schedule: schedule,
      openClockIn: open,
      todayClockIn: todayIn,
      todayClockOut: todayOut,
    );

void main() {
  group('geometri', () {
    test('Similarity.estimate menemukan kembali transformasi yang diketahui', () {
      final angle = 0.3, scale = 1.7;
      final a = scale * math.cos(angle), b = scale * math.sin(angle);
      final truth = Similarity(a, b, 12, -5);
      final src = [const P(10, 20), const P(40, 22), const P(25, 35), const P(14, 50), const P(36, 52)];
      final dst = src.map(truth.apply).toList();
      final est = Similarity.estimate(src, dst);
      expect(est.a, closeTo(a, 1e-9));
      expect(est.b, closeTo(b, 1e-9));
      expect(est.tx, closeTo(12, 1e-9));
      final back = est.invert(dst[3]);
      expect(back.x, closeTo(14, 1e-9));
      expect(back.y, closeTo(50, 1e-9));
    });

    test('urutan titik wajah tidak tergantung cermin', () {
      final o = orderLandmarks(eyeA: const P(70, 50), eyeB: const P(40, 50), nose: const P(55, 70), mouthA: const P(68, 90), mouthB: const P(42, 90));
      expect(o[0].x, 40);
      expect(o[1].x, 70);
      expect(o[3].x, 42);
    });

    test('koordinat tegak ke buffer mentah untuk setiap rotasi', () {
      // Buffer 4x2 (W x H). Rotasi 90: gambar tegak 2x4.
      expect(uprightToRaw(1, 0, 90, 4, 2).x, 0); // pojok kanan atas tegak = pojok kiri atas mentah
      expect(uprightToRaw(1, 0, 90, 4, 2).y, 0);
      expect(uprightToRaw(0, 3, 270, 4, 2).x, 0);
      expect(uprightToRaw(0, 3, 270, 4, 2).y, 0);
      expect(uprightToRaw(3, 1, 180, 4, 2).x, 0);
      expect(uprightSize(640, 480, 270), (480, 640));
    });

    test('kotak cek wajah asli tetap di dalam gambar', () {
      final b = antiSpoofBox(x: 10, y: 10, w: 100, h: 120, scale: 2.7, imageW: 480, imageH: 640);
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(479));
      expect(b.right - b.left, closeTo(270, 1));
    });

    test('wajah diluruskan ke 112x112 dari bingkai NV21', () {
      const w = 64, h = 48;
      final bytes = Uint8List(w * h * 3 ~/ 2)..fillRange(0, w * h, 200)..fillRange(w * h, w * h * 3 ~/ 2, 128);
      final f = FrameData(bytes: bytes, width: w, height: h, stride: w, rotation: 270);
      final out = f.alignedFace([const P(15, 20), const P(30, 20), const P(22, 30), const P(16, 40), const P(29, 40)]);
      expect(out.length, 112 * 112 * 3);
      expect(out[0], closeTo((200 - 127.5) / 127.5, 0.01));
      expect(f.meanLuma(0, 0, 20, 20), closeTo(200, 0.5));
      expect(encodeFrameJpeg(f).length, greaterThan(100));
    });
  });

  group('pencocokan', () {
    final a = vec([1, 0, 0, 0]);
    final b = vec([0, 1, 0, 0]);
    final aLike = vec([0.9, 0.2, 0, 0]);
    final gallery = [GalleryEntry(1, [a]), GalleryEntry(2, [b])];

    test('cocok dengan orang yang benar', () {
      final m = matchFace(aLike, gallery, threshold: 0.4, margin: 0.06);
      expect(m.employeeId, 1);
      expect(m.accepted, isTrue);
    });

    test('ditolak bila di bawah ambang', () {
      final m = matchFace(vec([0, 0, 1, 0]), gallery, threshold: 0.4, margin: 0.06);
      expect(m.accepted, isFalse);
    });

    test('ditolak bila dua orang terlalu mirip skornya', () {
      final m = matchFace(vec([1, 1, 0, 0]), gallery, threshold: 0.4, margin: 0.06);
      expect(m.accepted, isFalse);
    });

    test('base64 embedding bolak-balik', () {
      final back = decodeEmbedding(encodeEmbedding(aLike))!;
      expect(dot(back, aLike), closeTo(1, 1e-6));
    });

    test('harus cocok 3 bingkai berturut-turut ke orang yang sama', () {
      final t = ConsecutiveTracker(3);
      expect(t.add(1, score: 0.7, margin: 0.3), isFalse);
      expect(t.add(2, score: 0.7, margin: 0.3), isFalse); // ganti orang = mulai ulang
      expect(t.add(2, score: 0.7, margin: 0.3), isFalse);
      expect(t.add(2, score: 0.6, margin: 0.3, liveness: 0.9), isTrue);
      expect(t.meanScore, closeTo(0.6667, 0.001));
    });
  });

  test('PIN dicek dengan hash dari HRIS (PBKDF2)', () {
    const hash = r'pbkdf2_sha256$20000$idpJY0Wt+ah1v40Qn1vpJw==$VmVtKsmlMt2OawPpBooaVbJH4ox9TJQ/Ezymk5PfWHU=';
    expect(verifyPin('123456', hash), isTrue);
    expect(verifyPin('123457', hash), isFalse);
    expect(verifyPin('123456', null), isFalse);
  });

  group('tebakan masuk/pulang', () {
    const s = TabletSettings();
    final now = DateTime(2026, 11, 26, 17, 5);

    test('belum absen = masuk', () {
      expect(predictAction(emp(), const [], now, s).type, 'in');
    });

    test('sesi terbuka = pulang', () {
      final p = predictAction(emp(open: DateTime(2026, 11, 26, 7, 50), todayIn: DateTime(2026, 11, 26, 7, 50)), const [], now, s);
      expect(p.type, 'out');
      expect(durationLabel(now.difference(p.since!)), 'Kerja 9 j 15 m');
    });

    test('pindai ulang < 1 menit diabaikan', () {
      final p = predictAction(emp(), [LocalEvent('in', now.subtract(const Duration(seconds: 20)))], now, s);
      expect(p.ignored, isTrue);
    });

    test('pindai lagi setelah pulang = pulang diperbarui', () {
      final p = predictAction(emp(todayIn: DateTime(2026, 11, 26, 7, 50), todayOut: DateTime(2026, 11, 26, 16, 0)), const [], now, s);
      expect(p.type, 'out');
      expect(p.ignored, isFalse);
    });

    test('masuk lewat tablet lalu pulang (offline, tanpa sinkron)', () {
      final p = predictAction(emp(), [LocalEvent('in', DateTime(2026, 11, 26, 7, 50))], now, s);
      expect(p.type, 'out');
    });

    test('shift malam: sesi kemarin masih terbuka = pulang', () {
      final p = predictAction(emp(open: DateTime(2026, 11, 25, 22, 0)), const [], DateTime(2026, 11, 26, 6, 0), s);
      expect(p.type, 'out');
    });

    test('label tepat waktu / terlambat', () {
      final e = emp(schedule: const Schedule('08:00', '17:00', 10));
      expect(punctualityLabel(e, DateTime(2026, 11, 26, 7, 52)), 'Tepat waktu');
      expect(punctualityLabel(e, DateTime(2026, 11, 26, 8, 25)), 'Terlambat 25 menit');
    });
  });

  group('tombol Absen Masuk / Absen Pulang', () {
    const s = TabletSettings();
    final pagi = DateTime(2026, 11, 26, 7, 50);
    final sore = DateTime(2026, 11, 26, 17, 5);

    test('pilih masuk saat belum absen = dicatat masuk', () {
      final c = checkChosen(emp(), const [], pagi, s, 'in');
      expect(c.outcome, ChoiceOutcome.record);
      expect(c.type, 'in');
    });

    test('pilih masuk padahal sudah masuk = ditanya, usul pulang', () {
      final c = checkChosen(emp(open: pagi, todayIn: pagi), const [], sore, s, 'in');
      expect(c.outcome, ChoiceOutcome.alreadyIn);
      expect(c.type, 'out');
      expect(c.since, pagi);
    });

    test('pilih pulang padahal belum masuk = ditanya', () {
      expect(checkChosen(emp(), const [], sore, s, 'out').outcome, ChoiceOutcome.notIn);
    });

    test('pilih pulang setelah masuk = dicatat pulang', () {
      final c = checkChosen(emp(), [LocalEvent('in', pagi)], sore, s, 'out');
      expect(c.outcome, ChoiceOutcome.record);
      expect(c.since, pagi);
    });

    test('lupa pulang kemarin, pilih masuk pagi ini = dicatat masuk tanpa ditanya', () {
      final c = checkChosen(emp(open: DateTime(2026, 11, 25, 20, 0)), const [], pagi, s, 'in');
      expect(c.outcome, ChoiceOutcome.record);
      expect(c.type, 'in');
    });

    test('pindai ganda dalam 1 menit diabaikan', () {
      final c = checkChosen(emp(), [LocalEvent('in', pagi)], pagi.add(const Duration(seconds: 20)), s, 'out');
      expect(c.outcome, ChoiceOutcome.ignored);
    });

    test('pilihan bawaan mengikuti titik tengah jadwal', () {
      final list = [emp(schedule: const Schedule('08:00', '17:00', 10))];
      expect(defaultChoice(list, DateTime(2026, 11, 26, 12, 29)), 'in');
      expect(defaultChoice(list, DateTime(2026, 11, 26, 12, 30)), 'out');
      expect(defaultChoice(const [], DateTime(2026, 11, 26, 11, 0)), 'in');
      expect(defaultChoice(const [], DateTime(2026, 11, 26, 13, 0)), 'out');
    });
  });
}
