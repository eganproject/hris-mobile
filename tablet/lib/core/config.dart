/// Alamat HRIS. Diisi saat build: --dart-define=API_BASE_URL=https://...
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://cok-hris.com');

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// Jeda sinkron data karyawan + tanda tablet masih hidup.
const syncInterval = Duration(seconds: 60);

/// Jeda mencoba kirim ulang antrean absen.
const flushInterval = Duration(seconds: 15);

/// Lama layar hasil sebelum absen dikirim (waktu untuk menekan "Bukan saya").
const resultSeconds = 4;

/// Wajah berkualitas yang tidak cocok selama ini → layar "Wajah belum dikenali".
const unknownAfter = Duration(milliseconds: 2500);
