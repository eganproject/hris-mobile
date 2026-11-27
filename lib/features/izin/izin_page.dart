import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/push/push_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/t2_ui.dart';
import 'izin_setup.dart';

/// Alur izin: muncul sekali sesudah login pertama di HP ini, dan bisa dibuka
/// lagi dari Profil > Izin aplikasi. Tiap langkah: penjelasan singkat dulu,
/// baru dialog izin bawaan Android. Semua langkah boleh dilewati.
class IzinPage extends ConsumerStatefulWidget {
  const IzinPage({super.key});

  @override
  ConsumerState<IzinPage> createState() => _IzinPageState();
}

enum _Result { granted, opened, skipped }

class _IzinPageState extends ConsumerState<IzinPage> {
  IzinStatus? _status;
  List<IzinStep> _steps = const [];

  /// -1 = ringkasan, 0.._steps.length-1 = langkah, _steps.length = selesai.
  int _index = -1;
  bool _busy = false;
  final _results = <IzinStep, _Result>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await IzinStatus.read();
    if (!mounted) return;
    setState(() {
      _status = s;
      if (_steps.isEmpty) _steps = s.steps;
    });
  }

  Future<void> _allow() async {
    final step = _steps[_index];
    setState(() => _busy = true);
    await requestIzin(step);
    await _refresh();
    if (!mounted) return;
    final ok = _status?.granted(step);
    _results[step] = ok == true ? _Result.granted : (ok == null ? _Result.opened : _Result.skipped);
    setState(() {
      _busy = false;
      _index++;
    });
  }

  void _skip() {
    _results[_steps[_index]] = _Result.skipped;
    setState(() => _index++);
  }

  Future<void> _finish() async {
    await ref.read(izinSetupDoneProvider.notifier).markDone();
    // Izin notifikasi mungkin baru diberikan: daftarkan ulang HP ke server.
    ref.invalidate(pushRegistrarProvider);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return PopScope(
      canPop: context.canPop(),
      child: DotScaffold(
        child: status == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.navy))
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: _index < 0
                    ? _intro(status)
                    : _index >= _steps.length
                        ? _done(status)
                        : _step(_steps[_index]),
              ),
      ),
    );
  }

  // --- Ringkasan ------------------------------------------------------------

  Widget _intro(IzinStatus status) {
    final name = ref.watch(currentUserProvider)?.firstName;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.smartphone_rounded, color: AppColors.accent, size: 26),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Siapkan HP-mu dulu', style: _title),
          const SizedBox(height: 8),
          Text(
            '${name == null ? 'Halo' : 'Halo $name'}, supaya notifikasi absen selalu masuk dan semua fitur jalan, '
            'aplikasi butuh beberapa izin. Cukup sekali, ±1 menit.',
            style: _body,
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, s) in _steps.indexed)
                _Row(
                  icon: _meta[s]!.icon,
                  title: _meta[s]!.short,
                  subtitle: _meta[s]!.why,
                  pill: status.granted(s) == true
                      ? const StatusPill(label: 'Sudah', tone: PillTone.success)
                      : _meta[s]!.required
                          ? const StatusPill(label: 'Wajib', tone: PillTone.danger)
                          : const StatusPill(label: 'Bila perlu'),
                  last: i == _steps.length - 1,
                ),
            ]),
          ),
        ]),
      ),
      PrimaryButton(label: 'Mulai', onPressed: () => setState(() => _index = 0)),
      const SizedBox(height: 10),
      const Text('Bisa diatur ulang kapan saja di Profil > Izin aplikasi',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
    ]);
  }

  // --- Satu langkah ---------------------------------------------------------

  Widget _step(IzinStep step) {
    final m = _meta[step]!;
    final already = _status?.granted(step) == true;
    final opensSettings = step == IzinStep.otomatis || step == IzinStep.pembaruan;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('Langkah ${_index + 1} dari ${_steps.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const Spacer(),
        for (var i = 0; i < _steps.length; i++)
          Container(
            width: 28,
            height: 5,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: i <= _index ? AppColors.navy : AppColors.dot,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ]),
      const SizedBox(height: 18),
      Expanded(
        child: ListView(children: [
          _Hero(step: step),
          const SizedBox(height: 20),
          Text(m.title, style: _title.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text(m.body, style: _body),
          if (step == IzinStep.otomatis) ...[
            const SizedBox(height: 14),
            const _Numbered(n: 1, text: 'Tekan Buka setelan di bawah.'),
            const _Numbered(n: 2, text: 'Cari HRIS COK, nyalakan sakelarnya.'),
            const _Numbered(n: 3, text: 'Tekan tombol kembali. Aplikasi lanjut ke langkah berikutnya.'),
          ],
          if (already) ...[
            const SizedBox(height: 14),
            const Row(children: [
              Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
              SizedBox(width: 6),
              Text('Sudah diizinkan di HP ini', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
            ]),
          ],
        ]),
      ),
      PrimaryButton(
        label: already ? 'Lanjut' : (opensSettings ? 'Buka setelan' : 'Izinkan'),
        busy: _busy,
        onPressed: already
            ? () {
                _results[step] = _Result.granted;
                setState(() => _index++);
              }
            : _allow,
      ),
      if (!already)
        TextButton(
          onPressed: _busy ? null : _skip,
          child: Text(step == IzinStep.otomatis ? 'Sudah, lanjut' : 'Nanti saja',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted)),
        ),
    ]);
  }

  // --- Selesai --------------------------------------------------------------

  Widget _done(IzinStatus status) {
    final skipped = _steps.where((s) => status.granted(s) == false).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(children: [
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 34),
            ),
          ),
          const SizedBox(height: 16),
          const Text('HP-mu sudah siap', style: _title),
          const SizedBox(height: 8),
          Text(
            skipped == 0
                ? 'Notifikasi absen akan masuk walau aplikasi ditutup.'
                : '$skipped izin belum diberikan. Kamu bisa menyalakannya nanti dari Profil > Izin aplikasi.',
            style: _body,
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, s) in _steps.indexed)
                _Row(
                  title: _meta[s]!.short,
                  pill: switch (status.granted(s)) {
                    true => const StatusPill(label: 'Diizinkan', tone: PillTone.success),
                    false => const StatusPill(label: 'Dilewati', tone: PillTone.warning),
                    null => _results[s] == _Result.opened
                        ? const StatusPill(label: 'Sudah dibuka')
                        : const StatusPill(label: 'Dilewati', tone: PillTone.warning),
                  },
                  last: i == _steps.length - 1,
                ),
            ]),
          ),
        ]),
      ),
      PrimaryButton(label: context.canPop() ? 'Selesai' : 'Masuk ke Beranda', onPressed: _finish),
    ]);
  }
}

