import 'package:intl/intl.dart';

/// Format tanggal/jam berbahasa Indonesia (locale id_ID diinisialisasi di main).
class Fmt {
  static String time(DateTime? t) => t == null ? '--:--' : DateFormat('HH:mm').format(t.toLocal());

  static String longDate(DateTime d) => DateFormat('EEEE, d MMMM y', 'id_ID').format(d.toLocal());

  static String shortDate(DateTime d) => DateFormat('d MMM y', 'id_ID').format(d.toLocal());

  static String dayShort(DateTime d) => DateFormat('EEE', 'id_ID').format(d).toUpperCase();

  static String monthYear(DateTime d) => DateFormat('MMMM y', 'id_ID').format(d);

  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}j ${m}m' : '${m}m';
  }

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  static DateTime? parse(String? iso) => iso == null ? null : DateTime.tryParse(iso)?.toLocal();
}
