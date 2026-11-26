import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

/// Kartu pengumuman HR. Yang belum dibaca diberi garis kuning di kiri
/// dan label "Baru".
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.item, this.onReturn});
  final Map<String, dynamic> item;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final unread = item['is_read'] != true;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await context.push('/pengumuman/${item['id']}');
        onReturn?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: unread ? AppColors.accent : Colors.transparent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 13, 14, 13),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (unread) ...[const StatusChip('Baru', tone: 'warning'), const SizedBox(width: 8)],
                    if (item['is_pinned'] == true) ...[
                      const Icon(Icons.push_pin, size: 13, color: AppColors.navy),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text('${dateLabel(item['published_at'], year: false)} · HR',
                          overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.faint)),
                    ),
                    if (item['has_attachment'] == true) const Icon(Icons.attach_file, size: 14, color: AppColors.faint),
                  ]),
                  const SizedBox(height: 6),
                  Text(item['title'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.3)),
                  if ((item['excerpt'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item['excerpt'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
