/// Konfigurasi build. Alamat server diisi saat build:
///   flutter build apk --dart-define=API_BASE_URL=https://hris.domainanda.com
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cok-hris.com',
  );

  /// Prefix semua API aplikasi HP di Laravel (routes/api.php).
  static const String apiPrefix = '/api/mobile/v1';

  static String get apiUrl => '$apiBaseUrl$apiPrefix';
}
