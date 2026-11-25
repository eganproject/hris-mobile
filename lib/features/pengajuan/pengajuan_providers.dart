import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../t2_common/t2_api.dart';

final pengajuanSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('pengajuan/ringkasan');
  return asMap(res['data']);
});

/// type: null (semua) | cuti | izin | sakit | lembur | tukar | koreksi
final pengajuanListProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, type) async {
  final res = await ref.read(t2ApiProvider).get('pengajuan', query: {'type': ?type});
  return asList(res['data']);
});

final leaveTypesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('leave-types');
  return asList(res['data']);
});

final colleaguesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(t2ApiProvider).get('swaps/colleagues');
});

/// Segarkan semua daftar pengajuan setelah ada perubahan.
void refreshPengajuan(WidgetRef ref) {
  ref.invalidate(pengajuanSummaryProvider);
  ref.invalidate(pengajuanListProvider);
}
