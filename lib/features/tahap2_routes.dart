import 'package:go_router/go_router.dart';

import 'aset/aset_page.dart';
import 'info/info_page.dart';
import 'jadwal/jadwal_page.dart';
import 'notifikasi/notifikasi_page.dart';
import 'organisasi/struktur_page.dart';
import 'pengajuan/leave_form_page.dart';
import 'pengajuan/overtime_form_page.dart';
import 'pengajuan/pengajuan_list_page.dart';
import 'pengajuan/swap_form_page.dart';
import 'pengumuman/pengumuman_page.dart';
import 'profil/data_diri_page.dart';
import 'profil/notif_help_page.dart';
import 'tim/anggota_tim_page.dart';
import 'tim/jadwal_tim_page.dart';
import 'tim/persetujuan_page.dart';
import 'tim/tim_hari_ini_page.dart';

/// Rute fitur Tahap 2, tampil layar penuh (di luar menu bawah).
///
/// Pengajuan: /pengajuan/cuti?kategori=cuti|izin|sakit, /pengajuan/lembur,
/// /pengajuan/tukar?date=YYYY-MM-DD, /pengajuan/semua.
/// Lainnya: /jadwal, /notifikasi, /profil/data-diri, /profil/notifikasi-hp,
/// /struktur, /rekan.
/// Aset saya: /aset.
/// Atasan: /tim/persetujuan, /tim/hari-ini, /tim/jadwal, /tim/anggota/:id.
/// Pengumuman HR: /pengumuman/:id (daftarnya ada di tab Info).
final List<RouteBase> tahap2Routes = [
  GoRoute(
    path: '/pengajuan/cuti',
    builder: (_, state) => LeaveFormPage(category: state.uri.queryParameters['kategori'] ?? 'cuti'),
  ),
  GoRoute(path: '/pengajuan/lembur', builder: (_, _) => const OvertimeFormPage()),
  GoRoute(
    path: '/pengajuan/tukar',
    builder: (_, state) => SwapFormPage(date: state.uri.queryParameters['date']),
  ),
  GoRoute(path: '/pengajuan/semua', builder: (_, _) => const PengajuanListPage()),
  GoRoute(path: '/jadwal', builder: (_, _) => const JadwalPage()),
  GoRoute(path: '/notifikasi', builder: (_, _) => const NotifikasiPage()),
  GoRoute(path: '/profil/data-diri', builder: (_, _) => const DataDiriPage()),
  GoRoute(path: '/profil/notifikasi-hp', builder: (_, _) => const NotifHelpPage()),
  GoRoute(path: '/struktur', builder: (_, _) => const StrukturPage()),
  GoRoute(path: '/rekan', builder: (_, _) => const RekanPage()),
  GoRoute(path: '/tim/persetujuan', builder: (_, _) => const PersetujuanPage()),
  GoRoute(path: '/tim/hari-ini', builder: (_, state) => TimHariIniPage(initialState: state.uri.queryParameters['status'])),
  GoRoute(path: '/tim/jadwal', builder: (_, _) => const JadwalTimPage()),
  GoRoute(
    path: '/tim/anggota/:id',
    builder: (_, state) => AnggotaTimPage(id: int.parse(state.pathParameters['id']!)),
  ),
  GoRoute(path: '/aset', builder: (_, _) => const AsetPage()),
  GoRoute(
    path: '/pengumuman/:id',
    builder: (_, state) => PengumumanDetailPage(id: int.parse(state.pathParameters['id']!)),
  ),
];
