import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'frame.dart';
import 'geometry.dart';
import 'matcher.dart';

/// Nama model yang dikirim ke server bersama data wajah.
const faceModelName = 'w600k_mbf';

/// Alasan wajah belum bisa dipakai (ditampilkan sebagai petunjuk di layar).
enum FaceIssue { none, noFace, tooFar, tooClose, notFrontal, tooDark, tooBright, partial }

String faceIssueText(FaceIssue issue) => switch (issue) {
      FaceIssue.none => 'Wajah terlihat jelas',
      FaceIssue.noFace => 'Hadapkan wajah ke kamera',
      FaceIssue.tooFar => 'Mendekat sedikit',
      FaceIssue.tooClose => 'Mundur sedikit, kepala dan bahu harus terlihat',
      FaceIssue.notFrontal => 'Hadapkan wajah lurus ke kamera',
      FaceIssue.tooDark => 'Wajah terlalu gelap',
      FaceIssue.tooBright => 'Hindari cahaya terang dari belakang',
      FaceIssue.partial => 'Posisikan wajah di tengah layar',
    };

class FaceObservation {
  FaceObservation({
    required this.frame,
    required this.issue,
    this.box,
    this.yaw = 0,
    this.embedding,
    this.liveness,
  });

  final FrameData frame;
  final FaceIssue issue;

  /// Kotak wajah di gambar tegak.
  final Rect? box;

  /// Sudut toleh kiri/kanan (derajat, dari ML Kit).
  final double yaw;
  final Float32List? embedding;

  /// Skor wajah asli 0..1, null bila tidak dicek.
  final double? liveness;

  bool get usable => issue == FaceIssue.none && embedding != null;
}

/// Deteksi (Google ML Kit), pengenalan (MobileFaceNet TFLite), dan cek wajah asli
/// (MiniFASNet TFLite). Semuanya di dalam tablet, tanpa internet.
class FaceEngine {
  FaceEngine._(this._detector, this._recognizer, this._spoofV2, this._spoofV1);

  final FaceDetector _detector;
  final IsolateInterpreter _recognizer;
  final IsolateInterpreter _spoofV2;
  final IsolateInterpreter _spoofV1;

  /// Rentang lebar wajah terhadap lebar gambar (aturan "jarak normal": kepala +
  /// bahu terlihat sehingga tepi kertas/HP yang disodorkan ikut terlihat).
  static const minFaceRatio = 0.14;
  static const maxFaceRatio = 0.48;

  static Future<FaceEngine> load() async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: false,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.1,
      ),
    );
    Future<IsolateInterpreter> open(String asset) async {
      final options = InterpreterOptions()..threads = 2;
      final interpreter = await Interpreter.fromAsset(asset, options: options);
      return IsolateInterpreter.create(address: interpreter.address);
    }

    return FaceEngine._(
      detector,
      await open('assets/models/face_recognition_w600k_mbf.tflite'),
      await open('assets/models/antispoof_minifasnet_v2.tflite'),
      await open('assets/models/antispoof_minifasnet_v1se.tflite'),
    );
  }

  /// Ubah CameraImage (NV21) ke FrameData. Null bila formatnya tidak didukung.
  static FrameData? frameFrom(CameraImage image, int rotation) {
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return FrameData(
      bytes: Uint8List.fromList(plane.bytes),
      width: image.width,
      height: image.height,
      stride: plane.bytesPerRow,
      rotation: rotation,
    );
  }

  Future<FaceObservation> analyze(FrameData frame, {required bool liveness}) async {
    final input = InputImage.fromBytes(
      bytes: frame.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(frame.rotation) ?? InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: frame.stride,
      ),
    );

    final faces = await _detector.processImage(input);
    if (faces.isEmpty) return FaceObservation(frame: frame, issue: FaceIssue.noFace);

    faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(a.boundingBox.width * a.boundingBox.height));
    final face = faces.first;
    final box = face.boundingBox;
    final (uw, uh) = frame.upright;
    final yaw = face.headEulerAngleY ?? 0;

    FaceObservation fail(FaceIssue issue) => FaceObservation(frame: frame, issue: issue, box: box, yaw: yaw);

    final ratio = box.width / uw;
    if (box.left < 0 || box.top < 0 || box.right > uw || box.bottom > uh) return fail(FaceIssue.partial);
    if (ratio < minFaceRatio) return fail(FaceIssue.tooFar);
    if (ratio > maxFaceRatio) return fail(FaceIssue.tooClose);

    final luma = frame.meanLuma(box.left, box.top, box.width, box.height);
    if (luma < 45) return fail(FaceIssue.tooDark);
    if (luma > 235) return fail(FaceIssue.tooBright);

    final lm = face.landmarks;
    final le = lm[FaceLandmarkType.leftEye]?.position;
    final re = lm[FaceLandmarkType.rightEye]?.position;
    final nose = lm[FaceLandmarkType.noseBase]?.position;
    final ml = lm[FaceLandmarkType.leftMouth]?.position;
    final mr = lm[FaceLandmarkType.rightMouth]?.position;
    if (le == null || re == null || nose == null || ml == null || mr == null) return fail(FaceIssue.notFrontal);

    final points = orderLandmarks(
      eyeA: P(le.x.toDouble(), le.y.toDouble()),
      eyeB: P(re.x.toDouble(), re.y.toDouble()),
      nose: P(nose.x.toDouble(), nose.y.toDouble()),
      mouthA: P(ml.x.toDouble(), ml.y.toDouble()),
      mouthB: P(mr.x.toDouble(), mr.y.toDouble()),
    );

    final embedding = await embed(frame, points);

    double? live;
    if (liveness) {
      live = await _liveness(frame, box);
    }

    return FaceObservation(frame: frame, issue: FaceIssue.none, box: box, yaw: yaw, embedding: embedding, liveness: live);
  }

  /// Toleransi sudut wajah untuk absen (enrolment memakai aturannya sendiri).
  static bool frontal(FaceObservation o, {double maxYaw = 20}) => o.yaw.abs() <= maxYaw;

  Future<Float32List> embed(FrameData frame, List<P> points) async {
    final input = frame.alignedFace(points).reshape([1, 112, 112, 3]);
    final output = [List<double>.filled(512, 0)];
    await _recognizer.run(input, output);
    return normalize(output[0]);
  }

  Future<double> _liveness(FrameData frame, Rect box) async {
    Future<double> run(IsolateInterpreter model, double scale) async {
      final patch = frame.antiSpoofPatch(x: box.left, y: box.top, w: box.width, h: box.height, scale: scale);
      final output = [List<double>.filled(3, 0)];
      await model.run(patch.reshape([1, 80, 80, 3]), output);
      final logits = output[0];
      final m = logits.reduce(math.max);
      final e = logits.map((v) => math.exp(v - m)).toList();
      final sum = e.reduce((a, b) => a + b);
      return e[1] / sum; // indeks 1 = wajah asli
    }

    final v2 = await run(_spoofV2, 2.7);
    final v1 = await run(_spoofV1, 4.0);
    return (v2 + v1) / 2;
  }

  Future<void> dispose() async {
    await _detector.close();
    await _recognizer.close();
    await _spoofV2.close();
    await _spoofV1.close();
  }
}
