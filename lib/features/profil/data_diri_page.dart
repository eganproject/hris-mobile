import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';
import 'profil_providers.dart';

/// Data diri: semua data tampil, yang boleh diubah sendiri sama dengan web
/// (telepon, alamat, motto). Sisanya diubah HR.
class DataDiriPage extends ConsumerWidget {
  const DataDiriPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: Column(children: [
          BackHeader(
            title: 'Data diri',
            trailing: profile.hasValue
                ? TextButton(
                    onPressed: () => _edit(context, ref, profile.requireValue),
                    child: const Text('Ubah', style: TextStyle(color: T2Colors.orangeText, fontWeight: FontWeight.w800)),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncBody<Map<String, dynamic>>(
              value: profile,
              onRefresh: () async => ref.invalidate(profileProvider),
              builder: (p) {
                final manager = p['manager'] is Map ? Map<String, dynamic>.from(p['manager'] as Map) : null;
                final departments = (p['departments'] as List? ?? const []).join(', ');
                return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
                  T2Card(
                    child: Column(children: [
                      _Field('Nama lengkap', p['name']),
                      _Field('NIK', p['employee_number']),
                      _Field('Jabatan', p['job_title']),
                      _Field('Divisi', departments.isNotEmpty ? departments : p['department']),
                      _Field('Lokasi kerja', p['branch']),
                      _Field('Atasan langsung', manager?['name']),
                      _Field('Tanggal bergabung', p['join_date'] == null ? null : dateLabel(p['join_date'])),
                      _Field('Tanggal lahir', p['birth_date'] == null ? null : dateLabel(p['birth_date']), last: true),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  T2Card(
                    child: Column(children: [
                      _Field('Email', p['email']),
                      _Field('Telepon', p['phone']),
                      _Field('Alamat', p['address']),
                      _Field('Motto', p['motto'], last: true),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Data selain telepon, alamat, dan motto diubah oleh HR. Hubungi HR bila ada yang keliru.',
                    style: TextStyle(fontSize: 12.5, color: T2Colors.muted),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Map<String, dynamic> p) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _EditSheet(profile: p),
    );
    if (saved == true) {
      ref.invalidate(profileProvider);
      if (context.mounted) showSnack(context, 'Data pribadi berhasil diperbarui.');
    }
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.last = false});
  final String label;
  final dynamic value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = (value == null || value.toString().trim().isEmpty) ? '-' : value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: T2Colors.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(color: T2Colors.muted, fontSize: 13.5))),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
      ]),
    );
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.profile});
  final Map<String, dynamic> profile;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _phone = TextEditingController(text: widget.profile['phone'] as String? ?? '');
  late final _address = TextEditingController(text: widget.profile['address'] as String? ?? '');
  late final _motto = TextEditingController(text: widget.profile['motto'] as String? ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _motto.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(t2ApiProvider).patch('profile', data: {
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'motto': _motto.text.trim().isEmpty ? null : _motto.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = t2Error(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Ubah data diri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: t2Input('Nomor telepon')),
        const SizedBox(height: 10),
        TextField(controller: _address, minLines: 2, maxLines: 4, decoration: t2Input('Alamat')),
        const SizedBox(height: 10),
        TextField(controller: _motto, maxLength: 160, decoration: t2Input('Motto')),
        if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Simpan', busy: _busy, onPressed: _save),
      ]),
    );
  }
}
