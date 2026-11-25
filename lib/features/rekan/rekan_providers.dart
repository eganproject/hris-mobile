import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../t2_common/t2_api.dart';

/// Rekan yang sedang online (untuk baris di atas Kabar). meta.online_count = total.
final onlinePeopleProvider = FutureProvider.autoDispose<({List<Map<String, dynamic>> people, int count})>((ref) async {
  final res = await ref.read(t2ApiProvider).get('people', query: {'status': 'online', 'limit': 30});
  return (people: asList(res['data']), count: (asMap(res['meta'])['online_count'] as num?)?.toInt() ?? 0);
});

/// Id karyawan yang sedang online, untuk titik hijau di kartu kabar.
final onlineIdsProvider = Provider.autoDispose<Set<int>>((ref) {
  final people = ref.watch(onlinePeopleProvider).asData?.value.people ?? const [];
  return {for (final p in people) (p['id'] as num).toInt()};
});

/// Profil publik seorang rekan.
final personProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) async {
  final res = await ref.read(t2ApiProvider).get('people/$id');
  return asMap(res['data']);
});

/// "Aktif 2 jam lalu" untuk rekan yang offline.
String lastSeenLabel(Map<String, dynamic> p) {
  if (p['online'] == true) return 'Online';
  final raw = p['last_seen_at'];
  final d = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
  if (d == null) return 'Belum pernah aktif';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return 'Aktif ${diff.inMinutes.clamp(1, 59)} mnt lalu';
  if (diff.inHours < 24) return 'Aktif ${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'Aktif kemarin';
  if (diff.inDays < 30) return 'Aktif ${diff.inDays} hari lalu';
  return 'Lama tidak aktif';
}
