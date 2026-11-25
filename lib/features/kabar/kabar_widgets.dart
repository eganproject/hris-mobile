import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../rekan/rekan_providers.dart';
import '../t2_common/auth_image.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

/// Kartu pengumuman HR (oranye bila belum dibaca).
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.item, this.onReturn});
  final Map<String, dynamic> item;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final unread = item['is_read'] != true;
    return T2Card(
      onTap: () async {
        await context.push('/kabar/pengumuman/${item['id']}');
        onReturn?.call();
      },
      color: unread ? const Color(0xFFFFF7ED) : Colors.white,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(gradient: T2Colors.gradient, borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (item['is_pinned'] == true) ...[
                const Icon(Icons.push_pin, size: 14, color: T2Colors.orangeText),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(item['title'] as String? ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(item['excerpt'] as String? ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: T2Colors.muted, height: 1.35)),
            const SizedBox(height: 6),
            Row(children: [
              Text('HR · ${relativeTime(item['published_at'])}', style: const TextStyle(fontSize: 12, color: T2Colors.faint)),
              if (item['has_attachment'] == true) ...[
                const SizedBox(width: 8),
                const Icon(Icons.attach_file, size: 14, color: T2Colors.faint),
              ],
              const Spacer(),
              if (unread) const StatusChip('Baru', tone: 'warning'),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Kartu postingan rekan: penulis, isi, foto, suka, komentar.
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, this.onChanged, this.inDetail = false});
  final Map<String, dynamic> post;
  final VoidCallback? onChanged;
  final bool inDetail;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late bool _liked = widget.post['liked'] == true;
  late int _likes = (widget.post['likes_count'] as num?)?.toInt() ?? 0;

  @override
  void didUpdateWidget(covariant PostCard old) {
    super.didUpdateWidget(old);
    _liked = widget.post['liked'] == true;
    _likes = (widget.post['likes_count'] as num?)?.toInt() ?? 0;
  }

  Future<void> _toggleLike() async {
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      final res = await ref.read(t2ApiProvider).post('posts/${widget.post['id']}/like');
      final d = asMap(res['data']);
      setState(() {
        _liked = d['liked'] == true;
        _likes = (d['likes_count'] as num?)?.toInt() ?? _likes;
      });
    } catch (e) {
      setState(() {
        _liked = !_liked;
        _likes += _liked ? 1 : -1;
      });
      if (mounted) showSnack(context, t2Error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final author = asMap(p['author']);
    final hidden = p['is_hidden'] == true;
    final online = ref.watch(onlineIdsProvider).contains((author['id'] as num?)?.toInt());

    void open() async {
      if (widget.inDetail) return;
      await context.push('/kabar/post/${p['id']}');
      widget.onChanged?.call();
    }

    return T2Card(
      onTap: widget.inDetail ? null : open,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: author['id'] == null ? null : () => context.push('/rekan/${author['id']}'),
              child: Row(children: [
                PersonAvatar(person: author, size: 40, online: online ? true : null),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(author['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    Text(
                      [author['job_title'], relativeTime(p['created_at']), if (p['audience'] == 'division') p['audience_label']]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(fontSize: 12, color: T2Colors.muted),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          PostMenu(
            isMine: p['is_mine'] == true,
            onDelete: () async {
              await ref.read(t2ApiProvider).delete('posts/${p['id']}');
              if (!context.mounted) return;
              showSnack(context, 'Postingan dihapus.');
              widget.onChanged?.call();
              if (widget.inDetail) Navigator.of(context).maybePop();
            },
            onReport: (reason) => ref.read(t2ApiProvider).post('posts/${p['id']}/report', data: {'reason': reason}),
          ),
        ]),
        if (hidden)
          Container(
            margin: const EdgeInsets.only(top: 10, right: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Disembunyikan HR${(p['hidden_reason'] as String?)?.isNotEmpty == true ? ': ${p['hidden_reason']}' : ''}. Hanya Anda yang melihatnya.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 8, 0),
          child: Text(
            p['body'] as String? ?? '',
            maxLines: widget.inDetail ? null : 6,
            overflow: widget.inDetail ? null : TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, height: 1.45, color: T2Colors.ink),
          ),
        ),
        if (p['has_image'] == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 8, 0),
            child: AuthImage('posts/${p['id']}/image', height: widget.inDetail ? 260 : 200),
          ),
        Row(children: [
          TextButton.icon(
            onPressed: _toggleLike,
            style: TextButton.styleFrom(foregroundColor: _liked ? const Color(0xFFE11D48) : T2Colors.muted),
            icon: Icon(_liked ? Icons.favorite : Icons.favorite_border, size: 20),
            label: Text('$_likes', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          TextButton.icon(
            onPressed: widget.inDetail ? null : open,
            style: TextButton.styleFrom(foregroundColor: T2Colors.muted, disabledForegroundColor: T2Colors.muted),
            icon: const Icon(Icons.mode_comment_outlined, size: 19),
            label: Text('${p['comments_count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }
}

/// Menu titik tiga: hapus (milik sendiri) atau laporkan ke HR (milik orang lain).
class PostMenu extends StatelessWidget {
  const PostMenu({super.key, required this.isMine, required this.onDelete, required this.onReport, this.size = 20});
  final bool isMine;
  final Future<void> Function() onDelete;
  final Future<Object?> Function(String? reason) onReport;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: size, color: T2Colors.faint),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) async {
        try {
          if (v == 'delete') {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Hapus?'),
                content: const Text('Tulisan ini akan dihapus dan tidak bisa dikembalikan.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
                ],
              ),
            );
            if (ok == true) await onDelete();
          } else {
            final ctrl = TextEditingController();
            final reason = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Laporkan ke HR?'),
                content: TextField(controller: ctrl, maxLines: 3, decoration: t2Input('Alasan (opsional)')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                  TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Laporkan')),
                ],
              ),
            );
            if (reason == null) return;
            await onReport(reason.isEmpty ? null : reason);
            if (context.mounted) showSnack(context, 'Terima kasih, laporan diteruskan ke HR.');
          }
        } catch (e) {
          if (context.mounted) showSnack(context, t2Error(e), error: true);
        }
      },
      itemBuilder: (_) => [
        if (isMine) const PopupMenuItem(value: 'delete', child: Text('Hapus')) else const PopupMenuItem(value: 'report', child: Text('Laporkan ke HR')),
      ],
    );
  }
}
