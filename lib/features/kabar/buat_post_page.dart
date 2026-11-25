import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../t2_common/t2_api.dart';
import '../t2_common/t2_ui.dart';

/// Tulis postingan: teks (maks 2.000), penerima (semua / divisi saya), foto opsional.
class BuatPostPage extends ConsumerStatefulWidget {
  const BuatPostPage({super.key});

  @override
  ConsumerState<BuatPostPage> createState() => _BuatPostPageState();
}

class _BuatPostPageState extends ConsumerState<BuatPostPage> {
  final _body = TextEditingController();
  String _audience = 'all';
  XFile? _image;
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final img = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (img != null) setState(() => _image = img);
  }

  Future<void> _submit() async {
    if (_body.text.trim().isEmpty) {
      showSnack(context, 'Tulis sesuatu dulu.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final form = FormData.fromMap({
        'body': _body.text.trim(),
        'audience': _audience,
        if (_image != null) 'image': MultipartFile.fromBytes(await _image!.readAsBytes(), filename: _image!.name),
      });
      await ref.read(t2ApiProvider).post('posts', data: form);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: Column(children: [
          const BackHeader(title: 'Tulis kabar'),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
              T2Card(
                child: TextField(
                  controller: _body,
                  autofocus: true,
                  minLines: 6,
                  maxLines: 14,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Bagikan kabar untuk rekan kerja…', border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 12),
              if (_image != null)
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: FutureBuilder(
                      future: _image!.readAsBytes(),
                      builder: (_, snap) => snap.hasData
                          ? Image.memory(snap.data!, height: 220, width: double.infinity, fit: BoxFit.cover)
                          : Container(height: 220, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => setState(() => _image = null),
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ])
              else
                Row(children: [
                  Expanded(child: _Action(icon: Icons.photo_library_outlined, label: 'Galeri', onTap: () => _pick(ImageSource.gallery))),
                  const SizedBox(width: 10),
                  Expanded(child: _Action(icon: Icons.photo_camera_outlined, label: 'Kamera', onTap: () => _pick(ImageSource.camera))),
                ]),
              const SizedBox(height: 16),
              const Text('Siapa yang bisa melihat?', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _audience,
                onChanged: (v) => setState(() => _audience = v ?? 'all'),
                child: const T2Card(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    RadioListTile(value: 'all', title: Text('Semua karyawan'), activeColor: T2Colors.orange),
                    RadioListTile(value: 'division', title: Text('Divisi saya saja'), activeColor: T2Colors.orange),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Postingan bisa dilihat HR dan disembunyikan bila melanggar aturan perusahaan.',
                style: TextStyle(fontSize: 12.5, color: T2Colors.muted),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: PrimaryButton(label: 'Kirim', icon: Icons.send_rounded, busy: _busy, onPressed: _submit),
          ),
        ]),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => T2Card(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: T2Colors.navy),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
