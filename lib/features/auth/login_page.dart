import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/company_logo.dart';
import '../../core/widgets/ui.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Isi email/NIK dan kata sandi.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(_login.text, _password.text);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final notice = auth is AuthSignedOut ? auth.message : null;

    return Scaffold(
      body: Stack(children: [
        const GradientHeaderBackground(height: 430, radius: 44),
        SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    CompanyLogo(),
                    SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Cahaya Optima Karya', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('HRIS · Karyawan', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                  const SizedBox(height: 22),
                  const Text('Urusan kantor\ndari HP kamu',
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5)),
                  const SizedBox(height: 10),
                  const Text('Lihat kehadiran, ajukan cuti, izin, dan lembur.',
                      style: TextStyle(color: Color(0xE0FFFFFF), fontSize: 15, height: 1.5)),
                ]),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(20, 34, 20, 0),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [BoxShadow(color: Color(0x24111C45), blurRadius: 44, offset: Offset(0, 20))],
                ),
                child: AutofillGroup(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (notice != null) ...[
                      _banner(notice, AppColors.warningSoft, AppColors.warning),
                      const SizedBox(height: 14),
                    ],
                    const Text('Email atau NIK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _login,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline)),
                    ),
                    const SizedBox(height: 14),
                    const Text('Kata sandi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Masuk'),
                    ),
                  ]),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(30, 28, 30, 30),
                child: Text(
                  'Pakai akun yang sama dengan HRIS web. Lupa kata sandi atau belum punya akun? Hubungi HR.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _banner(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, height: 1.45)),
      );
}
