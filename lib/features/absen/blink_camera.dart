import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:material_ui/material_ui.dart';

/// Keadaan deteksi wajah/kedip yang ditampilkan ke pengguna.
enum BlinkPhase { starting, noFace, multipleFaces, waitingBlink, captured, timeout, error }

/// Kamera depan dengan cek kedip (liveness sederhana) memakai ML Kit di HP.
/// Tidak ada pencocokan wajah: yang dicek hanya ada satu wajah dan ia berkedip.
///
/// Setelah kedip terdeteksi foto diambil otomatis dan [onCaptured] dipanggil
/// dengan blinkVerified = true. Bila dalam [timeout] tidak ada kedip, fase
/// menjadi [BlinkPhase.timeout]; pemanggil boleh memanggil [BlinkCameraState.retry]
/// atau [BlinkCameraState.captureWithoutBlink].
class BlinkCamera extends StatefulWidget {
  const BlinkCamera({
    super.key,
    required this.onCaptured,
    required this.onPhase,
    this.timeout = const Duration(seconds: 10),
  });

  final void Function(XFile photo, bool blinkVerified) onCaptured;
  final ValueChanged<BlinkPhase> onPhase;
  final Duration timeout;

  @override
  State<BlinkCamera> createState() => BlinkCameraState();
}

class BlinkCameraState extends State<BlinkCamera> with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _camera;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast, minFaceSize: 0.2),
  );

  bool _busy = false;
  bool _capturing = false;
  bool _eyesWereOpen = false;
  bool _eyesClosed = false;
  Timer? _timeoutTimer;
  BlinkPhase _phase = BlinkPhase.starting;
  String? errorMessage;

  /// Progres 0..1 menuju batas waktu kedip (untuk cincin di layar).
  final ValueNotifier<double> progress = ValueNotifier(0);
  DateTime? _startedAt;
  Timer? _progressTimer;

  BlinkPhase get phase => _phase;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _progressTimer?.cancel();
    _stopStream();
    _controller?.dispose();
    _detector.close();
    progress.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopStream();
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && !_capturing) {
      _init();
    }
  }

  void _setPhase(BlinkPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    widget.onPhase(phase);
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      _camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) return;
      setState(() {});
      _startDetection();
    } on CameraException catch (e) {
      errorMessage = e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt'
          ? 'Izin kamera ditolak. Buka pengaturan aplikasi untuk mengizinkan kamera.'
          : 'Kamera tidak bisa dibuka (${e.code}).';
      _setPhase(BlinkPhase.error);
    } catch (e) {
      errorMessage = 'Kamera tidak bisa dibuka.';
      _setPhase(BlinkPhase.error);
    }
  }

  void _startDetection() {
    _eyesWereOpen = false;
    _eyesClosed = false;
    _startedAt = DateTime.now();
    progress.value = 0;
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(widget.timeout, () {
      if (_capturing) return;
      _stopStream();
      _setPhase(BlinkPhase.timeout);
    });
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final started = _startedAt;
      if (started == null) return;
      progress.value = (DateTime.now().difference(started).inMilliseconds / widget.timeout.inMilliseconds).clamp(0, 1);
    });
    _setPhase(BlinkPhase.noFace);
    _controller?.startImageStream(_onFrame);
  }

  void _stopStream() {
    _progressTimer?.cancel();
    final c = _controller;
    if (c != null && c.value.isStreamingImages) {
      c.stopImageStream().catchError((_) {});
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _capturing) return;
    _busy = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (faces.isEmpty) {
        _setPhase(BlinkPhase.noFace);
        return;
      }
      if (faces.length > 1) {
        _setPhase(BlinkPhase.multipleFaces);
        return;
      }
      _setPhase(BlinkPhase.waitingBlink);
      final face = faces.first;
      final left = face.leftEyeOpenProbability;
      final right = face.rightEyeOpenProbability;
      if (left == null || right == null) return;
      final open = left > 0.7 && right > 0.7;
      final closed = left < 0.3 && right < 0.3;
      if (open && !_eyesClosed) _eyesWereOpen = true;
      if (closed && _eyesWereOpen) _eyesClosed = true;
      if (open && _eyesClosed) {
        await _capture(blinkVerified: true);
      }
    } catch (e) {
      debugPrint('Deteksi wajah gagal: $e');
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _capture({required bool blinkVerified}) async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    _capturing = true;
    _timeoutTimer?.cancel();
    _progressTimer?.cancel();
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
      final photo = await controller.takePicture();
      _setPhase(BlinkPhase.captured);
      widget.onCaptured(photo, blinkVerified);
    } catch (e) {
      _capturing = false;
      errorMessage = 'Foto gagal diambil. Coba lagi.';
      _setPhase(BlinkPhase.error);
    }
  }

  /// Ulangi menunggu kedip.
  void retry() {
    _capturing = false;
    errorMessage = null;
    if (_controller == null || !(_controller!.value.isInitialized)) {
      _init();
      return;
    }
    _startDetection();
  }

  /// Ambil foto tanpa kedip (akan ditandai "kedip tidak terverifikasi").
  Future<void> captureWithoutBlink() => _capture(blinkVerified: false);

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF0A0F20));
    }
    // Pratinjau memenuhi layar (cover), dicerminkan seperti cermin.
    final size = controller.value.previewSize;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size?.height ?? 480,
            height: size?.width ?? 640,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
