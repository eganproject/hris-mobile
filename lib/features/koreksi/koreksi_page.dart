import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/t2_ui.dart';

class CorrectionDto {
  CorrectionDto({
    required this.workDate,
    this.clockIn,
    this.clockOut,
    required this.reason,
    required this.status,
    required this.statusLabel,
    this.notes,
  });

  final DateTime workDate;
  final String? clockIn;
  final String? clockOut;
  final String reason;
  final String status;
  final String statusLabel;
  final String? notes;

  factory CorrectionDto.fromJson(Map<String, dynamic> j) => CorrectionDto(
    workDate: DateTime.parse(j['work_date'] as String),
    clockIn: j['requested_clock_in'] as String?,
    clockOut: j['requested_clock_out'] as String?,
    reason: j['reason'] as String? ?? '',
    status: j['status'] as String? ?? 'pending',
    statusLabel: j['status_label'] as String? ?? '',
    notes: j['decision_notes'] as String?,
  );
}

final correctionsProvider = FutureProvider.autoDispose<List<CorrectionDto>>((ref) async {
  final res = await ref.watch(apiClientProvider).get('/corrections');
  return ((res.data['data'] as List?) ?? const []).map((e) => CorrectionDto.fromJson((e as Map).cast<String, dynamic>())).toList();
});

/// Koreksi absensi: ajukan jam masuk/pulang yang benar + bukti gambar.
/// Disetujui HR lewat menu Koreksi Absensi di web.
class KoreksiPage extends ConsumerStatefulWidget {
  const KoreksiPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<KoreksiPage> createState() => _KoreksiPageState();
}

class _KoreksiPageState extends ConsumerState<KoreksiPage> {
  late DateTime _date = widget.initialDate ?? DateTime.now();
  TimeOfDay? _in;
  TimeOfDay? _out;
  final _reason = TextEditingController();
  XFile? _attachment;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String? _fmt(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickAttachment(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (file != null) setState(() => _attachment = file);
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });
    if (_in == null && _out == null) {
      setState(() => _error = 'Isi minimal jam masuk atau jam pulang yang benar.');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Tulis alasan koreksi.');
      return;
    }
    if (_attachment == null) {
      setState(() => _error = 'Lampirkan bukti gambar (foto CCTV atau tangkapan layar aktivitas kerja).');
      return;
    }
    setState(() => _sending = true);
    try {
      final form = FormData.fromMap({
        'work_date': '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
        if (_in != null) 'requested_clock_in': _fmt(_in),
        if (_out != null) 'requested_clock_out': _fmt(_out),
        'reason': _reason.text.trim(),
        'attachment': await MultipartFile.fromFile(_attachment!.path, filename: _attachment!.name),
      });
      await ref.read(apiClientProvider).post('/corrections', data: form);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan koreksi terkirim ke HR.')));
      setState(() {
        _in = null;
        _out = null;
        _attachment = null;
        _reason.clear();
      });
      ref.invalidate(correctionsProvider);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(correctionsProvider);
    return DotScaffold(
      child: Column(
        children: [
          const BackHeader(title: 'Koreksi absen', subtitle: 'Lupa absen atau jam salah? Ajukan ke HR'),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field('Tanggal', Fmt.longDate(_date), Icons.event, () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime.now().subtract(const Duration(days: 60)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _date = picked);
                      }),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field('Jam masuk', _fmt(_in) ?? '--:--', Icons.login_rounded, () async {
                              final t = await showTimePicker(context: context, initialTime: _in ?? const TimeOfDay(hour: 8, minute: 0));
                              if (t != null) setState(() => _in = t);
                            }),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field('Jam pulang', _fmt(_out) ?? '--:--', Icons.logout_rounded, () async {
                              final t = await showTimePicker(context: context, initialTime: _out ?? const TimeOfDay(hour: 17, minute: 0));
                              if (t != null) setState(() => _out = t);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reason,
                        maxLines: 3,
                        maxLength: 1000,
                        decoration: const InputDecoration(hintText: 'Alasan, mis. lupa absen pulang karena rapat'),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickAttachment(ImageSource.gallery),
                              icon: const Icon(Icons.photo_outlined),
                              label: Text(_attachment == null ? 'Pilih bukti' : 'Ganti bukti'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            tooltip: 'Foto dengan kamera',
                            onPressed: () => _pickAttachment(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                          ),
                        ],
                      ),
                      if (_attachment != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_attachment!.name, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _sending ? null : _submit,
                        child: _sending
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Kirim ke HR'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Pengajuan sebelumnya', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...list.when(
                  loading: () => [const Center(child: CircularProgressIndicator())],
                  error: (e, _) => [Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.muted))],
                  data: (items) => items.isEmpty
                      ? [const Text('Belum ada pengajuan.', style: TextStyle(color: AppColors.muted))]
                      : [
                          for (final c in items) ...[
                            AppCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(Fmt.shortDate(c.workDate), style: const TextStyle(fontWeight: FontWeight.w800)),
                                        Text(
                                          '${c.clockIn ?? '--:--'} – ${c.clockOut ?? '--:--'} · ${c.reason}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                                        ),
                                        if (c.notes != null && c.notes!.isNotEmpty)
                                          Text('HR: ${c.notes}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                                      ],
                                    ),
                                  ),
                                  StatusPill(
                                    label: c.statusLabel,
                                    tone: switch (c.status) {
                                      'approved' => PillTone.success,
                                      'rejected' => PillTone.danger,
                                      _ => PillTone.warning,
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value, IconData icon, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
