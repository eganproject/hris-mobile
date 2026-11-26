import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/core/api/api_client.dart';
import 'package:hris_mobile/core/auth/auth_controller.dart';
import 'package:hris_mobile/core/auth/models.dart';
import 'package:hris_mobile/core/router/app_router.dart';
import 'package:hris_mobile/core/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

/// Tes asap: setiap tab utama tampil tanpa galat/overflow di layar HP 390×844,
/// untuk karyawan biasa dan atasan, memakai data API palsu.
///
/// Tangkapan layar (opsional): SHOTS_DIR=/path flutter test test/screens_test.dart --update-goldens
void main() {
  final shots = Platform.environment['SHOTS_DIR'];

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    if (shots != null) await _loadFonts();
  });

  for (final leader in [false, true]) {
    final who = leader ? 'atasan' : 'karyawan';
    final tabs = ['/', '/kehadiran', '/kehadiran?tab=jadwal', '/pengajuan', leader ? '/tim' : '/info', '/info?tab=rekan', '/profil'];
    for (final path in tabs) {
      testWidgets('$who: $path tampil', (tester) async {
        await _pump(tester, leader: leader, path: path);
        expect(tester.takeException(), isNull);
        if (shots != null) {
          final name = '${who}_${path == '/' ? 'beranda' : path.substring(1).replaceAll(RegExp(r'[?=]'), '_')}.png';
          await expectLater(find.byType(MaterialApp), matchesGoldenFile(Uri.file('$shots/$name')));
        }
      });
    }
  }

  // Layar baru, termasuk di HP sempit (320) dan tablet (820).
  for (final width in [320.0, 390.0, 820.0]) {
    for (final (path, leader) in [
      ('/aset', false),
      ('/notifikasi', false),
      ('/jadwal', false),
      ('/pengajuan/tukar', false),
      ('/pengajuan/cuti?kategori=cuti', false),
      ('/tim/anggota/4', true),
      ('/tim/hari-ini', true),
      ('/tim/persetujuan', true),
      ('/pengajuan/lembur', false),
      ('/pengajuan/cuti?kategori=sakit', false),
      ('/pengajuan/semua', false),
      ('/koreksi', false),
      ('/struktur', false),
      ('/profil/data-diri', false),
      ('/rekan', true),
    ]) {
      testWidgets('$path tampil di lebar ${width.toInt()}', (tester) async {
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          if (Platform.environment['DEBUG_OVERFLOW'] != null) FlutterError.dumpErrorToConsole(d, forceReport: true);
          old?.call(d);
        };
        addTearDown(() => FlutterError.onError = old);
        await _pump(tester, leader: leader, path: path, width: width);
        expect(tester.takeException(), isNull);
        if (shots != null && width == 390) {
          final name = 'baru_${path.substring(1).replaceAll(RegExp(r'[/?=]'), '_')}.png';
          await expectLater(find.byType(MaterialApp), matchesGoldenFile(Uri.file('$shots/$name')));
        }
      });
    }
  }

  testWidgets('notifikasi aset bisa diketuk dan dikonfirmasi', (tester) async {
    await _pump(tester, leader: false, path: '/notifikasi');
    await tester.tap(find.text('Aset diserahkan kepada Anda'));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi terima'), findsOneWidget);
    expect(find.text('Lihat aset saya'), findsOneWidget);
    if (shots != null) await expectLater(find.byType(MaterialApp), matchesGoldenFile(Uri.file('$shots/baru_notifikasi_detail.png')));
  });

  testWidgets('jenis cuti bisa diketik untuk dicari', (tester) async {
    await _pump(tester, leader: false, path: '/pengajuan/cuti?kategori=cuti');
    await tester.tap(find.text('Jenis'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'duka');
    await tester.pumpAndSettle();
    expect(find.text('Cuti duka'), findsOneWidget);
    expect(find.text('Cuti menikah'), findsNothing);
    if (shots != null) await expectLater(find.byType(MaterialApp), matchesGoldenFile(Uri.file('$shots/baru_pilih_cari.png')));
    await tester.tap(find.text('Cuti duka'));
    await tester.pumpAndSettle();
    expect(find.text('Cuti duka'), findsOneWidget);
  });

  testWidgets('pilihan rekan bisa dicari', (tester) async {
    await _pump(tester, leader: false, path: '/pengajuan/tukar');
    await tester.tap(find.text('Rekan'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih rekan'), findsOneWidget);
    await tester.tap(find.text('Dewi Wulandari'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dewi Wulandari'), findsOneWidget);
  });

  testWidgets('layar masuk tampil', (tester) async {
    await _pump(tester, leader: false, path: '/login', signedIn: false);
    expect(find.text('Masuk'), findsOneWidget);
    if (shots != null) await expectLater(find.byType(MaterialApp), matchesGoldenFile(Uri.file('$shots/masuk.png')));
  });
}

Future<void> _pump(WidgetTester tester, {required bool leader, required String path, bool signedIn = true, double width = 390}) async {
  tester.view.physicalSize = Size(width * 2, (width > 600 ? 1180 : 844) * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    apiClientProvider.overrideWithValue(_fakeDio(leader)),
    authControllerProvider.overrideWith(() => _FakeAuth(signedIn ? _user(leader) : null)),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: Consumer(
      builder: (_, ref, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(fontFamily: 'Inter'),
        routerConfig: ref.watch(routerProvider),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  if (path != '/' && path != '/login') {
    // Layar penuh (bukan tab) dibuka di atas Beranda, seperti di aplikasi.
    final isTab = ['/kehadiran', '/pengajuan', '/info', '/tim', '/profil'].any((t) => path == t || path.startsWith('$t?'));
    if (isTab) {
      container.read(routerProvider).go(path);
    } else {
      container.read(routerProvider).push(path);
    }
    await tester.pumpAndSettle();
  }
}

class _FakeAuth extends AuthController {
  _FakeAuth(this.user);
  final AppUser? user;

  @override
  AuthState build() => user == null ? const AuthSignedOut() : AuthSignedIn(user!);
}

AppUser _user(bool leader) => AppUser.fromJson({
      'id': 1,
      'name': 'Rina Sari',
      'email': 'rina@contoh.co.id',
      'is_leader': leader,
      'employee': {
        'id': 10,
        'number': '2024017',
        'full_name': leader ? 'Hendra Wijaya' : 'Rina Sari',
        'department': 'Keuangan',
        'job_position': leader ? 'Manajer Keuangan' : 'Staf Keuangan',
        'branch': {'id': 1, 'name': 'Kantor Pusat'},
        'manager': {'full_name': 'Hendra Wijaya'},
      },
    });

String _d(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _person(int id, String name, String job, {bool online = false}) => {
      'id': id,
      'name': name,
      'initials': name.split(' ').take(2).map((w) => w[0]).join(),
      'job_title': job,
      'department': 'Keuangan',
      'photo_url': null,
      'online': online,
      'last_seen_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    };

Map<String, dynamic> _asset(int id, String state) => {
      'id': id,
      'state': state,
      'asset': {
        'id': id,
        'code': 'LPT-00$id$id',
        'name': ['Laptop Lenovo ThinkPad E14', 'Monitor Dell 24 inci', 'Kartu akses gedung', 'HP Samsung A15'][id - 1],
        'brand': 'Lenovo',
        'model': 'E14 Gen 5',
        'serial_number': 'SN-88231$id',
        'category': 'Elektronik',
      },
      'assigned_at': '${_d(-30 * id)}T09:00:00+07:00',
      'assigned_by': 'Tim IT',
      'expected_return_at': state == 'overdue' ? _d(-3) : null,
      'condition_out': 'Baik',
      'purpose': 'Kerja harian',
      'notes': null,
      'acknowledged_at': state == 'unacknowledged' ? null : '${_d(-29 * id)}T10:00:00+07:00',
      'acknowledgement_note': null,
      'returned_at': state == 'returned' ? '${_d(-10)}T16:00:00+07:00' : null,
      'condition_in': state == 'returned' ? 'Baik' : null,
    };

Object? _response(String path, Map<String, dynamic> q, bool leader) {
  final today = _d(0);
  switch (path) {
    case '/attendance/status':
      return {
        'data': {
          'server_time': DateTime.now().toIso8601String(),
          'work_date': today,
          'session': {'open': true, 'clock_in_at': '${today}T07:52:00+07:00'},
          'schedule': {
            'is_day_off': false,
            'shift': {'name': 'Shift Pagi', 'start': '08:00', 'end': '17:00'},
          },
          'settings': <String, dynamic>{},
          'attendance': {
            'id': 1,
            'work_date': today,
            'status': 'present',
            'status_label': 'Hadir',
            'clock_in': '${today}T07:52:00+07:00',
          },
        },
      };
    case '/attendance/history':
      return {
        'data': {
          'summary': {'present': 17, 'late': 2, 'absent': 0},
          'items': [
            for (var i = 0; i < 6; i++)
              {
                'id': i + 1,
                'work_date': _d(-i),
                'status': i == 2 ? 'late' : 'present',
                'status_label': 'Hadir',
                'shift': 'Shift Pagi 08:00–17:00',
                'clock_in': '${_d(-i)}T07:5$i:00+07:00',
                'clock_out': i == 0 ? null : '${_d(-i)}T17:0$i:00+07:00',
                'late_minutes': i == 2 ? 9 : 0,
                'flags': i == 4 ? ['Lupa absen pulang'] : <String>[],
              },
          ],
        },
      };
    case '/schedule':
      final from = DateTime.parse(q['from'] as String);
      final to = q['to'] == null ? from.add(const Duration(days: 6)) : DateTime.parse(q['to'] as String);
      return {
        'data': {
          'days': [
            for (var i = 0; i <= to.difference(from).inDays; i++)
              () {
                final d = from.add(Duration(days: i));
                final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                final off = d.weekday >= 6;
                final mode = off ? 'off' : d.day % 9 == 0 ? 'leave' : d.day % 5 == 0 ? 'wfh' : 'office';
                return {
                  'date': date,
                  'mode': mode,
                  'label': off ? 'Libur' : mode == 'leave' ? 'Cuti' : mode == 'wfh' ? 'WFH' : 'Shift Pagi',
                  'is_holiday': false,
                  'shift': mode == 'office' || mode == 'wfh'
                      ? {'code': d.day.isEven ? 'P' : 'S', 'start_time': '08:00', 'end_time': '17:00'}
                      : null,
                  'location': off ? null : 'Kantor Pusat',
                  'leave': mode == 'leave' ? {'id': 1, 'name': 'Cuti tahunan'} : null,
                };
              }(),
          ],
          'pending_confirmations': [
            {'week_start': _d(7 - DateTime.now().weekday + 1), 'week_end': _d(7 - DateTime.now().weekday + 7)},
          ],
        },
      };
    case '/assets':
      return {
        'data': {
          'open': [_asset(1, 'unacknowledged'), _asset(2, 'held'), _asset(3, 'overdue')],
          'history': [_asset(4, 'returned')],
          'counts': {'open': 3, 'unacknowledged': 1, 'overdue': 1},
        },
      };
    case '/assets/1':
      return {'data': _asset(1, 'unacknowledged')};
    case '/notifications':
      return {
        'data': [
          {'id': 'a', 'category': 'asset', 'title': 'Aset diserahkan kepada Anda', 'message': 'Laptop Lenovo ThinkPad E14 (LPT-0012) diserahkan oleh Tim IT. Mohon konfirmasi penerimaannya.', 'created_at': DateTime.now().toIso8601String(), 'read': false, 'meta': {'assignment_id': 1}},
          {'id': 'b', 'category': 'leave', 'title': 'Cuti disetujui', 'message': 'Cuti tahunan 2 hari Anda disetujui.', 'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'read': true, 'meta': <String, dynamic>{}},
          {'id': 'c', 'category': 'schedule', 'title': 'Jadwal minggu depan terbit', 'message': 'Cek dan konfirmasi jadwalmu.', 'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'read': true, 'meta': <String, dynamic>{}},
        ],
      };
    case '/leave-types':
      return {
        'data': [
          for (final (i, n) in ['Cuti tahunan', 'Cuti menikah', 'Cuti melahirkan', 'Cuti duka', 'Cuti besar', 'Cuti haji', 'Cuti khitan anak'].indexed)
            {'id': i + 1, 'name': n, 'category': 'cuti', 'remaining': i == 0 ? 9 : null, 'requires_attachment': false},
          {'id': 20, 'name': 'Izin pribadi', 'category': 'izin'},
          {'id': 30, 'name': 'Sakit dengan surat dokter', 'category': 'sakit', 'requires_attachment': true},
        ],
      };
    case '/swaps/colleagues':
      return {
        'data': [_person(2, 'Budi Santoso', 'Kasir'), _person(3, 'Dewi Wulandari', 'Staf Pajak')],
        'meta': {'types': {'swap': 'Tukar shift', 'cover': 'Gantikan shift'}},
      };
    case '/team/members/4':
      return {
        'data': {
          'person': {..._person(4, 'Yoga Hidayat', 'Staf Penagihan'), 'branch': 'Kantor Pusat', 'joined': '2022-03', 'manager': _person(5, 'Hendra Wijaya', 'Manajer Keuangan'), 'is_direct': true},
          'month': q['month'],
          'summary': {'present': 14, 'late': 2, 'leave': 1, 'absent': 0, 'late_minutes': 23},
          'items': [
            for (var i = 0; i < 8; i++)
              {
                'id': i,
                'work_date': _d(-i),
                'status': i == 2 ? 'late' : i == 5 ? 'leave' : 'present',
                'status_label': i == 2 ? 'Terlambat' : i == 5 ? 'Cuti' : 'Hadir',
                'shift': i == 5 ? null : 'Shift Pagi',
                'clock_in': i == 5 ? null : '${_d(-i)}T07:5$i:00+07:00',
                'clock_out': i == 5 || i == 0 ? null : '${_d(-i)}T17:0$i:00+07:00',
                'late_minutes': i == 2 ? 12 : 0,
                'note': null,
              },
          ],
        },
      };
    case '/pengajuan/ringkasan':
      return {
        'data': {
          'balances': [
            {'name': 'Cuti tahunan', 'year': 2026, 'quota': 12, 'remaining': 9, 'used': 3, 'pending_days': 2},
          ],
          'recent': [
            {'kind': 'leave', 'id': 1, 'category': 'cuti', 'title': 'Cuti tahunan · 2 hari', 'start_date': _d(26), 'end_date': _d(27), 'status_label': 'Menunggu', 'tone': 'warning'},
            {'kind': 'overtime', 'id': 2, 'category': 'lembur', 'title': 'Lembur 2 jam', 'work_date': _d(-2), 'start_time': '17:00', 'end_time': '19:00', 'status_label': 'Disetujui', 'tone': 'success'},
          ],
        },
      };
    case '/announcements':
      return {
        'data': [
          {'id': 1, 'title': 'Jadwal libur akhir tahun 2026', 'excerpt': 'Kantor tutup tanggal 25 Desember dan 1 Januari. Silakan atur cuti dari sekarang.', 'published_at': _d(-1), 'is_read': false, 'is_pinned': true},
          {'id': 2, 'title': 'Pembaruan aturan lembur', 'excerpt': 'Mulai Desember, lembur wajib diajukan paling lambat H+1.', 'published_at': _d(-6), 'is_read': true},
        ],
      };
    case '/notifications/unread-count':
      return {'data': {'count': 2}};
    case '/people':
      return {
        'data': [
          _person(2, 'Budi Santoso', 'Kasir', online: true),
          _person(3, 'Dewi Wulandari', 'Staf Pajak', online: true),
          _person(4, 'Yoga Hidayat', 'Staf Penagihan'),
          _person(5, 'Hendra Wijaya', 'Manajer Keuangan'),
        ],
        'meta': {'online_count': 2, 'offline_count': 2},
      };
    case '/profile':
      return {
        'data': {
          'is_leader': leader,
          if (leader) 'leader': {'pending_approvals': 3, 'team_size': 14},
        },
      };
    case '/team/today':
      Map<String, dynamic> m(int id, String name, String job, String state, {String? clockIn, int late = 0}) => {
            'employee': _person(id, name, job),
            'schedule': {'label': state == 'leave' ? 'Cuti tahunan' : 'Shift Pagi', 'shift': {'code': 'P', 'start_time': '08:00', 'end_time': '17:00'}},
            'state': state,
            'clock_in': clockIn,
            'late_minutes': late,
          };
      return {
        'data': {
          'counts': {'present': 10, 'late': 2, 'not_yet': 1, 'leave': 1},
          'team_size': 14,
          'as_of': '09:12',
          'members': [
            m(4, 'Yoga Hidayat', 'Staf Penagihan', 'not_yet'),
            m(2, 'Budi Santoso', 'Kasir', 'present', clockIn: '07:49'),
            m(3, 'Dewi Wulandari', 'Staf Pajak', 'late', clockIn: '08:09', late: 9),
            m(6, 'Rina Sari', 'Staf Keuangan', 'leave'),
          ],
        },
      };
    case '/approvals':
      return {
        'data': [
          {'kind': 'leave', 'id': 1, 'category': 'cuti', 'employee': _person(6, 'Rina Sari', 'Staf Keuangan'), 'title': 'Cuti tahunan · 2 hari', 'reason': 'Acara keluarga di luar kota.', 'start_date': _d(26), 'end_date': _d(27), 'submitted_at': _d(-1)},
          {'kind': 'overtime', 'id': 2, 'category': 'lembur', 'employee': _person(2, 'Budi Santoso', 'Kasir'), 'title': 'Lembur', 'work_date': _d(-2), 'start_time': '17:00', 'end_time': '19:00'},
          {'kind': 'leave', 'id': 3, 'category': 'izin', 'employee': _person(3, 'Dewi Wulandari', 'Staf Pajak'), 'title': 'Izin', 'start_date': _d(3), 'end_date': _d(3)},
        ],
        'meta': {'total': 3, 'counts': {'cuti': 1, 'izin': 1, 'lembur': 1}},
      };
  }
  return {'data': <String, dynamic>{}};
}

Dio _fakeDio(bool leader) {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake/api/mobile/v1'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    final path = options.path.startsWith('/') ? options.path : '/${options.path}';
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: _response(path, options.queryParameters, leader)));
  }));
  return dio;
}

Future<void> _loadFonts() async {
  const dir = '/usr/share/fonts/opentype/inter';
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final f = File('$dir/Inter-$w.otf');
    if (f.existsSync()) inter.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  }
  await inter.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/home/user/flutter';
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  }
}
