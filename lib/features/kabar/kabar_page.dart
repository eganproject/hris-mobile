import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../t2_common/t2_api.dart';
import '../t2_common/t2_ui.dart';
import 'kabar_widgets.dart';

/// Tab Kabar: pengumuman HR di atas, lalu postingan rekan (semua / divisi saya).
class KabarPage extends ConsumerStatefulWidget {
  const KabarPage({super.key});

  @override
  ConsumerState<KabarPage> createState() => _KabarPageState();
}

class _KabarPageState extends ConsumerState<KabarPage> {
  String _filter = 'semua';
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _posts = [];
  int _unread = 0;
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _more();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_posts.isEmpty) _loading = true;
    });
    try {
      final res = await ref.read(t2ApiProvider).get('kabar', query: {'filter': _filter, 'page': 1});
      final d = asMap(res['data']);
      final meta = asMap(res['meta']);
      setState(() {
        _announcements = asList(d['announcements']);
        _unread = (d['unread_announcements'] as num?)?.toInt() ?? 0;
        _posts = asList(d['posts']);
        _page = 1;
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
      });
    } catch (e) {
      setState(() => _error = t2Error(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _more() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(t2ApiProvider).get('kabar', query: {'filter': _filter, 'page': _page + 1});
      final d = asMap(res['data']);
      setState(() {
        _posts = [..._posts, ...asList(d['posts'])];
        _page++;
      });
    } catch (_) {
      // Diam saja: pengguna bisa menggulir lagi untuk mencoba.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setFilter(String f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _posts = [];
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T2Colors.bg,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton(
          backgroundColor: T2Colors.orange,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: () async {
            final posted = await context.push<bool>('/kabar/tulis');
            if (posted == true) _load();
          },
          child: const Icon(Icons.edit_outlined),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: T2Colors.orange,
          onRefresh: _load,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 140),
            children: [
              const PageTitle('Kabar'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _FilterChip('Semua', _filter == 'semua', () => _setFilter('semua')),
                  const SizedBox(width: 8),
                  _FilterChip('Divisi saya', _filter == 'divisi', () => _setFilter('divisi')),
                ]),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: T2Colors.orange)))
              else if (_error != null && _posts.isEmpty && _announcements.isEmpty) ...[
                EmptyNote(_error!, icon: Icons.wifi_off_rounded),
                Center(child: TextButton(onPressed: _load, child: const Text('Coba lagi'))),
              ] else ...[
                if (_announcements.isNotEmpty) ...[
                  SectionLabel(
                    _unread > 0 ? 'Pengumuman HR · $_unread baru' : 'Pengumuman HR',
                    action: 'Lihat semua',
                    onAction: () async {
                      await context.push('/kabar/pengumuman');
                      _load();
                    },
                  ),
                  const SizedBox(height: 10),
                  for (final a in _announcements.take(3))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: AnnouncementCard(item: a, onReturn: _load),
                    ),
                  const SizedBox(height: 8),
                ],
                const SectionLabel('Dari rekan kerja'),
                const SizedBox(height: 10),
                if (_posts.isEmpty) const EmptyNote('Belum ada postingan. Jadilah yang pertama berbagi kabar!', icon: Icons.forum_outlined),
                for (final p in _posts)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: PostCard(key: ValueKey('post-${p['id']}'), post: p, onChanged: _load),
                  ),
                if (_loadingMore) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: T2Colors.orange))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(color: selected ? T2Colors.navy : Colors.white, borderRadius: BorderRadius.circular(99)),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : T2Colors.ink)),
        ),
      );
}
