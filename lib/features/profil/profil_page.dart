import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_ui.dart';
import 'profil_providers.dart';

/// Tab Profil: identitas, menu akun,
/// HP absen terdaftar, dan keluar. Menu atasan ada di Beranda (LeaderPanel).
class ProfilPage extends ConsumerWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final e = user.employee;
    // Foto terbaru dari /profile (berubah setelah ganti foto), cadangan dari sesi login.
    final profile = ref.watch(profileProvider).asData?.value;
    final photoUrl = profile != null ? profile['photo_url'] as String? : e.photoUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(profileProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(children: [
              const GradientHeaderBackground(height: 210),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(children: [
                    _ProfilePhoto(initials: user.initials, photoUrl: photoUrl),
                    const SizedBox(height: 12),
                    Text(e.fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      [e.jobPosition, if (e.number != null) 'NIK ${e.number}'].whereType<String>().join(' · '),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(height: 22),
                  ]),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const _GroupLabel('AKUN'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    _MenuRow(
                      icon: Icons.badge_outlined,
                      title: 'Data diri',
                      subtitle: 'Telepon, alamat, motto',
                      onTap: () => context.push('/profil/data-diri'),
                    ),
                    _MenuRow(
                      icon: Icons.account_tree_outlined,
                      title: 'Struktur organisasi',
                      subtitle: 'Atasan langsung dan tim di bawah Anda',
                      onTap: () => context.push('/struktur'),
                    ),
                    _MenuRow(
                      icon: Icons.event_note_outlined,
                      title: 'Jadwal saya',
                      subtitle: 'Shift minggu ini dan konfirmasi',
                      onTap: () => context.push('/jadwal'),
                    ),
                    _MenuRow(
                      icon: Icons.groups_2_outlined,
                      title: 'Rekan kerja',
                      subtitle: 'Siapa yang online, profil rekan',
                      onTap: () => context.push('/rekan'),
                    ),
                    _MenuRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifikasi',
                      onTap: () => context.push('/notifikasi'),
                      last: true,
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                const _GroupLabel('HP ABSEN'),
                AppCard(
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.smartphone, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('HP absen terdaftar', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                        Text(user.device?.model ?? 'HP ini', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ganti HP: cukup masuk dari HP baru, lalu tunggu persetujuan HR.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Keluar dari aplikasi?'),
                        content: const Text('Absen yang masih antre (belum terkirim) tetap tersimpan di HP ini.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
                        ],
                      ),
                    );
                    if (ok == true) await ref.read(authControllerProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Keluar'),
                ),
                const SizedBox(height: 16),
                const Text('Cahaya Optima Karya · HRIS',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.faint)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.faint)),
      );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.title, this.subtitle, required this.onTap, this.last = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: AppColors.primaryDark, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: T2Colors.faint),
        ]),
      ),
    );
  }
}

/// Foto profil bulat + tombol kamera. Ketuk untuk ambil foto, pilih dari
/// galeri, atau hapus. Foto ini terpisah dari selfie absen.
class _ProfilePhoto extends ConsumerStatefulWidget {
  const _ProfilePhoto({required this.initials, required this.photoUrl});
  final String initials;
  final String? photoUrl;

  @override
  ConsumerState<_ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends ConsumerState<_ProfilePhoto> {
  bool _busy = false;

  Future<void> _change() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _PhotoSheet(hasPhoto: widget.photoUrl != null),
    );
    if (action == null || !mounted) return;

    try {
      if (action == 'delete') {
        setState(() => _busy = true);
        final res = await ref.read(t2ApiProvider).delete('profile/photo');
        await _done(res['message'] as String? ?? 'Foto profil dihapus.');
        return;
      }
      final img = await ImagePicker().pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (img == null || !mounted) return;
      setState(() => _busy = true);
      final name = img.name.contains('.') ? img.name : '${img.name}.jpg';
      final form = FormData.fromMap({'photo': MultipartFile.fromBytes(await img.readAsBytes(), filename: name)});
      final res = await ref.read(t2ApiProvider).post('profile/photo', data: form);
      await _done(res['message'] as String? ?? 'Foto profil diperbarui.');
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _done(String message) async {
    ref.invalidate(profileProvider);
    try {
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } catch (_) {
      // Foto sudah tersimpan; data sesi akan ikut segar saat aplikasi dibuka lagi.
    }
    if (mounted) showSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photoUrl;
    return Semantics(
      button: true,
      label: 'Ganti foto profil',
      child: GestureDetector(
        onTap: _busy ? null : _change,
        child: SizedBox(
          width: 92,
          height: 92,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                foregroundImage: photo != null ? NetworkImage(photo) : null,
                onForegroundImageError: photo != null ? (_, _) {} : null,
                child: Text(widget.initials,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                  child: const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
                ),
              ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: T2Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryDark, width: 3),
                ),
                child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({required this.hasPhoto});
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    Widget option(String value, IconData icon, String title, String subtitle, {Color bg = T2Colors.orangeSoft, Color fg = T2Colors.orangeText, Color? text}) {
      return ListTile(
        minTileHeight: 60,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        onTap: () => Navigator.pop(context, value),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: fg, size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: text)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Ganti foto profil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Foto ini terlihat oleh semua rekan di Kabar dan di profil Anda.',
                style: TextStyle(fontSize: 13, color: T2Colors.muted)),
          ),
          option('camera', Icons.photo_camera_outlined, 'Ambil foto', 'Pakai kamera depan'),
          option('gallery', Icons.photo_library_outlined, 'Pilih dari galeri', 'Foto ditampilkan bulat',
              bg: const Color(0xFFE8ECF7), fg: T2Colors.navy),
          if (hasPhoto)
            option('delete', Icons.delete_outline_rounded, 'Hapus foto', 'Kembali ke inisial nama',
                bg: const Color(0xFFFDECEA), fg: const Color(0xFFB42318), text: const Color(0xFFB42318)),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: T2Colors.bg, borderRadius: BorderRadius.circular(14)),
            child: const Text('Foto profil terpisah dari selfie absen. Selfie absen tetap hanya terlihat oleh HR.',
                style: TextStyle(fontSize: 12.5, color: T2Colors.muted, height: 1.4)),
          ),
        ]),
      ),
    );
  }
}
