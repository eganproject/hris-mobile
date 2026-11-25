import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      'announcement' => (icon: Icons.campaign_outlined, bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309)),
      'kabar' => (icon: Icons.chat_bubble_outline, bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D)),
      _ => (icon: Icons.notifications_none, bg: T2Colors.bg, fg: T2Colors.muted),
    };

/// Layar tujuan aplikasi untuk sebuah notifikasi (null = tetap di sini).
String? notificationRoute(Map<String, dynamic> n) {
  final meta = asMap(n['meta']);
  return switch (n['category']) {
    'announcement' when meta['announcement_id'] != null => '/kabar/pengumuman/${meta['announcement_id']}',
    'kabar' when meta['post_id'] != null => '/kabar/post/${meta['post_id']}',
    'schedule' => '/jadwal',
    'leave' || 'overtime' || 'swap' => '/pengajuan/semua',
    'correction' => '/koreksi',
    _ => null,
  };
}

class NotifikasiPage extends ConsumerWidget {
  const NotifikasiPage({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Map<String, dynamic> n) async {
    if (n['read'] != true) {
      try {
        await ref.read(t2ApiProvider).post('notifications/${n['id']}/read');
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationCountProvider);
      } catch (_) {}
    }
    final route = notificationRoute(n);
    if (route != null && context.mounted) context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: Column(children: [
          BackHeader(
            title: 'Notifikasi',
            trailing: TextButton(
              onPressed: () async {
                await ref.read(t2ApiProvider).post('notifications/read-all');
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationCountProvider);
              },
              child: const Text('Tandai semua dibaca', style: TextStyle(color: T2Colors.orangeText, fontWeight: FontWeight.w700)),
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
                  final group = days == 0 ? 'HARI INI' : days == 1 ? 'KEMARIN' : 'SEBELUMNYA';
                  if (group != lastGroup) {
                    children.add(Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                      child: Text(group, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: T2Colors.muted, letterSpacing: .6)),
                    ));
                    lastGroup = group;
                  }
                  final s = _style(n['category'] as String?);
                  children.add(Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: T2Card(
                      onTap: () => _open(context, ref, n),
                      color: n['read'] == true ? Colors.white : const Color(0xFFFFF8EE),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(14)), child: Icon(s.icon, color: s.fg, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n['title'] as String? ?? '', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(n['message'] as String? ?? '', style: const TextStyle(fontSize: 13, color: T2Colors.muted)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Text(days == 0 ? hm(d) : '${dayShort(d)} ${hm(d)}', style: const TextStyle(fontSize: 12, color: T2Colors.faint)),
                      ]),
                    ),
                  ));
                }
                return ListView(padding: const EdgeInsets.only(bottom: 30), children: children);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
