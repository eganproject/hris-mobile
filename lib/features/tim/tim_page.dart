import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../pengajuan/pengajuan_widgets.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';
import 'persetujuan_page.dart';
import 'tim_hari_ini_page.dart';

/// Tab Tim (khusus atasan): ringkasan tim hari ini, jalan pintas
/// persetujuan / atur jadwal / struktur, pengajuan yang menunggu, dan
/// anggota tim.
class TimPage extends ConsumerStatefulWidget {
  const TimPage({super.key});

  @override
  ConsumerState<TimPage> createState() => _TimPageState();
}

class _TimPageState extends ConsumerState<TimPage> {
  final Set<String> _busy = {};

  Future<void> _decide(Map<String, dynamic> item, bool approve) async {
    final key = '${item['kind']}-${item['id']}';
    setState(() => _busy.add(key));
    await decideApproval(context, ref, item, approve);
    if (mounted) setState(() => _busy.remove(key));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final today = ref.watch(teamTodayProvider);
    final approvals = ref.watch(approvalsProvider('semua'));
    final t = today.asData?.value;
    final counts = asMap(t?['counts']);
    final teamSize = (t?['team_size'] as num?)?.toInt();
    final pendingItems = asList(approvals.asData?.value['data']);
    final meta = approvals.asData?.value['meta'];
    final pendingTotal = meta is Map && meta['total'] is num ? (meta['total'] as num).toInt() : pendingItems.length;
    final members = asList(t?['members']);
    final now = DateTime.now();

    int c(String k) => (counts[k] as num?)?.toInt() ?? 0;
    final present = c('present') + c('late');

    return DotScaffold(
      child: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () async {
          ref.invalidate(teamTodayProvider);
          refreshApprovals(ref);
          await ref.read(teamTodayProvider.future).then((_) {}, onError: (_) {});
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            TabHeader(
              title: 'Tim',
              subtitle: [user?.employee.department, if (teamSize != null) '$teamSize orang'].whereType<String>().join(' · '),
              trailing: const StatusPill(label: 'Atasan', tone: PillTone.accent),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: NavyHeroCard(
                onTap: () => context.push('/tim/hari-ini'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hari ini · ${dateLabel(ymd(now), year: false)}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xB3FFFFFF), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: t == null ? '–' : '$present', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                      TextSpan(
                        text: teamSize == null ? '' : ' dari $teamSize hadir',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xCCFFFFFF)),
                      ),
                    ]),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    StatusPill(label: '${c('not_yet')} belum absen', tone: c('not_yet') > 0 ? PillTone.accent : PillTone.onPrimary),
                    StatusPill(label: '${c('leave')} cuti', tone: PillTone.onPrimary),
                    StatusPill(label: '${c('late')} terlambat', tone: PillTone.onPrimary),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _Tile(Icons.fact_check_outlined, 'Persetujuan', '/tim/persetujuan', badge: pendingTotal),
                const SizedBox(width: 10),
                const _Tile(Icons.calendar_view_week_outlined, 'Atur jadwal', '/tim/jadwal'),
                const SizedBox(width: 10),
                const _Tile(Icons.account_tree_outlined, 'Struktur', '/struktur'),
              ]),
            ),
            const SizedBox(height: 22),
            SectionLabel('Menunggu persetujuan',
                action: pendingTotal > 0 ? 'Semua ($pendingTotal)' : null, onAction: () => context.push('/tim/persetujuan')),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: approvals.when(
                skipLoadingOnRefresh: true,
                loading: () => const AppCard(child: SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))),
                error: (e, _) => AppCard(child: Text(t2Error(e), style: const TextStyle(color: AppColors.muted))),
                data: (_) => pendingItems.isEmpty
                    ? const AppCard(
                        child: Row(children: [
                          Icon(Icons.task_alt, color: AppColors.success),
                          SizedBox(width: 10),
                          Expanded(child: Text('Tidak ada pengajuan yang menunggu.', style: TextStyle(color: AppColors.muted))),
                        ]),
                      )
                    : Column(children: [
                        ApprovalCard(
                          item: pendingItems.first,
                          busy: _busy.contains('${pendingItems.first['kind']}-${pendingItems.first['id']}'),
                          onApprove: () => _decide(pendingItems.first, true),
                          onReject: () => _decide(pendingItems.first, false),
                        ),
                        if (pendingItems.length > 1) ...[
                          const SizedBox(height: 8),
                          AppCard(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(children: [
                              for (final (i, item) in pendingItems.skip(1).take(3).indexed)
                                _PendingRow(item: item, last: i == (pendingItems.length - 1).clamp(0, 3) - 1),
                            ]),
                          ),
                        ],
                      ]),
              ),
            ),
            const SizedBox(height: 22),
            SectionLabel('Anggota tim', action: 'Lihat semua', onAction: () => context.push('/tim/hari-ini')),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: members.isEmpty
                  ? AppCard(
                      child: Text(today.isLoading ? 'Memuat…' : 'Belum ada anggota tim.', style: const TextStyle(color: AppColors.muted)),
                    )
                  : AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(children: [
                        for (final (i, m) in members.take(5).indexed) _MemberRow(row: m, last: i == members.take(5).length - 1),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.route, {this.badge = 0});
  final IconData icon;
  final String label;
  final String route;
  final int badge;

  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          radius: 14,
          onTap: () => context.push(route),
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.navySoft, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: AppColors.navy, size: 21),
              ),
              if (badge > 0)
                Positioned(
                  top: -6,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text('$badge', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.item, required this.last});
  final Map<String, dynamic> item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final emp = asMap(item['employee']);
    final style = categoryStyle(item['category'] as String?);
    final when = item['kind'] == 'overtime'
        ? '${dateLabel(item['work_date'], year: false)} · ${item['start_time'] ?? ''}–${item['end_time'] ?? ''}'
        : rangeLabel(item['start_date'], item['end_date']);
    return InkWell(
      onTap: () => context.push('/tim/persetujuan'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(children: [
          PersonAvatar(person: emp, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(emp['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              Text(when, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
            decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(99)),
            child: Text(approvalCategoryLabel(item['category'] as String?),
                style: TextStyle(color: style.fg, fontWeight: FontWeight.w600, fontSize: 11.5)),
          ),
        ]),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.row, required this.last});
  final Map<String, dynamic> row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final emp = asMap(row['employee']);
    final schedule = asMap(row['schedule']);
    final state = row['state'] as String? ?? 'off';
    final late = (row['late_minutes'] as num?)?.toInt() ?? 0;
    final (label, tone) = switch (state) {
      'present' => ('Masuk ${row['clock_in'] ?? ''}', 'success'),
      'late' => ('Telat $late mnt', 'warning'),
      'wfh' => ('WFH', 'info'),
      'leave' => (schedule['label'] as String? ?? 'Cuti', 'info'),
      'not_yet' => ('Belum absen', 'danger'),
      _ => ('Libur', 'neutral'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(children: [
        PersonAvatar(person: emp, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emp['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(emp['job_title'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        StatusChip(label.trim(), tone: tone),
      ]),
    );
  }
}
