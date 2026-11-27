import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'face_engine.dart';
import 'frame.dart';

/// Kamera depan tablet yang terus mengalirkan bingkai. Layar yang sedang aktif
/// (absen atau daftar wajah) memasang [onFrame]; bingkai baru dilewati selama
/// bingkai sebelumnya masih diproses.
class CameraService extends ChangeNotifier {
  CameraController? controller;
  CameraDescription? _camera;
  String? error;
  bool _busy = false;

  /// Kamera sengaja dimatikan oleh layar istirahat: jangan dinyalakan lagi
  /// saat aplikasi kembali ke depan.
  bool resting = false;

  Future<void> Function(FrameData frame)? onFrame;

  bool get ready => controller?.value.isInitialized ?? false;

  Future<void> start() async {
    if (ready) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('no_camera', 'Tablet ini tidak punya kamera.');
      _camera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
      final c = CameraController(_camera!, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
      await c.initialize();
      controller = c;
      error = null;
      notifyListeners();
      await c.startImageStream(_handle);
    } on CameraException catch (e) {
      error = e.code == 'CameraAccessDenied' ? 'Izin kamera ditolak. Buka Setelan > Aplikasi > Absensi Tablet > Izin.' : (e.description ?? e.code);
      notifyListeners();
    }
  }

  int _rotation() {
    final c = controller;
    final cam = _camera;
    if (c == null || cam == null) return 0;
    const degrees = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final device = degrees[c.value.deviceOrientation] ?? 0;
    return cam.lensDirection == CameraLensDirection.front
        ? (cam.sensorOrientation + device) % 360
        : (cam.sensorOrientation - device + 360) % 360;
  }

  Future<void> _handle(CameraImage image) async {
    final handler = onFrame;
    if (_busy || handler == null) return;
    final frame = FaceEngine.frameFrom(image, _rotation());
    if (frame == null) return;
    _busy = true;
    try {
      await handler(frame);
    } catch (e) {
      debugPrint('frame error: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> stop() async {
    final c = controller;
    controller = null;
    notifyListeners();
    if (c != null) {
      try {
        await c.stopImageStream();
      } catch (_) {}
      await c.dispose();
    }
  }
}
