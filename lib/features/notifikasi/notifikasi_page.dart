import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../aset/aset_page.dart';
import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('notifications');
  return asList(res['data']);
});

/// Jumlah belum dibaca, untuk badge lonceng di Beranda (dipakai tahap 1).
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final res = await ref.read(t2ApiProvider).get('notifications/unread-count');
  return (asMap(res['data'])['count'] as num? ?? 0).toInt();
});

({IconData icon, Color bg, Color fg}) _style(String? category) => switch (category) {
  'leave' || 'overtime' || 'swap' => (icon: Icons.description_outlined, bg: T2Colors.orangeSoft, fg: T2Colors.orangeText),
  'correction' || 'attendance' => (icon: Icons.fingerprint, bg: const Color(0xFFEDE9FE), fg: const Color(0xFF6D28D9)),
  'schedule' => (icon: Icons.calendar_month_outlined, bg: const Color(0xFFE0F2FE), fg: const Color(0xFF0369A1)),
  'asset' => (icon: Icons.inventory_2_outlined, bg: AppColors.accentSoft, fg: AppColors.accentText),
  'announcement' => (icon: Icons.campaign_outlined, bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309)),
  _ => (icon: Icons.notifications_none, bg: T2Colors.bg, fg: T2Colors.muted),
};

/// Tombol tindakan di rincian notifikasi: (label, rute). Null = tanpa tombol.
(String, String)? notificationAction(Map<String, dynamic> n) {
  final meta = asMap(n['meta']);
  final forApprover = meta['for'] == 'approver';
  return switch (n['category']) {
    'announcement' when meta['announcement_id'] != null => ('Baca pengumuman', '/pengumuman/${meta['announcement_id']}'),
    'schedule' => ('Buka jadwal saya', '/jadwal'),
    'leave' || 'overtime' when forApprover => ('Buka persetujuan', '/tim/persetujuan'),
    'leave' || 'overtime' || 'swap' => ('Lihat pengajuan saya', '/pengajuan/semua'),
    'correction' => ('Buka koreksi absen', '/koreksi'),
    'attendance' => ('Buka kehadiran', '/kehadiran'),
    'asset' => ('Lihat aset saya', '/aset'),
    _ => null,
  };
}

final _assignmentProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) async {
  final res = await ref.read(t2ApiProvider).get('assets/$id');
  return asMap(res['data']);
});

