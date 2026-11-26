import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:hris_mobile/features/info/info_page.dart';
import 'package:hris_mobile/features/t2_common/t2_api.dart';
import 'package:hris_mobile/features/tim/jadwal_tim_page.dart';

/// API palsu: jawaban tetap per path, supaya layar bisa dirender tanpa server.
class FakeApi extends T2Api {
  FakeApi() : super(Dio());

  static Map<String, dynamic> person(int id, String name, {bool online = true}) => {
        'id': id,
        'name': name,
        'initials': name.substring(0, 2).toUpperCase(),
        'job_title': 'Supervisor Gudang dan Logistik Wilayah Barat',
        'department': 'Gudang & Logistik',
        'photo_url': null,
        'online': online,
        'last_seen_at': online ? null : DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      };

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    if (path == 'people') {
      return {
        'data': [for (var i = 1; i <= 8; i++) person(i, 'Rekan Dengan Nama Sangat Panjang Sekali $i', online: query?['status'] != 'offline')],
        'meta': {'online_count': 12, 'offline_count': 86},
      };
    }
    if (path.startsWith('people/')) {
      return {
        'data': {
          ...person(1, 'Okan Saputra Wijayakusuma Panjang'),
          'motto': 'Kerja rapi, pulang tepat waktu, dan selalu bantu rekan yang kesulitan.',
          'branch': 'Gudang Cikarang',
          'departments': ['Gudang & Logistik', 'Operasional'],
          'manager': person(9, 'Ega Nugraha'),
          'joined': '2022-03',
        },
      };
    }
    if (path == 'shifts') {
      return {
        'data': [
          {'id': 1, 'code': 'P', 'name': 'Pagi', 'start_time': '07:00', 'end_time': '15:00'},
          {'id': 2, 'code': 'S', 'name': 'Siang', 'start_time': '13:00', 'end_time': '21:00'},
          {'id': 3, 'code': 'M', 'name': 'Malam Panjang', 'start_time': '21:00', 'end_time': '05:00'},
        ],
      };
    }
    if (path == 'team/schedule') {
      final start = DateTime.parse(query!['week_start'] as String);
      const modes = ['office', 'wfh', 'off', 'leave', 'none', 'office', 'trip'];
      return {
        'data': {
          'team_size': 7,
          'branch': 'Kantor Pusat',
          'published_at': null,
          'confirmed_count': 0,
          'members': [
            for (var m = 0; m < 7; m++)
              {
                'employee': person(m + 1, 'Anggota Tim Nama Panjang $m'),
                'manager_name': m.isEven ? 'Okan' : null,
                'confirmed': m == 1,
                'days': [
                  for (var d = 0; d < 7; d++)
                    {
                      'date': start.add(Duration(days: d)).toIso8601String().substring(0, 10),
                      'mode': modes[(m + d) % 7],
                      'code': 'P',
                      'shift_id': 1,
                      'shift_name': 'Pagi',
                      'label': 'Cuti Tahunan',
                      'time': '07:00 – 15:00',
                      'editable': true,
                    },
                ],
              },
          ],
        },
      };
    }
    return {'data': {}};
  }
}

Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [t2ApiProvider.overrideWithValue(FakeApi())],
    child: MaterialApp(home: child),
  ));
  await tester.pumpAndSettle();
}

void main() {
  const sizes = [Size(320, 640), Size(390, 844), Size(820, 1180)];

  for (final size in sizes) {
    final w = size.width.toInt();

    testWidgets('Jadwal tim tanpa overflow di lebar $w', (tester) async {
      await pumpAt(tester, size, const JadwalTimPage());
      expect(tester.takeException(), isNull);
      expect(find.text('Jadwal tim'), findsOneWidget);
      // Buka lembar ubah shift (gulir dulu bila layar pendek).
      final pagi = find.text('Pagi', skipOffstage: false);
      expect(pagi, findsWidgets);
      await tester.ensureVisible(pagi.first);
      await tester.pumpAndSettle();
      await tester.tap(pagi.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('TERAPKAN JUGA KE'), findsOneWidget);
      await tester.tap(find.text('Sen–Jum'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Simpan untuk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rekan kerja tanpa overflow di lebar $w', (tester) async {
      await pumpAt(tester, size, const RekanPage());
      expect(tester.takeException(), isNull);
      expect(find.text('12 sedang aktif di aplikasi'), findsOneWidget);
      await tester.tap(find.textContaining('Rekan Dengan Nama Sangat Panjang Sekali 1').first);
      await tester.pumpAndSettle();
      expect(find.text('Maret 2022'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
