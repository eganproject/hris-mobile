import 'package:material_ui/material_ui.dart';

import '../../core/widgets/ui.dart';

/// Tab Kabar (pengumuman HR + postingan). Diisi di Tahap 2.
class KabarPage extends StatelessWidget {
  const KabarPage({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoon(
        title: 'Kabar',
        description: 'Pengumuman HR dan kabar dari rekan kerja akan tampil di sini.',
        icon: Icons.chat_bubble_outline,
      );
}