const _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.4);
const _body = TextStyle(fontSize: 14, height: 1.5, color: AppColors.chipText);

class _Meta {
  const _Meta(this.icon, this.short, this.why, this.title, this.body, {this.required = false});
  final IconData icon;
  final String short;
  final String why;
  final String title;
  final String body;
  final bool required;
}

const _meta = {
  IzinStep.notifikasi: _Meta(
    Icons.notifications_none_rounded,
    'Notifikasi',
    'Kabar saat absenmu tercatat',
    'Izinkan notifikasi',
    'Kamu akan dikabari setiap absen masuk atau pulang tercatat, juga saat pengajuan cuti atau lembur disetujui. '
        'Kalau ada absen yang bukan kamu, kamu tahu saat itu juga.',
    required: true,
  ),
  IzinStep.baterai: _Meta(
    Icons.battery_charging_full_rounded,
    'Baterai tanpa batasan',
    'Supaya notifikasi tidak tertahan',
    'Jangan batasi baterai aplikasi ini',
    'Penghemat baterai sering menghentikan aplikasi yang ditutup, sehingga notifikasinya tertahan. '
        'Aplikasi ini hampir tidak memakai baterai: ia hanya bangun sebentar saat ada notifikasi dari HRIS.',
    required: true,
  ),
  IzinStep.otomatis: _Meta(
    Icons.power_settings_new_rounded,
    'Mulai otomatis',
    'Khusus HP Xiaomi, Oppo, Vivo',
    'Nyalakan mulai otomatis',
    'HP-mu mematikan aplikasi yang tidak diizinkan mulai otomatis. Nyalakan untuk HRIS COK supaya notifikasi tetap masuk.',
    required: true,
  ),
  IzinStep.kamera: _Meta(
    Icons.photo_camera_outlined,
    'Kamera & lokasi',
    'Untuk absen selfie saat WFH',
    'Kamera dan lokasi',
    'Dipakai hanya saat kamu absen selfie ketika WFH atau dinas luar, dan saat melampirkan foto surat dokter. '
        'Lokasi tidak dilacak di luar saat absen.',
  ),
  IzinStep.pembaruan: _Meta(
    Icons.system_update_alt_rounded,
    'Pasang pembaruan',
    'Update aplikasi langsung dari HRIS',
    'Izinkan pasang pembaruan',
    'Saat ada versi baru, aplikasi mengunduh dan memasangnya sendiri dari HRIS, tanpa perlu mengirim file APK lewat WhatsApp. '
        'Nyalakan "Izinkan dari sumber ini", lalu tekan kembali.',
  ),
};

class _Row extends StatelessWidget {
  const _Row({this.icon, required this.title, this.subtitle, required this.pill, required this.last});
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget pill;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.navySoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        pill,
      ]),
    );
  }
}

class _Numbered extends StatelessWidget {
  const _Numbered({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.navySoft, shape: BoxShape.circle),
          child: Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.navy)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: _body)),
      ]),
    );
  }
}

/// Kartu navy di atas tiap langkah: contoh atau ilustrasi yang dijelaskan.
class _Hero extends StatelessWidget {
  const _Hero({required this.step});
  final IzinStep step;

  @override
  Widget build(BuildContext context) {
    final child = switch (step) {
      IzinStep.notifikasi => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Absen masuk tercatat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  Text('Pukul 07:58 di Tablet Kantor Pusat. Bukan Anda? Segera hubungi HR.',
                      style: TextStyle(fontSize: 12, color: AppColors.chipText)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          const Text('Contoh notifikasi yang akan kamu terima', style: TextStyle(fontSize: 12, color: Color(0xFFC7CEE3))),
        ]),
      IzinStep.otomatis || IzinStep.pembaruan => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(step == IzinStep.otomatis ? 'Contoh halaman mulai otomatis' : 'Halaman Android yang akan terbuka',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFC7CEE3))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(step == IzinStep.otomatis ? 'HRIS COK' : 'Izinkan dari sumber ini',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              const Switch(value: true, onChanged: null),
            ]),
          ),
        ]),
      IzinStep.baterai => const Row(children: [
          Icon(Icons.battery_charging_full_rounded, size: 56, color: AppColors.accent),
          SizedBox(width: 14),
          Expanded(
            child: Text('Penghemat baterai sering menghentikan aplikasi yang ditutup. Notifikasinya jadi tertahan.',
                style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFE4E8F3))),
          ),
        ]),
      IzinStep.kamera => const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.photo_camera_outlined, size: 52, color: AppColors.accent),
          SizedBox(width: 22),
          Icon(Icons.location_on_outlined, size: 52, color: AppColors.accent),
        ]),
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }
}
