import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/login_page.dart';
import '../../features/beranda/beranda_page.dart';
import '../../features/koreksi/koreksi_page.dart';
import '../../features/pengajuan/pengajuan_page.dart';
import '../../features/pengumuman/pengumuman_page.dart';
import '../../features/profil/profil_page.dart';
import '../../features/riwayat/riwayat_page.dart';
import '../../features/tahap2_routes.dart';
import '../auth/auth_controller.dart';
import '../shell/main_shell.dart';
import '../theme/app_colors.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Rute aplikasi. Menu bawah (shell): / (Beranda), /riwayat, /pengajuan,
/// /pengumuman, /profil. Layar penuh: /login, /koreksi, ditambah [tahap2Routes].
/// Absen masuk/pulang tidak lagi lewat HP (pakai tablet kantor / mesin).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
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
      if (loc == '/login' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
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
          StatefulShellBranch(routes: [GoRoute(path: '/riwayat', builder: (_, _) => const RiwayatPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/pengajuan', builder: (_, _) => const PengajuanPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/pengumuman', builder: (_, _) => const PengumumanListPage())]),
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
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
}
