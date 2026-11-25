import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/company_logo.dart';
import '../../core/widgets/ui.dart';
import '../absen/device_checks.dart';

/// "Jadikan HP ini HP absenmu": cek keamanan HP + persetujuan penyimpanan
/// selfie & lokasi (UU PDP). Muncul sekali per HP setelah login pertama.
class DaftarHpPage extends ConsumerStatefulWidget {
  const DaftarHpPage({super.key});

  @override
  ConsumerState<DaftarHpPage> createState() => _DaftarHpPageState();
}

class _DaftarHpPageState extends ConsumerState<DaftarHpPage> {
  bool _agree = false;
  bool _saving = false;
  bool? _rooted;

  @override
  void initState() {
    super.initState();
    DeviceChecks.isRooted().then((v) {
      if (mounted) setState(() => _rooted = v);
    });
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).giveConsent();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showPolicy() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: SingleChildScrollView(
          child: Text(
            'Saat kamu absen lewat aplikasi, Cahaya Optima Karya menyimpan foto selfie, titik lokasi (GPS), '
            'nama Wi-Fi yang tersambung, dan informasi HP (model, versi sistem). Data ini dipakai hanya untuk '
            'mencatat dan memeriksa kehadiran, dapat dilihat oleh kamu dan petugas HR yang berwenang, dan '
            'foto selfie dihapus otomatis setelah masa simpan berakhir. Aplikasi tidak melacak lokasimu di luar '
            'saat menekan tombol absen. Kamu dapat meminta penjelasan atau koreksi data ke HR.',
            style: TextStyle(height: 1.6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final rooted = _rooted;
    return Scaffold(
      body: Stack(children: [
        const GradientHeaderBackground(height: 300, radius: 44),
        SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), children: [
            const Row(children: [
              CompanyLogo(size: 44),
              SizedBox(width: 10),
              Text('Cahaya Optima Karya', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 24),
            const Text('Jadikan HP ini HP absenmu',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 8),
            const Text('Satu akun, satu HP. Kalau nanti ganti HP, cukup minta persetujuan HR.',
                style: TextStyle(color: Color(0xE0FFFFFF), height: 1.5)),
            const SizedBox(height: 26),
            AppCard(
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.smartphone, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.device?.model ?? 'HP ini', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(user?.employee.fullName ?? '', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ]),
                ),
                if (rooted == null)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  StatusPill(
                    label: rooted ? 'HP di-root' : 'Lolos cek',
                    tone: rooted ? PillTone.danger : PillTone.success,
                    icon: rooted ? Icons.close : Icons.check,
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CheckboxListTile(
                  value: _agree,
                  onChanged: (v) => setState(() => _agree = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.primary,
                  title: const Text(
                    'Saya setuju foto selfie dan lokasi saat absen disimpan untuk keperluan absensi.',
                    style: TextStyle(fontSize: 14, height: 1.45),
                  ),
                ),
                TextButton(onPressed: _showPolicy, child: const Text('Baca selengkapnya')),
              ]),
            ),
            if (rooted == true) ...[
              const SizedBox(height: 12),
              const Text('HP yang di-root/jailbreak tidak bisa dipakai untuk absen. Gunakan HP lain atau mesin absen.',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _agree && !_saving ? _submit : null,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Daftarkan HP ini'),
            ),
            TextButton(
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              child: const Text('Bukan akun saya, keluar'),
            ),
          ]),
        ),
      ]),
    );
  }
}
