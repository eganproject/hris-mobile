import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../t2_common/t2_api.dart';

/// GET /profile: data diri + ringkasan menu atasan (badge persetujuan, ukuran tim).
final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('profile');
  return asMap(res['data']);
});
