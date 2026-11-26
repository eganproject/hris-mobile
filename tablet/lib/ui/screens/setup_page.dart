import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/tablet_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Pemasangan pertama: HR membuat kode di web HRIS (Absensi > Tablet Absensi
/// Wajah > Daftarkan tablet) lalu mengetiknya di sini.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.tablet});
  final TabletController tablet;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final code = _code.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (code.length < 8) {
      setState(() => _error = 'Kode terdiri dari 8 huruf/angka.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.tablet.pair(code);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = widget.tablet.unpairedReason;
    return Scaffold(
      body: DottedBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CardBox(
                padding: const EdgeInsets.all(36),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Image.asset('assets/img/logo.png', width: 52, height: 52),
                    const SizedBox(width: 14),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Cahaya Optima Karya', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.navy)),
                      Text('Absensi wajah', style: TextStyle(color: C.muted)),
                    ]),
                  ]),
                  const SizedBox(height: 28),
                  const Text('Pasangkan tablet ini', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Di web HRIS buka Absensi > Tablet Absensi Wajah > Daftarkan tablet, lalu ketik kode pasangan yang muncul.',
                      style: TextStyle(color: C.muted, height: 1.45)),
                  if (reason != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: C.yellowSoft, borderRadius: BorderRadius.circular(12)),
                      child: Text(reason, style: const TextStyle(color: C.yellowText, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    maxLength: 9,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]'))],
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 6),
                    decoration: const InputDecoration(hintText: 'ABCD-1234', counterText: ''),
                    onSubmitted: (_) => _pair(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: C.redText, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _pair,
                    child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Text('Pasangkan'),
                  ),
                  const SizedBox(height: 16),
                  Text('Server: $apiBaseUrl · versi $appVersion', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: C.muted)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
