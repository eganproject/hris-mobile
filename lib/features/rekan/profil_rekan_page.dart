import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/ui.dart';
import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';
import 'rekan_providers.dart';

/// Profil PUBLIK rekan: foto, nama, jabatan, status online, motto, divisi,
/// lokasi kerja, atasan langsung, bulan bergabung. Data pribadi tidak dikirim
/// server sama sekali, jadi tidak mungkin tampil di sini.
class ProfilRekanPage extends ConsumerWidget {
  const ProfilRekanPage({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(personProvider(id));
    final top = MediaQuery.paddingOf(context).top;

    final body = AsyncBody<Map<String, dynamic>>(
        value: value,
        onRefresh: () async => ref.invalidate(personProvider(id)),
        builder: (p) {
          final online = p['online'] == true;
          final first = (p['name'] as String? ?? '').split(' ').first;
          final depts = (p['departments'] is List ? List<String>.from(p['departments'] as List) : <String>[]);
          final rows = <(IconData, String, String)>[
            if (depts.isNotEmpty || p['department'] is String) (Icons.groups_2_outlined, 'Divisi', depts.isNotEmpty ? depts.join(', ') : p['department'] as String),
            if (p['branch'] is String) (Icons.place_outlined, 'Lokasi kerja', p['branch'] as String),
            if (p['manager'] is Map) (Icons.account_tree_outlined, 'Atasan langsung', asMap(p['manager'])['name'] as String? ?? '-'),
            if (p['joined'] is String) (Icons.event_available_outlined, 'Bergabung sejak', _joined(p['joined'] as String)),
          ];

          return ListView(padding: EdgeInsets.zero, children: [
            Stack(children: [
              GradientHeaderBackground(height: 250 + top),
              SafeArea(
                bottom: false,
                child: Column(children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: IconButton(
                        tooltip: 'Kembali',
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                  PersonAvatar(person: p, size: 96, online: online, ringColor: T2Colors.navy),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(p['name'] as String? ?? '-',
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  if (p['job_title'] is String)
                    Text(p['job_title'] as String, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .9))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: online ? const Color(0x3316A34A) : Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(online ? 'Online sekarang' : lastSeenLabel(p),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: online ? const Color(0xFFBBF7D0) : Colors.white)),
                  ),
                  const SizedBox(height: 30),
                ]),
              ),
            ]),
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if ((p['motto'] as String?)?.trim().isNotEmpty == true) ...[
                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: T2Card(
                        padding: const EdgeInsets.all(16),
                        child: Text('“${(p['motto'] as String).trim()}”',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, height: 1.45, color: Color(0xFF3B4458))),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 14),
                  if (rows.isNotEmpty)
                    T2Card(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(children: [
                        for (var i = 0; i < rows.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: T2Colors.line))),
                            child: Row(children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(color: T2Colors.orangeSoft, borderRadius: BorderRadius.circular(12)),
                                child: Icon(rows[i].$1, size: 19, color: T2Colors.orangeText),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(rows[i].$2, style: const TextStyle(fontSize: 12, color: T2Colors.muted)),
                                  Text(rows[i].$3, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ]),
                          ),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFEEF1F6), borderRadius: BorderRadius.circular(14)),
                    child: const Row(children: [
                      Icon(Icons.lock_outline_rounded, size: 18, color: T2Colors.muted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Nomor HP, alamat, email, NIK, dan data pribadi lain tidak ditampilkan.',
                            style: TextStyle(fontSize: 12.5, color: T2Colors.muted, height: 1.4)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: T2Colors.orange, shape: const StadiumBorder()),
                      onPressed: () => context.push('/rekan/$id/kabar?name=${Uri.encodeComponent(first)}'),
                      child: Text('Lihat kabar dari $first', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ]),
              ),
            ),
          ]);
        },
      );

    return Scaffold(
      backgroundColor: T2Colors.bg,
      // Selagi memuat / gagal, tetap ada tombol kembali.
      body: value.hasValue
          ? body
          : SafeArea(child: Column(children: [const BackHeader(title: 'Profil'), Expanded(child: body)])),
    );
  }

  static String _joined(String ym) {
    final d = DateTime.tryParse('$ym-01');
    return d == null ? ym : '${monthLong(d)} ${d.year}';
  }
}
