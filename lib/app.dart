import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/absen/offline_queue.dart';

class HrisApp extends ConsumerWidget {
  const HrisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Antrean offline hidup sepanjang aplikasi terbuka.
    ref.watch(offlineQueueProvider);

    return MaterialApp.router(
      title: 'HRIS Cahaya Optima Karya',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
