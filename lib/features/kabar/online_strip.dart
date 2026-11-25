import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../rekan/rekan_providers.dart';
import '../t2_common/t2_ui.dart';

/// Kartu "Sedang online · N" di atas Kabar: foto rekan yang online bisa digeser,
/// diketuk membuka profil publiknya; "Lihat semua" membuka daftar rekan kerja.
class OnlineStrip extends ConsumerWidget {
  const OnlineStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(onlinePeopleProvider).asData?.value;
    final people = data?.people ?? const <Map<String, dynamic>>[];
    final count = data?.count ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: T2Card(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(children: [
              Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(data == null ? 'Sedang online' : 'Sedang online · $count',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              TextButton(
                onPressed: () => context.push('/rekan'),
                style: TextButton.styleFrom(foregroundColor: T2Colors.orangeText, minimumSize: const Size(44, 44)),
                child: const Text('Lihat semua', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          SizedBox(
            height: 78,
            child: data != null && people.isEmpty
                ? const Center(child: Text('Belum ada rekan yang online.', style: TextStyle(color: T2Colors.muted)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: data == null ? 5 : people.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      if (data == null) {
                        return Column(children: [
                          Container(width: 52, height: 52, decoration: const BoxDecoration(color: T2Colors.line, shape: BoxShape.circle)),
                        ]);
                      }
                      final p = people[i];
                      final first = (p['name'] as String? ?? '-').split(' ').first;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => context.push('/rekan/${p['id']}'),
                        child: SizedBox(
                          width: 60,
                          child: Column(children: [
                            PersonAvatar(person: p, size: 52, online: true),
                            const SizedBox(height: 6),
                            Text(first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
