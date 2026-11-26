import 'models.dart';

/// Absen yang tercatat di tablet ini sejak sinkron terakhir.
class LocalEvent {
  const LocalEvent(this.type, this.at);
  final String type; // in | out
  final DateTime at;
}

class Predicted {
  const Predicted(this.type, {this.ignored = false, this.since});

  /// in | out
  final String type;

  /// Pindai ulang dalam jeda singkat: hanya ditampilkan, tidak dikirim.
  final bool ignored;

  /// Jam absen sebelumnya (untuk pesan "sudah absen pukul ..." atau lama kerja).
  final DateTime? since;
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Tebak masuk/pulang di tablet, dengan aturan yang sama dengan server
/// (TabletAttendanceService): sesi terbuka = pulang, pindai ulang < 1 menit
/// diabaikan, pindai lagi setelah pulang hari ini = pulang diperbarui. Server tetap
/// yang menentukan; tebakan ini dipakai untuk layar hasil (juga saat offline).
Predicted predictAction(Employee e, List<LocalEvent> local, DateTime now, TabletSettings s) {
  DateTime? openIn = e.openClockIn;
  DateTime? todayIn = e.todayClockIn != null && _sameDay(e.todayClockIn!, now) ? e.todayClockIn : null;
  DateTime? todayOut = e.todayClockOut != null && _sameDay(e.todayClockOut!, now) ? e.todayClockOut : null;

  final events = [...local]..sort((a, b) => a.at.compareTo(b.at));
  for (final ev in events) {
    if (ev.type == 'in') {
      openIn = ev.at;
      if (_sameDay(ev.at, now)) {
        todayIn = ev.at;
        todayOut = null;
      }
    } else {
      openIn = null;
      if (_sameDay(ev.at, now)) todayOut = ev.at;
    }
  }

  final repeat = Duration(seconds: s.repeatIgnoreSeconds);
  final session = Duration(minutes: s.sessionMaxMinutes);

  if (openIn != null && !now.isBefore(openIn) && now.difference(openIn) <= session) {
    if (now.difference(openIn) < repeat) return Predicted('in', ignored: true, since: openIn);
    return Predicted('out', since: openIn);
  }

  if (todayIn != null && todayOut != null) {
    if (!now.isAfter(todayOut) || now.difference(todayOut) < repeat) return Predicted('out', ignored: true, since: todayOut);
    return Predicted('out', since: todayIn);
  }

  if (todayIn != null) return Predicted('out', since: todayIn);

  return const Predicted('in');
}

/// "Tepat waktu" / "Terlambat N menit" untuk layar absen masuk.
String? punctualityLabel(Employee e, DateTime at) {
  final s = e.schedule;
  if (s == null) return null;
  final parts = s.start.split(':');
  if (parts.length < 2) return null;
  final start = DateTime(at.year, at.month, at.day, int.parse(parts[0]), int.parse(parts[1]));
  final late = at.difference(start).inMinutes;
  if (late > s.lateTolerance && late > 0) return 'Terlambat $late menit';
  return 'Tepat waktu';
}

String durationLabel(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  return h > 0 ? 'Kerja $h j $m m' : 'Kerja $m m';
}
