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

/// Tab Profil: identitas, menu akun, dan keluar. Menu atasan ada di tab Tim.
class ProfilPage extends ConsumerWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final e = user.employee;
    final p = ref.watch(profileProvider).asData?.value;
    final isLeader = (p?['is_leader'] as bool?) ?? user.isLeader;
    // Foto terbaru dari /profile (berubah setelah ganti foto), cadangan dari sesi login.
    final photoUrl = p != null ? p['photo_url'] as String? : e.photoUrl;

    return DotScaffold(
      child: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () async => ref.invalidate(profileProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
          children: [
            const TabHeader(title: 'Profil', padding: EdgeInsets.only(top: 12)),
            const SizedBox(height: 16),
            NavyHeroCard(
              child: Row(children: [
                _ProfilePhoto(initials: user.initials, photoUrl: photoUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (e.jobPosition != null)
                      Text(e.jobPosition!, style: const TextStyle(fontSize: 13, color: Color(0xCCFFFFFF))),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (e.number != null) StatusPill(label: 'NIK ${e.number}', tone: PillTone.onPrimary),
                      if (e.branchName != null) StatusPill(label: e.branchName!, tone: PillTone.onPrimary),
                      if (isLeader) const StatusPill(label: 'Atasan', tone: PillTone.accent),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 22),
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
                  icon: Icons.inventory_2_outlined,
                  title: 'Aset saya',
                  subtitle: 'Barang kantor yang sedang kamu pegang',
                  onTap: () => context.push('/aset'),
                ),
                _MenuRow(
                  icon: Icons.account_tree_outlined,
                  title: 'Struktur organisasi',
                  subtitle: [e.department, e.managerName == null ? null : 'Atasan: ${e.managerName}'].whereType<String>().join(' · '),
                  onTap: () => context.push('/struktur'),
                ),
                if (isLeader)
                  _MenuRow(
                    icon: Icons.people_alt_outlined,
                    title: 'Rekan kerja',
                    subtitle: 'Cari rekan di seluruh kantor',
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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.navySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 19, color: AppColors.navy),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Absen masuk dan pulang dilakukan di tablet kantor atau mesin gudang. Saat WFH atau dinas luar, absen dengan selfie dari Beranda.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.chipText, height: 1.45),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: Color(0xFFFECDCA))),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Keluar dari aplikasi?'),
                    content: const Text('Kamu bisa masuk lagi kapan saja, dari HP mana saja.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
                    ],
                  ),
                );
                if (ok == true) await ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Keluar'),
            ),
            const SizedBox(height: 16),
            const Text('Cahaya Optima Karya · HRIS',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.faint)),
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
            decoration: BoxDecoration(color: AppColors.navySoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              if (subtitle?.isNotEmpty ?? false) Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: T2Colors.faint),
        ]),
      ),
    );
  }
}

/// Foto profil bulat + tombol kamera. Ketuk untuk ambil foto, pilih dari
/// galeri, atau hapus.
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
          width: 64,
          height: 64,
          child: Stack(clipBehavior: Clip.none, children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircleAvatar(
                backgroundColor: AppColors.accent,
                foregroundImage: photo != null ? NetworkImage(absoluteUrl(photo)!) : null,
                onForegroundImageError: photo != null ? (_, _) {} : null,
                child: Text(widget.initials,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.navy)),
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                  child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
                ),
              ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navy, width: 2),
                ),
                child: const Icon(Icons.photo_camera_outlined, color: AppColors.navy, size: 15),
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
    Widget option(String value, IconData icon, String title, String subtitle, {Color bg = AppColors.navySoft, Color fg = AppColors.navy, Color? text}) {
      return ListTile(
        minTileHeight: 60,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        onTap: () => Navigator.pop(context, value),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
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
            child: Text('Foto ini terlihat oleh rekan di daftar Rekan kerja dan Tim.',
                style: TextStyle(fontSize: 13, color: T2Colors.muted)),
          ),
          option('camera', Icons.photo_camera_outlined, 'Ambil foto', 'Pakai kamera depan'),
          option('gallery', Icons.photo_library_outlined, 'Pilih dari galeri', 'Foto ditampilkan bulat',
              bg: AppColors.infoSoft, fg: AppColors.info),
          if (hasPhoto)
            option('delete', Icons.delete_outline_rounded, 'Hapus foto', 'Kembali ke inisial nama',
                bg: AppColors.dangerSoft, fg: AppColors.danger, text: AppColors.danger),
        ]),
      ),
    );
  }
}
