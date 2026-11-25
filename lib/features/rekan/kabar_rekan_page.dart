import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../kabar/kabar_widgets.dart';
import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_ui.dart';

final _authorPostsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, id) async {
  final res = await ref.read(t2ApiProvider).get('kabar', query: {'author': id});
  return asList(asMap(res['data'])['posts']);
});

/// Kabar yang ditulis seorang rekan (yang memang boleh Anda lihat).
class KabarRekanPage extends ConsumerWidget {
  const KabarRekanPage({super.key, required this.id, this.name});
  final int id;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(_authorPostsProvider(id));
    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: MaxWidth(
          child: Column(children: [
            BackHeader(title: name == null || name!.isEmpty ? 'Kabar' : 'Kabar dari $name'),
            const SizedBox(height: 12),
            Expanded(
              child: AsyncBody<List<Map<String, dynamic>>>(
                value: value,
                onRefresh: () async => ref.invalidate(_authorPostsProvider(id)),
                builder: (posts) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
                  if (posts.isEmpty) const EmptyNote('Belum ada kabar yang ditulis.', icon: Icons.forum_outlined),
                  for (final p in posts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PostCard(key: ValueKey('post-${p['id']}'), post: p, onChanged: () => ref.invalidate(_authorPostsProvider(id))),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