class NotifikasiPage extends ConsumerWidget {
  const NotifikasiPage({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Map<String, dynamic> n) async {
    if (n['read'] != true) {
      // Tandai dibaca di belakang layar; rinciannya langsung tampil.
      ref.read(t2ApiProvider).post('notifications/${n['id']}/read').then((_) {
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationCountProvider);
      }, onError: (_) {});
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => NotificationDetailSheet(notification: n),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);

    return DotScaffold(
      child: SafeArea(
        child: Column(
          children: [
            BackHeader(
              title: 'Notifikasi',
              trailing: TextButton(
                onPressed: () async {
                  await ref.read(t2ApiProvider).post('notifications/read-all');
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadNotificationCountProvider);
                },
                child: const Text(
                  'Baca semua',
                  style: TextStyle(color: T2Colors.orangeText, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncBody<List<Map<String, dynamic>>>(
                value: list,
                onRefresh: () async => ref.invalidate(notificationsProvider),
                builder: (items) {
                  if (items.isEmpty) return ListView(children: const [EmptyNote('Belum ada notifikasi.', icon: Icons.notifications_none)]);

                  final children = <Widget>[];
                  String? lastGroup;
                  for (final n in items) {
                    final d = parseDate(n['created_at']) ?? DateTime.now();
                    final now = DateTime.now();
                    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
                    final group = days == 0
                        ? 'HARI INI'
                        : days == 1
                        ? 'KEMARIN'
                        : 'SEBELUMNYA';
                    if (group != lastGroup) {
                      children.add(
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                          child: Text(
                            group,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: T2Colors.muted, letterSpacing: .6),
                          ),
                        ),
                      );
                      lastGroup = group;
                    }
                    final s = _style(n['category'] as String?);
                    children.add(
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: T2Card(
                          onTap: () => _open(context, ref, n),
                          color: n['read'] == true ? Colors.white : const Color(0xFFFFF8EE),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(14)),
                                child: Icon(s.icon, color: s.fg, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n['title'] as String? ?? '', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text(n['message'] as String? ?? '', style: const TextStyle(fontSize: 13, color: T2Colors.muted)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                days == 0 ? hm(d) : '${dayShort(d)} ${hm(d)}',
                                style: const TextStyle(fontSize: 12, color: T2Colors.faint),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView(padding: const EdgeInsets.only(bottom: 30), children: children);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rincian satu notifikasi, dengan tombol tindakan yang sesuai. Untuk
/// penyerahan aset yang belum dikonfirmasi, konfirmasinya bisa langsung di sini.
class NotificationDetailSheet extends ConsumerStatefulWidget {
  const NotificationDetailSheet({super.key, required this.notification});
  final Map<String, dynamic> notification;

  @override
  ConsumerState<NotificationDetailSheet> createState() => _NotificationDetailSheetState();
}

class _NotificationDetailSheetState extends ConsumerState<NotificationDetailSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final s = _style(n['category'] as String?);
    final d = parseDate(n['created_at']);
    final action = notificationAction(n);
    final assignmentId = (asMap(n['meta'])['assignment_id'] as num?)?.toInt();
    final assignment = assignmentId == null ? null : ref.watch(_assignmentProvider(assignmentId));
    final row = assignment?.asData?.value;
    final canAcknowledge = row != null && row['state'] == 'unacknowledged';

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(14)),
                    child: Icon(s.icon, color: s.fg, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      d == null ? '' : '${dayLong(d)}, ${d.day} ${monthLong(d)} ${d.year} · ${hm(d)}',
                      style: const TextStyle(fontSize: 12.5, color: T2Colors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(n['title'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
              const SizedBox(height: 8),
              Text(n['message'] as String? ?? '', style: const TextStyle(fontSize: 14.5, color: T2Colors.ink, height: 1.5)),
              if (row != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: T2Colors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: T2Colors.navy, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(asMap(row['asset'])['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(assetSubtitle(asMap(row['asset'])), style: const TextStyle(fontSize: 12.5, color: T2Colors.muted)),
                          ],
                        ),
                      ),
                      if (!canAcknowledge)
                        StatusChip(
                          row['state'] == 'returned' ? 'Dikembalikan' : 'Dikonfirmasi',
                          tone: row['state'] == 'returned' ? null : 'success',
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (canAcknowledge) ...[
                PrimaryButton(
                  label: 'Konfirmasi terima',
                  icon: Icons.check_rounded,
                  busy: _busy,
                  onPressed: () async {
                    setState(() => _busy = true);
                    final ok = await acknowledgeAsset(context, ref, assignmentId!);
                    if (!mounted) return;
                    setState(() => _busy = false);
                    if (ok) ref.invalidate(_assignmentProvider(assignmentId));
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: _busy
                      ? null
                      : () async {
                          final ok = await showAssetProblemSheet(context, ref, row);
                          if (ok && mounted) ref.invalidate(_assignmentProvider(assignmentId!));
                        },
                  child: const Text('Ada masalah'),
                ),
                const SizedBox(height: 8),
              ],
              if (action != null)
                canAcknowledge
                    ? TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push(action.$2);
                        },
                        child: Text(action.$1),
                      )
                    : PrimaryButton(
                        label: action.$1,
                        onPressed: () {
                          Navigator.pop(context);
                          context.push(action.$2);
                        },
                      ),
              if (assignment?.isLoading ?? false)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
