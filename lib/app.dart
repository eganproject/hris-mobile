import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/push/push_service.dart';
import 'core/config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/update/app_update.dart';

/// Cek wajib update (publik, jadi layar update juga muncul sebelum login).
final appUpdaterProvider = Provider<AppUpdater>((ref) {
  final updater = AppUpdater(checkUrl: '${AppConfig.apiBaseUrl}/api/app-update/employee');
  ref.onDispose(updater.dispose);
  return updater;
});

class HrisApp extends ConsumerWidget {
  const HrisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushRegistrarProvider);
    return MaterialApp.router(
      title: 'HRIS Cahaya Optima Karya',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => UpdateGate(updater: ref.watch(appUpdaterProvider), child: child ?? const SizedBox.shrink()),
    );
  }
}
