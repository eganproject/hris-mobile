import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/login_page.dart';
import '../../features/beranda/beranda_page.dart';
import '../../features/koreksi/koreksi_page.dart';
import '../../features/pengajuan/pengajuan_page.dart';
import '../../features/info/info_page.dart';
import '../../features/izin/izin_page.dart';
import '../../features/izin/izin_setup.dart';
import '../../features/kehadiran/kehadiran_page.dart';
import '../../features/profil/profil_page.dart';
import '../../features/tahap2_routes.dart';
import '../../features/tim/tim_page.dart';
import '../auth/auth_controller.dart';
import '../shell/main_shell.dart';
import '../theme/app_colors.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Rute aplikasi. Menu bawah (shell): / (Beranda), /kehadiran, /pengajuan,
/// /info (karyawan) atau /tim (atasan), /profil. Layar penuh: /login, /izin,
/// /koreksi, ditambah [tahap2Routes]. Urutan cabang = [ShellTab].
/// Absen masuk/pulang tidak lagi lewat HP (pakai tablet kantor / mesin).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(izinSetupDoneProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (auth is AuthLoading) return loc == '/splash' ? null : '/splash';
      if (auth is AuthSignedOut) return loc == '/login' ? null : '/login';
      // Sekali per HP sesudah login: alur izin (notifikasi, baterai, dll.).
      if (ref.read(izinSetupDoneProvider) == false) return loc == '/izin' ? null : '/izin';
      if (loc == '/login' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/izin', parentNavigatorKey: _rootKey, builder: (_, _) => const IzinPage()),
      GoRoute(
        path: '/koreksi',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => KoreksiPage(initialDate: DateTime.tryParse(state.uri.queryParameters['date'] ?? '')),
      ),
      ...tahap2Routes,
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const BerandaPage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/kehadiran',
              builder: (_, state) => KehadiranPage(initialTab: state.uri.queryParameters['tab'] == 'jadwal' ? 1 : 0),
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/pengajuan', builder: (_, _) => const PengajuanPage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/info',
              builder: (_, state) => InfoPage(initialTab: state.uri.queryParameters['tab'] == 'rekan' ? 1 : 0),
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/tim', builder: (_, _) => const TimPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profil', builder: (_, _) => const ProfilPage())]),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(kDebugMode ? 'Halaman tidak ditemukan: ${state.uri}' : 'Halaman belum tersedia.')),
    ),
  );
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
}
