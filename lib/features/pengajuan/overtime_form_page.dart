import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';
import 'pengajuan_providers.dart';

/// Ajukan lembur untuk hari yang sudah dijalani; diputuskan atasan langsung.
class OvertimeFormPage extends ConsumerStatefulWidget {
  const OvertimeFormPage({super.key});

  @override
  ConsumerState<OvertimeFormPage> createState() => _OvertimeFormPageState();
}

class _OvertimeFormPageState extends ConsumerState<OvertimeFormPage> {
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 19, minute: 0);
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _t(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int get _minutes {
    var m = (_end.hour * 60 + _end.minute) - (_start.hour * 60 + _start.minute);
    if (m <= 0) m += 24 * 60; // melewati tengah malam
    return m;
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      showSnack(context, 'Tulis uraian pekerjaan lemburnya.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ref.read(t2ApiProvider).post('overtime', data: {
        'work_date': ymd(_date),
        'start_time': _t(_start),
        'end_time': _t(_end),
        'reason': _reason.text.trim(),
      });
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          const BackHeader(title: 'Ajukan lembur', subtitle: 'Dikirim ke atasan langsung'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 20), children: [
              _PickerRow(
                icon: Icons.calendar_today_outlined,
                label: 'Tanggal',
                value: dateLabel(ymd(_date)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(const Duration(days: 60)),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _PickerRow(
                    icon: Icons.schedule,
                    label: 'Mulai',
                    value: _t(_start),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _start);
                      if (t != null) setState(() => _start = t);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerRow(
                    icon: Icons.schedule,
                    label: 'Selesai',
                    value: _t(_end),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _end);
                      if (t != null) setState(() => _end = t);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: T2Colors.orangeSoft, borderRadius: BorderRadius.circular(20)),
                child: Text('Durasi ${minutesLabel(_minutes)}',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: T2Colors.orangeText)),
              ),
              const SizedBox(height: 12),
              TextField(controller: _reason, minLines: 3, maxLines: 5, maxLength: 500, decoration: t2Input('Uraian pekerjaan')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: PrimaryButton(label: 'Kirim pengajuan', busy: _busy, onPressed: _submit),
          ),
        ]),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return T2Card(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(icon, color: T2Colors.orangeText, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: T2Colors.muted)),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }
}
