import 'package:material_ui/material_ui.dart';

/// Logo Cahaya Optima Karya (lingkaran COK), sama dengan
/// public/img/company-logo.png di HRIS web.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, this.size = 60});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x2E080E28), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Image.asset('assets/images/company_logo.png', width: size, height: size, fit: BoxFit.contain),
    );
  }
}
