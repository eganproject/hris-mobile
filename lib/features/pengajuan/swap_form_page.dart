import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/search_select.dart';
import '../t2_common/t2_ui.dart';
import 'pengajuan_providers.dart';

/// Ajukan tukar jadwal ke rekan selokasi & sedivisi. Rekan menyetujui dulu,
/// lalu HR. Bukti kesepakatan (tangkapan layar chat) wajib.
class SwapFormPage extends ConsumerStatefulWidget {
  const SwapFormPage({super.key, this.date});
  final String? date;

  @override
  ConsumerState<SwapFormPage> createState() => _SwapFormPageState();
}

class _SwapFormPageState extends ConsumerState<SwapFormPage> {
  String _type = 'swap';
  int? _partnerId;
  late DateTime _myDate = (widget.date != null ? DateTime.tryParse(widget.date!) : null) ?? DateTime.now().add(const Duration(days: 1));
  DateTime? _partnerDate;
  final _reason = TextEditingController();
  XFile? _proof;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 120)),
      );

  Future<void> _submit() async {
    if (_partnerId == null) return showSnack(context, 'Pilih rekan.', error: true);
    if (_proof == null) return showSnack(context, 'Lampirkan bukti kesepakatan dengan rekan.', error: true);
    if (_type != 'cover' && _partnerDate == null) return showSnack(context, 'Pilih tanggal rekan.', error: true);

    setState(() => _busy = true);
    try {
      final form = FormData.fromMap({
        'type': _type,
        'partner_id': _partnerId,
        'requester_date': ymd(_myDate),
        if (_type != 'cover') 'partner_date': ymd(_partnerDate!),
        if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
        'attachment': await MultipartFile.fromFile(_proof!.path, filename: _proof!.name),
      });
      final res = await ref.read(t2ApiProvider).post('swaps', data: form);
      refreshPengajuan(ref);
      if (!mounted) return;
      showSnack(context, (res['message'] ?? 'Terkirim.') as String);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colleagues = ref.watch(colleaguesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: colleagues.when(
          loading: () => const Center(child: CircularProgressIndicator(color: T2Colors.orange)),
          error: (e, _) => EmptyNote(t2Error(e)),
          data: (res) {
            final people = asList(res['data']);
            final types = Map<String, dynamic>.from((res['meta']?['types'] as Map?) ?? const {'swap': 'Tukar shift'});

            return Column(children: [
              const BackHeader(title: 'Tukar jadwal', subtitle: 'Disetujui rekan, lalu HR'),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 20), children: [
                  SearchSelectField<String>(
                    label: 'Jenis',
                    value: _type,
                    options: [for (final e in types.entries) SelectOption(e.key, e.value.toString())],
                    onChanged: (v) => setState(() => _type = v),
                  ),
                  const SizedBox(height: 12),
                  SearchSelectField<int>(
                    label: 'Rekan',
                    sheetTitle: 'Pilih rekan',
                    searchHint: 'Cari nama rekan…',
                    value: _partnerId,
                    options: [
                      for (final p in people)
                        SelectOption(p['id'] as int, p['name'] as String? ?? '-', subtitle: p['job_title'] as String?, person: p),
                    ],
                    onChanged: (v) => setState(() => _partnerId = v),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.inputLine)),
                    trailing: const Icon(Icons.expand_more_rounded, color: AppColors.faint),
                    leading: const Icon(Icons.event, color: T2Colors.orangeText),
                    title: const Text('Tanggal saya', style: TextStyle(fontSize: 12, color: T2Colors.muted)),
                    subtitle: Text(dateLabel(ymd(_myDate)), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T2Colors.ink)),
                    onTap: () async {
                      final d = await _pickDate(_myDate);
                      if (d != null) setState(() => _myDate = d);
                    },
                  ),
                  if (_type != 'cover') ...[
                    const SizedBox(height: 10),
                    ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.inputLine)),
                      trailing: const Icon(Icons.expand_more_rounded, color: AppColors.faint),
                      leading: const Icon(Icons.event_available, color: T2Colors.orangeText),
                      title: const Text('Tanggal rekan', style: TextStyle(fontSize: 12, color: T2Colors.muted)),
                      subtitle: Text(_partnerDate == null ? 'Pilih tanggal' : dateLabel(ymd(_partnerDate!)),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T2Colors.ink)),
                      onTap: () async {
                        final d = await _pickDate(_partnerDate ?? _myDate);
                        if (d != null) setState(() => _partnerDate = d);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(controller: _reason, minLines: 2, maxLines: 4, maxLength: 1000, decoration: t2Input('Alasan (opsional)')),
                  const Text('Bukti kesepakatan (wajib)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 80);
                      if (f != null) setState(() => _proof = f);
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_proof?.name ?? 'Pilih gambar'),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: PrimaryButton(label: 'Kirim ke rekan', busy: _busy, onPressed: _submit),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
