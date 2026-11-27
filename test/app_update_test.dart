import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/core/update/app_update.dart';
import 'package:material_ui/material_ui.dart';

Map<String, dynamic> _response({required bool requiredUpdate}) => {
      'current_version_code': 45,
      'min_version_code': requiredUpdate ? 52 : 0,
      'update_available': true,
      'update_required': requiredUpdate,
      'latest': {
        'version_code': 53,
        'version_name': '1.0.0',
        'size': 60817408,
        'sha256': 'ABC123',
        'notes': 'Perbaikan notifikasi persetujuan',
        'download_url': 'https://cok-hris.com/unduh-aplikasi/apk',
      },
    };

void main() {
  test('jawaban server: hanya update_required yang menghalangi', () {
    expect(AppUpdateInfo.fromResponse(_response(requiredUpdate: false)), isNull);

    final info = AppUpdateInfo.fromResponse(_response(requiredUpdate: true))!;
    expect(info.currentCode, 45);
    expect(info.versionCode, 53);
    expect(info.sha256, 'abc123');
    expect(info.sizeLabel, '58 MB');
  });

  testWidgets('layar wajib update menutup aplikasi', (tester) async {
    final updater = AppUpdater(checkUrl: 'https://contoh.test/api/app-update/employee');
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => UpdateGate(updater: updater, child: child!),
      home: Scaffold(body: Center(child: ElevatedButton(onPressed: () {}, child: const Text('Beranda')))),
    ));
    expect(find.text('Perlu update aplikasi'), findsNothing);

    updater.required = AppUpdateInfo.fromResponse(_response(requiredUpdate: true));
    updater.notifyListeners();
    await tester.pump();

    expect(find.text('Perlu update aplikasi'), findsOneWidget);
    expect(find.text('Update sekarang'), findsOneWidget);
    expect(find.text('Versi kamu: build 45'), findsOneWidget);
    expect(find.text('Perbaikan notifikasi persetujuan'), findsOneWidget);

    // Layar di bawahnya tidak bisa diketuk.
    await tester.tap(find.text('Beranda'), warnIfMissed: false);
    expect(find.byType(IgnorePointer), findsWidgets);

    updater.phase = UpdatePhase.needPermission;
    updater.notifyListeners();
    await tester.pump();
    expect(find.text('Buka pengaturan'), findsOneWidget);

    updater.phase = UpdatePhase.downloading;
    updater.received = 30 * 1024 * 1024;
    updater.total = 60 * 1024 * 1024;
    updater.notifyListeners();
    await tester.pump();
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('30 dari 60 MB'), findsOneWidget);
  });
}
