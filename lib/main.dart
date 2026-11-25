import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(ProviderScope(
    overrides: [
      // Server menolak token (HP dicabut HR / akun nonaktif) → kembali ke login.
      unauthorizedHandlerProvider.overrideWith(
        (ref) => (code, message) => ref.read(authControllerProvider.notifier).forceSignOut(message),
      ),
    ],
    child: const HrisApp(),
  ));
}
