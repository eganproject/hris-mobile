import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_update.dart';
import 'core/config.dart';
import 'core/tablet_controller.dart';
import 'face/camera_service.dart';
import 'face/face_engine.dart';
import 'platform/lock_task.dart';
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

  // Wajib update: dicek saat dibuka, saat kembali ke depan, dan tiap 30 menit
  // (tablet jarang ditutup). Sematan layar dilepas sebelum pemasang Android dibuka.
  late final AppUpdater _updater = AppUpdater(
    checkUrl: '$apiBaseUrl/api/tablet/v1/app-update',
    headers: () => {if (widget.tablet.api.token != null) 'Authorization': 'Bearer ${widget.tablet.api.token}'},
    beforeInstall: () async {
      // Pemasang Android tidak bisa tampil selama layar disematkan. Ingat
      // sematannya supaya dipasang lagi saat aplikasi versi baru dibuka.
      if (await LockTask.isLocked()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_repinKey, true);
        await LockTask.stop();
      }
    },
    recheckEvery: const Duration(minutes: 30),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.tablet.addListener(_checkUpdateOnceReady);
    _repinAfterUpdate();
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
    widget.tablet.removeListener(_checkUpdateOnceReady);
    _updater.dispose();
    super.dispose();
  }

  static const _repinKey = 'repin_after_update';

  bool _updateChecked = false;

  /// Sematkan lagi layar yang dilepas untuk memasang update.
  Future<void> _repinAfterUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_repinKey) != true) return;
    await prefs.remove(_repinKey);
    await LockTask.start();
  }

  /// Token tablet baru terbaca setelah init: cek update begitu tablet terpasang.
  void _checkUpdateOnceReady() {
    if (_updateChecked || !widget.tablet.paired) return;
    _updateChecked = true;
    _updater.check(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kamera dilepas saat aplikasi di latar belakang dan dinyalakan lagi saat kembali.
    if (state == AppLifecycleState.paused) {
      widget.camera.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!widget.camera.resting) widget.camera.start();
      widget.tablet.syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi Tablet',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => UpdateGate(updater: _updater, appName: 'Absensi Tablet', child: child ?? const SizedBox.shrink()),
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
