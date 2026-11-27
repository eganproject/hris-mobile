import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/push/push_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/t2_ui.dart';

const _channel = MethodChannel('hris/notif-help');

/// Profil > "Notifikasi tidak muncul?": tiga setelan HP yang paling sering
/// membuat notifikasi absen tidak muncul, masing-masing dengan tombol pintas.
///
/// Xiaomi, Oppo, Vivo, Realme dan sejenisnya mematikan aplikasi yang tidak
/// sedang dibuka untuk menghemat baterai. Aplikasi yang "dimatikan" begitu
/// tidak menerima notifikasi sampai dibuka lagi.
class NotifHelpPage extends StatefulWidget {
  const NotifHelpPage({super.key});

  @override
  State<NotifHelpPage> createState() => _NotifHelpPageState();
}

class _NotifHelpPageState extends State<NotifHelpPage> {
  bool? _allowed;
  bool? _batteryRestricted;
  bool _hasAutostart = false;
  String _brand = '';
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Kembali dari setelan HP: perbarui centangnya.
    _lifecycle = AppLifecycleListener(onResume: _load);
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    bool? allowed;
    if (PushService.enabled) {
      try {
        final s = await FirebaseMessaging.instance.getNotificationSettings();
        allowed = s.authorizationStatus == AuthorizationStatus.authorized ||
            s.authorizationStatus == AuthorizationStatus.provisional;
      } catch (_) {}
    }
    Map<dynamic, dynamic>? status;
    if (Platform.isAndroid) {
      try {
        status = await _channel.invokeMapMethod<dynamic, dynamic>('status');
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _batteryRestricted = status?['batteryRestricted'] as bool?;
      _hasAutostart = status?['hasAutostart'] as bool? ?? false;
      _brand = status?['manufacturer'] as String? ?? '';
    });
  }

  Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<bool>(method);
    } catch (_) {}
  }

  String get _batteryTip => switch (_brand) {
        'xiaomi' || 'redmi' || 'poco' => 'Pilih "Tanpa batasan" (No restrictions).',
        'oppo' || 'realme' || 'oneplus' => 'Buka "Penggunaan baterai", nyalakan "Izinkan aktivitas latar belakang".',
        'vivo' || 'iqoo' => 'Buka "Baterai", pilih "Izinkan konsumsi daya tinggi di latar belakang".',
        'samsung' => 'Buka "Baterai", pilih "Tidak dibatasi".',
        _ => 'Pilih "Izinkan" atau "Tanpa batasan".',
      };

  @override
  Widget build(BuildContext context) {
    return DotScaffold(
      child: SafeArea(
        child: Column(children: [
          const BackHeader(title: 'Notifikasi tidak muncul?'),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
              const Text(
                'Notifikasi absen dikirim saat absenmu tercatat di tablet atau mesin. '
                'Banyak HP menghentikan aplikasi yang sedang ditutup supaya baterai awet, '
                'sehingga notifikasinya tertahan. Nyalakan ketiga setelan di bawah ini sekali saja.',
                style: TextStyle(fontSize: 13, color: AppColors.chipText, height: 1.5),
              ),
              const SizedBox(height: 16),
              _Step(
                number: 1,
                title: 'Izinkan notifikasi',
                detail: 'Nyalakan semua notifikasi HRIS COK, termasuk saluran "Absensi".',
                ok: _allowed,
                button: 'Buka setelan notifikasi',
                onPressed: () => _call('openNotificationSettings'),
              ),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 12),
                _Step(
                  number: 2,
                  title: 'Matikan penghemat baterai untuk aplikasi ini',
                  detail: _batteryTip,
                  ok: _batteryRestricted == null ? null : !_batteryRestricted!,
                  button: 'Atur baterai',
                  onPressed: () => _call('requestBattery'),
                ),
                const SizedBox(height: 12),
                _Step(
                  number: 3,
                  title: 'Izinkan mulai otomatis',
                  detail: _hasAutostart
                      ? 'Cari HRIS COK di daftar, lalu nyalakan sakelarnya.'
                      : 'Bila ada pilihan "Mulai otomatis" atau "Autostart" di setelan aplikasi, nyalakan.',
                  ok: null,
                  button: _hasAutostart ? 'Buka mulai otomatis' : 'Buka setelan aplikasi',
                  onPressed: () => _call('openAutostart'),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.navySoft, borderRadius: BorderRadius.circular(14)),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 19, color: AppColors.navy),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Jangan "bersihkan" atau geser tutup aplikasi ini dari daftar aplikasi terbaru. '
                      'Di HP Xiaomi, Oppo dan Vivo, kunci aplikasinya di daftar itu (tekan lama, pilih ikon gembok).',
                      style: TextStyle(fontSize: 12.5, color: AppColors.chipText, height: 1.45),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.detail,
    required this.ok,
    required this.button,
    required this.onPressed,
  });

  final int number;
  final String title;
  final String detail;

  /// true = sudah benar, false = perlu diubah, null = HP tidak bisa memastikan.
  final bool? ok;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (ok) {
      true => ('Sudah', PillTone.success),
      false => ('Perlu diubah', PillTone.danger),
      null => ('Periksa', PillTone.neutral),
    };
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('$number. $title',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
          StatusPill(label: label, tone: tone),
        ]),
        const SizedBox(height: 6),
        Text(detail, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.45)),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onPressed, child: Text(button)),
      ]),
    );
  }
}
