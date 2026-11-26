import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/search_select.dart';
import '../t2_common/t2_ui.dart';
import 'pengajuan_providers.dart';

/// Ajukan cuti / izin / sakit. Dikirim ke atasan langsung (atau HR bila belum
/// punya atasan). Sakit wajib melampirkan foto surat keterangan.
class LeaveFormPage extends ConsumerStatefulWidget {
  const LeaveFormPage({super.key, this.category = 'cuti'});
  final String category;

  @override
  ConsumerState<LeaveFormPage> createState() => _LeaveFormPageState();
}

class _LeaveFormPageState extends ConsumerState<LeaveFormPage> {
  late String _category = widget.category;
  int? _typeId;
  DateTimeRange? _range;
  final _reason = TextEditingController();
  XFile? _attachment;
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
      helpText: 'Pilih tanggal',
      saveText: 'Pilih',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: T2Colors.orange)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _pickAttachment(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 80);
    if (file != null) setState(() => _attachment = file);
  }

  Future<void> _submit(Map<String, dynamic> type) async {
    if (_range == null) {
      showSnack(context, 'Pilih tanggal dulu.', error: true);
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      final form = FormData.fromMap({
        'leave_type_id': type['id'],
        'start_date': ymd(_range!.start),
        'end_date': ymd(_range!.end),
        if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
        if (_attachment != null) 'attachment': await MultipartFile.fromFile(_attachment!.path, filename: _attachment!.name),
      });
      final res = await ref.read(t2ApiProvider).post('leave', data: form);
      refreshPengajuan(ref);
      if (!mounted) return;
      showSnack(context, (res['message'] ?? 'Pengajuan terkirim.') as String);
      Navigator.of(context).pop();
    } on DioException catch (e) {
      final errs = (e.response?.data is Map) ? (e.response!.data['errors'] as Map?) : null;
      setState(() => _errors = errs?.map((k, v) => MapEntry(k.toString(), List<String>.from(v as List))) ?? {});
      if (mounted) showSnack(context, t2Error(e), error: true);
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _err(String field) => _errors[field]?.first;

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(leaveTypesProvider);
    final title = switch (_category) { 'izin' => 'Ajukan izin', 'sakit' => 'Ajukan sakit', _ => 'Ajukan cuti' };

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: types.when(
          loading: () => const Center(child: CircularProgressIndicator(color: T2Colors.orange)),
          error: (e, _) => EmptyNote(t2Error(e)),
          data: (all) {
            final ofCategory = all.where((t) => t['category'] == _category).toList();
            final type = ofCategory.firstWhere((t) => t['id'] == _typeId, orElse: () => ofCategory.isNotEmpty ? ofCategory.first : <String, dynamic>{});
            final days = _range == null ? 0 : _range!.end.difference(_range!.start).inDays + 1;
            final remaining = type['remaining'] as int?;
            final needsAttachment = type['requires_attachment'] == true;

            return Column(children: [
              BackHeader(title: title, subtitle: 'Dikirim ke atasan langsung'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  children: [
                    _Segmented(
                      value: _category,
                      options: const [('cuti', 'Cuti'), ('izin', 'Izin'), ('sakit', 'Sakit')],
                      onChanged: (v) => setState(() {
                        _category = v;
                        _typeId = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (ofCategory.isEmpty)
                      const EmptyNote('Jenis pengajuan ini belum disiapkan HR.')
                    else ...[
                      if (ofCategory.length > 1) ...[
                        SearchSelectField<int>(
                          label: 'Jenis',
                          sheetTitle: 'Pilih jenis $_category',
                          searchHint: 'Cari jenis…',
                          value: type['id'] as int?,
                          options: [for (final t in ofCategory) SelectOption(t['id'] as int, t['name'] as String)],
                          onChanged: (v) => setState(() => _typeId = v),
                        ),
                        if (_err('leave_type_id') != null) _ErrorText(_err('leave_type_id')!),
                        const SizedBox(height: 12),
                      ],
                      T2Card(
                        onTap: _pickRange,
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          const Icon(Icons.calendar_month_outlined, color: T2Colors.orangeText),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _range == null ? 'Pilih tanggal' : rangeLabel(ymd(_range!.start), ymd(_range!.end)),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: T2Colors.faint),
                        ]),
                      ),
                      if (_err('start_date') != null) _ErrorText(_err('start_date')!),
                      if (_range != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(color: T2Colors.orangeSoft, borderRadius: BorderRadius.circular(20)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${rangeLabel(ymd(_range!.start), ymd(_range!.end))} · $days hari',
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: T2Colors.orangeText)),
                            if (remaining != null)
                              Text('Sisa ${type['name']} setelah ini: ${remaining - days} hari',
                                  style: const TextStyle(fontSize: 12.5, color: T2Colors.orangeDark)),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(controller: _reason, minLines: 2, maxLines: 4, maxLength: 1000, decoration: t2Input('Alasan (opsional)')),
                      const SizedBox(height: 4),
                      Text(needsAttachment ? 'Foto surat keterangan sakit (wajib)' : 'Lampiran (opsional)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickAttachment(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Kamera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickAttachment(ImageSource.gallery),
                            icon: const Icon(Icons.photo_outlined),
                            label: const Text('Galeri'),
                          ),
                        ),
                      ]),
                      if (_attachment != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [
                            const Icon(Icons.attach_file, size: 18, color: T2Colors.muted),
                            Expanded(child: Text(_attachment!.name, overflow: TextOverflow.ellipsis)),
                            IconButton(onPressed: () => setState(() => _attachment = null), icon: const Icon(Icons.close, size: 18)),
                          ]),
                        ),
                      if (_err('attachment') != null) _ErrorText(_err('attachment')!),
                    ],
                  ],
                ),
              ),
              if (ofCategory.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: PrimaryButton(label: 'Kirim pengajuan', busy: _busy, onPressed: () => _submit(type)),
                ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.options, required this.onChanged});
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: T2Colors.bg, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        for (final o in options)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == o.$1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: value == o.$1 ? const [BoxShadow(color: Color(0x14111C45), blurRadius: 8, offset: Offset(0, 2))] : null,
                ),
                child: Text(o.$2,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: value == o.$1 ? FontWeight.w800 : FontWeight.w600,
                      color: value == o.$1 ? T2Colors.ink : T2Colors.muted,
                    )),
              ),
            ),
          ),
      ]),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(text, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5)));
}
