import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../t2_common/t2_api.dart';
import '../t2_common/t2_ui.dart';
import 'rekan_providers.dart';

/// Rekan kerja: tab Online / Offline + cari nama, jabatan, atau divisi.
class RekanPage extends ConsumerStatefulWidget {
  const RekanPage({super.key});

  @override
  ConsumerState<RekanPage> createState() => _RekanPageState();
}

class _RekanPageState extends ConsumerState<RekanPage> {
  String _status = 'online';
  String _q = '';
  Timer? _debounce;
  List<Map<String, dynamic>> _people = [];
  int _online = 0;
  int _offline = 0;
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_request;
    setState(() {
      _loading = _people.isEmpty;
      _error = null;
    });
    try {
      final res = await ref.read(t2ApiProvider).get('people', query: {'status': _status, if (_q.isNotEmpty) 'q': _q});
      if (id != _request || !mounted) return;
      final meta = asMap(res['meta']);
      setState(() {
        _people = asList(res['data']);
        _online = (meta['online_count'] as num?)?.toInt() ?? 0;
        _offline = (meta['offline_count'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      if (id == _request && mounted) setState(() => _error = t2Error(e));
    } finally {
      if (id == _request && mounted) setState(() => _loading = false);
    }
  }

  void _setStatus(String s) {
    if (s == _status) return;
    setState(() {
      _status = s;
      _people = [];
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: MaxWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const BackHeader(title: 'Rekan kerja'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    _q = v.trim();
                    _load();
                  });
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari nama, jabatan, atau divisi',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFFE6E9EF), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  _Seg('Online ($_online)', _status == 'online', () => _setStatus('online')),
                  _Seg('Offline ($_offline)', _status == 'offline', () => _setStatus('offline')),
                ]),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: T2Colors.orange,
                onRefresh: _load,
                child: _loading
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: T2Colors.orange)))])
                    : _error != null && _people.isEmpty
                        ? ListView(children: [
                            EmptyNote(_error!, icon: Icons.wifi_off_rounded),
                            Center(child: TextButton(onPressed: _load, child: const Text('Coba lagi'))),
                          ])
                        : _people.isEmpty
                            ? ListView(children: [
                                EmptyNote(
                                  _q.isNotEmpty ? 'Tidak ada yang cocok dengan "$_q".' : (_status == 'online' ? 'Belum ada rekan yang online.' : 'Semua rekan sedang online.'),
                                  icon: Icons.groups_2_outlined,
                                ),
                              ])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                itemCount: _people.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (_, i) => PersonTile(person: _people[i]),
                              ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 42),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                boxShadow: selected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))] : null,
              ),
              child: Text(label,
                  style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w700, fontSize: 14, color: selected ? T2Colors.ink : T2Colors.muted)),
            ),
          ),
        ),
      );
}

/// Satu baris rekan: foto + titik status, nama, jabatan, keterangan online.
class PersonTile extends StatelessWidget {
  const PersonTile({super.key, required this.person});
  final Map<String, dynamic> person;

  @override
  Widget build(BuildContext context) {
    final online = person['online'] == true;
    final sub = [person['job_title'], person['department']].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return T2Card(
      onTap: () => context.push('/rekan/${person['id']}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        PersonAvatar(person: person, size: 46, online: online),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(person['name'] as String? ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: T2Colors.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 84),
          child: Text(
            lastSeenLabel(person),
            textAlign: TextAlign.end,
            maxLines: 2,
            style: TextStyle(fontSize: 12, fontWeight: online ? FontWeight.w800 : FontWeight.w500, color: online ? const Color(0xFF15803D) : T2Colors.faint),
          ),
        ),
      ]),
    );
  }
}
