/// Format tanggal/jam berbahasa Indonesia tanpa bergantung pada paket intl
/// (supaya tidak perlu initializeDateFormatting di main).
const _hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _hariPanjang = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const _bulanPanjang = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String dayShort(DateTime d) => _hari[d.weekday - 1];
String dayLong(DateTime d) => _hariPanjang[d.weekday - 1];
String monthShort(DateTime d) => _bulan[d.month - 1];
String monthLong(DateTime d) => _bulanPanjang[d.month - 1];

/// "Jum, 4 Des 2026"
String dateLabel(dynamic v, {bool year = true}) {
  final d = parseDate(v);
  if (d == null) return '-';
  return '${dayShort(d)}, ${d.day} ${monthShort(d)}${year ? ' ${d.year}' : ''}';
}

/// "27 Sep" (tahun ini) atau "27 Sep 2025" — tanpa nama hari, untuk baris sempit.
String shortDate(dynamic v) {
  final d = parseDate(v);
  if (d == null) return '-';
  return '${d.day} ${monthShort(d)}${d.year == DateTime.now().year ? '' : ' ${d.year}'}';
}

/// "Sen 14 – Rab 16 Des"
String rangeLabel(dynamic from, dynamic to) {
  final a = parseDate(from), b = parseDate(to);
  if (a == null) return '-';
  if (b == null || ymd(a) == ymd(b)) return dateLabel(a);
  final sameMonth = a.month == b.month && a.year == b.year;
  return '${dayShort(a)} ${a.day}${sameMonth ? '' : ' ${monthShort(a)}'} – ${dayShort(b)} ${b.day} ${monthShort(b)}';
}

String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "25 mnt", "2 jam", "kemarin", "3 Des"
String relativeTime(dynamic v) {
  final d = parseDate(v);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt';
  if (diff.inHours < 24) return '${diff.inHours} jam';
  if (diff.inDays == 1) return 'kemarin';
  if (diff.inDays < 7) return '${diff.inDays} hari';
  return '${d.day} ${monthShort(d)}';
}

String minutesLabel(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m mnt';
  return m == 0 ? '$h jam' : '$h j $m m';
}
