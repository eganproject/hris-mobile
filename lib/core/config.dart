/// Konfigurasi build. Alamat server diisi saat build:
///   flutter build apk --dart-define=API_BASE_URL=https://hris.domainanda.com
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Prefix semua API aplikasi HP di Laravel (routes/api.php).
  static const String apiPrefix = '/api/mobile/v1';

  static String get apiUrl => '$apiBaseUrl$apiPrefix';
}
