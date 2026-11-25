import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Logo Cahaya Optima Karya: "C • K" navy dengan titik oranye
/// (sama dengan public/img/company-logo.svg di HRIS web).
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, this.size = 60});

  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = TextStyle(
      fontSize: size * 0.36,
      fontWeight: FontWeight.w800,
      color: AppColors.navy,
      height: 1,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [BoxShadow(color: Color(0x2E080E28), blurRadius: 24, offset: Offset(0, 10))],
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('C', style: letter),
          SizedBox(width: size * 0.04),
          Container(
            width: size * 0.13,
            height: size * 0.13,
            decoration: const BoxDecoration(color: AppColors.logoDot, shape: BoxShape.circle),
          ),
          SizedBox(width: size * 0.04),
          Text('K', style: letter),
        ],
      ),
    );
  }
}
