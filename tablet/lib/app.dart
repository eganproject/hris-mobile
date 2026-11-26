import 'package:material_ui/material_ui.dart';

import 'core/tablet_controller.dart';
import 'face/camera_service.dart';
import 'face/face_engine.dart';
import 'ui/screens/home_page.dart';
import 'ui/screens/setup_page.dart';
import 'ui/theme.dart';

class TabletApp extends StatefulWidget {
  const TabletApp({super.key, required this.tablet, required this.camera});
  final TabletController tablet;
  final CameraService camera;

  @override
  State<TabletApp> createState() => _TabletAppState();
}

class _TabletAppState extends State<TabletApp> with WidgetsBindingObserver {
  FaceEngine? _engine;
  String? _engineError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FaceEngine.load().then((e) {
      if (mounted) setState(() => _engine = e);
    }).catchError((Object e) {
      if (mounted) setState(() => _engineError = 'Model wajah gagal dimuat: $e');
    });
    widget.camera.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kamera dilepas saat aplikasi di latar belakang dan dinyalakan lagi saat kembali.
    if (state == AppLifecycleState.paused) {
      widget.camera.stop();
    } else if (state == AppLifecycleState.resumed) {
      widget.camera.start();
      widget.tablet.syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi Tablet',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: widget.tablet,
        builder: (context, _) {
          final t = widget.tablet;
          if (!t.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (!t.paired) return SetupPage(tablet: t);
          if (_engineError != null) return Scaffold(body: Center(child: Text(_engineError!)));
          final engine = _engine;
          if (engine == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return HomePage(tablet: t, camera: widget.camera, engine: engine);
        },
      ),
    );
  }
}
