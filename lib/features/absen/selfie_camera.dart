import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Keadaan kamera selfie yang ditampilkan ke pengguna.
enum SelfiePhase { starting, ready, capturing, captured, error }

/// Kamera depan untuk selfie absen. Tanpa cek kedip dan tanpa pencocokan
/// wajah: karyawan menekan tombol potret, foto langsung dikirim.
class SelfieCamera extends StatefulWidget {
  const SelfieCamera({super.key, required this.onCaptured, required this.onPhase});

  final ValueChanged<XFile> onCaptured;
  final ValueChanged<SelfiePhase> onPhase;

  @override
  State<SelfieCamera> createState() => SelfieCameraState();
}

class SelfieCameraState extends State<SelfieCamera> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _capturing = false;
  SelfiePhase _phase = SelfiePhase.starting;
  String? errorMessage;

  SelfiePhase get phase => _phase;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && !_capturing) {
      _init();
    }
  }

  void _setPhase(SelfiePhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    widget.onPhase(phase);
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    _setPhase(SelfiePhase.starting);
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) return;
      errorMessage = null;
      _setPhase(SelfiePhase.ready);
    } on CameraException catch (e) {
      errorMessage = e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt'
          ? 'Izin kamera ditolak. Buka pengaturan aplikasi untuk mengizinkan kamera.'
          : 'Kamera tidak bisa dibuka (${e.code}).';
      _setPhase(SelfiePhase.error);
    } catch (_) {
      errorMessage = 'Kamera tidak bisa dibuka.';
      _setPhase(SelfiePhase.error);
    }
  }

  /// Ambil foto selfie.
  Future<void> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;
    _capturing = true;
    _setPhase(SelfiePhase.capturing);
    try {
      final photo = await controller.takePicture();
      _setPhase(SelfiePhase.captured);
      widget.onCaptured(photo);
    } catch (_) {
      _capturing = false;
      errorMessage = 'Foto gagal diambil. Coba lagi.';
      _setPhase(SelfiePhase.error);
    }
  }

  /// Buka ulang kamera (mis. setelah galat).
  void retry() {
    _capturing = false;
    errorMessage = null;
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      _init();
    } else {
      _setPhase(SelfiePhase.ready);
    }
  }

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
