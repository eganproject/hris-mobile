import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';
import 'kabar_widgets.dart';

final postDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) async {
  final res = await ref.read(t2ApiProvider).get('posts/$id');
  return asMap(res['data']);
});

/// Postingan + komentar berutas (satu tingkat balasan, seperti Threads/X).
class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  Map<String, dynamic>? _replyTo;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(postDetailProvider(widget.id));

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(t2ApiProvider).post('posts/${widget.id}/comments', data: {
        'body': body,
        if (_replyTo != null) 'parent_id': _replyTo!['id'],
      });
      _input.clear();
      setState(() => _replyTo = null);
      _focus.unfocus();
      _refresh();
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _reply(Map<String, dynamic> comment) {
    setState(() => _replyTo = comment);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(postDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: Column(children: [
          const BackHeader(title: 'Kabar'),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncBody<Map<String, dynamic>>(
              value: value,
              onRefresh: () async => _refresh(),
              builder: (p) {
                final comments = asList(p['comments']);
                return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
                  PostCard(post: p, inDetail: true),
                  const SizedBox(height: 16),
                  Text('Komentar (${p['comments_count'] ?? comments.length})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 10),
                  if (comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('Belum ada komentar.', textAlign: TextAlign.center, style: TextStyle(color: T2Colors.muted)),
                    ),
                  for (final c in comments) ...[
                    _CommentTile(comment: c, onReply: () => _reply(c), onChanged: _refresh),
                    for (final r in asList(c['replies']))
                      Padding(
                        padding: const EdgeInsets.only(left: 44),
                        child: _CommentTile(comment: r, onReply: () => _reply(c), onChanged: _refresh, small: true),
                      ),
                  ],
                ]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 10, 10),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x14111C45), blurRadius: 20, offset: Offset(0, -4))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_replyTo != null)
                Row(children: [
                  Expanded(
                    child: Text('Membalas ${asMap(_replyTo!['author'])['name']}',
                        style: const TextStyle(fontSize: 12.5, color: T2Colors.muted, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _replyTo = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ]),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: t2Input(_replyTo == null ? 'Tulis komentar…' : 'Tulis balasan…').copyWith(counterText: ''),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  style: IconButton.styleFrom(backgroundColor: T2Colors.orange),
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({required this.comment, required this.onReply, required this.onChanged, this.small = false});
  final Map<String, dynamic> comment;
  final VoidCallback onReply;
  final VoidCallback onChanged;
  final bool small;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  late bool _liked = widget.comment['liked'] == true;
  late int _likes = (widget.comment['likes_count'] as num?)?.toInt() ?? 0;

  Future<void> _like() async {
    try {
      final res = await ref.read(t2ApiProvider).post('comments/${widget.comment['id']}/like');
      final d = asMap(res['data']);
      setState(() {
        _liked = d['liked'] == true;
        _likes = (d['likes_count'] as num?)?.toInt() ?? _likes;
      });
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final author = asMap(c['author']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PersonAvatar(person: author, size: widget.small ? 30 : 36),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(author['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(c['body'] as String? ?? '', style: const TextStyle(fontSize: 14, height: 1.4)),
                  ]),
                ),
                SizedBox(
                  height: 28,
                  child: PostMenu(
                    size: 18,
                    isMine: c['is_mine'] == true,
                    onDelete: () async {
                      await ref.read(t2ApiProvider).delete('comments/${c['id']}');
                      widget.onChanged();
                    },
                    onReport: (reason) => ref.read(t2ApiProvider).post('comments/${c['id']}/report', data: {'reason': reason}),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Row(children: [
                Text(relativeTime(c['created_at']), style: const TextStyle(fontSize: 12, color: T2Colors.faint)),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: _like,
                  child: Text(
                    _likes > 0 ? 'Suka · $_likes' : 'Suka',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _liked ? const Color(0xFFE11D48) : T2Colors.muted),
                  ),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: widget.onReply,
                  child: const Text('Balas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: T2Colors.muted)),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
