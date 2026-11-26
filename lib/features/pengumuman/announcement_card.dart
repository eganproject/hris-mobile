import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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
        await context.push('/pengumuman/${item['id']}');
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

