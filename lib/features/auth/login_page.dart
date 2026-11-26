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

    const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.chipText);

    return Scaffold(
      body: DotBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: AppColors.heroShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: const Stack(children: [
                  Positioned(top: -70, right: -80, child: YellowRing(size: 240, width: 20)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 28),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CompanyLogo(size: 60),
                      SizedBox(height: 22),
                      Text('HRIS Cahaya Optima Karya',
                          style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      Text('Urusan kantor,\ncukup dari HP.',
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5)),
                      SizedBox(height: 8),
                      Text('Lihat kehadiran, ajukan cuti, izin, dan lembur.',
                          style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13.5, height: 1.5)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(20),
                radius: 22,
                child: AutofillGroup(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (notice != null) ...[
                      _banner(notice, AppColors.warningSoft, AppColors.warning),
                      const SizedBox(height: 14),
                    ],
                    const Text('NIK atau email', style: label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _login,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    const Text('Kata sandi', style: label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
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
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('Masuk'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ]),
                    ),
                    const SizedBox(height: 14),
                    const Text('Lupa kata sandi? Hubungi HR.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.tablet_android_outlined, size: 19, color: AppColors.accentText),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Absen masuk dan pulang dilakukan di tablet kantor atau mesin gudang, bukan dari aplikasi ini.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF475467), height: 1.5),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, height: 1.45)),
      );
}
