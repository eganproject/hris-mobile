import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/common.dart';

/// Satu kutipan: kalimat dan tokohnya.
class Quote {
  const Quote(this.text, this.author);
  final String text;
  final String author;
}

/// Baca `assets/quotes/kutipan.txt`: satu kutipan per baris, `kalimat|tokoh`.
List<Quote> parseQuotes(String raw) => [
      for (final line in const LineSplitter().convert(raw))
        if (line.trim().isNotEmpty)
          if (line.split('|') case [final text, final author] when text.trim().isNotEmpty)
            Quote(text.trim(), author.trim()),
    ];

/// Layar istirahat: muncul bila tablet lama tidak dipakai. Kamera sudah
/// dimatikan oleh pemanggil; layar gelap dengan jam kecil dan kutipan motivasi
/// yang berganti. Ketuk di mana saja untuk kembali ke layar absen.
class RestScreen extends StatefulWidget {
  const RestScreen({super.key, required this.onWake});
  final VoidCallback onWake;

  static const quoteEvery = Duration(seconds: 15);

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  static List<Quote>? _cache;
  final _random = Random();
  List<Quote> _order = const [];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(RestScreen.quoteEvery, (_) => _next());
  }

  Future<void> _load() async {
    final quotes = _cache ??= parseQuotes(await rootBundle.loadString('assets/quotes/kutipan.txt'));
    if (!mounted || quotes.isEmpty) return;
    setState(() => _order = [...quotes]..shuffle(_random));
  }

  void _next() {
    if (_order.isEmpty) return;
    setState(() {
      _index++;
      if (_index >= _order.length) {
        // Satu putaran selesai: acak lagi, tanpa mengulang kutipan terakhir di awal.
        final last = _order.last;
        _order = [..._order]..shuffle(_random);
        if (_order.length > 1 && identical(_order.first, last)) _order = [..._order.skip(1), _order.first];
        _index = 0;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  static const _months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

  @override
  Widget build(BuildContext context) {
    final quote = _order.isEmpty ? null : _order[_index];
    return Scaffold(
      backgroundColor: const Color(0xFF05070F),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onWake,
        child: LiveClock(builder: (context, now) {
          // Isi bergeser pelan tiap menit supaya layar tidak berbekas.
          final step = now.minute % 6;
          final shift = Offset(((step % 3) - 1) * 40.0, ((step ~/ 3) * 2 - 1) * 24.0);
          final hh = now.hour.toString().padLeft(2, '0');
          final mm = now.minute.toString().padLeft(2, '0');
          return Stack(children: [
            Center(
              child: Transform.translate(
                  offset: shift,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Opacity(
                        opacity: 0.6,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          ClipOval(child: Container(color: Colors.white, width: 36, height: 36, child: Image.asset('assets/img/logo.png'))),
                          const SizedBox(width: 12),
                          const Text('Cahaya Optima Karya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFC3CBE0))),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: hh),
                          const TextSpan(text: ':', style: TextStyle(color: Color(0xFF8A6A1F))),
                          TextSpan(text: mm),
                        ]),
                        style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w700, letterSpacing: -4, height: 1, color: Color(0xFF8A93AD), fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(height: 10),
                      Text('${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF7A849E))),
                      const SizedBox(height: 44),
                      SizedBox(
                        height: 190,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 700),
                          layoutBuilder: (current, previous) => Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                          child: quote == null ? const SizedBox.shrink() : _QuoteView(key: ValueKey(quote), quote: quote),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.touch_app_outlined, size: 22, color: Color(0xFF9AA6C7)),
                        SizedBox(width: 10),
                        Text('Ketuk layar untuk absen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF9AA6C7))),
                      ]),
                    ]),
                  ),
                ),
            ),
          ]);
        }),
      ),
    );
  }
}

class _QuoteView extends StatelessWidget {
  const _QuoteView({super.key, required this.quote});
  final Quote quote;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 4, height: 96, decoration: BoxDecoration(color: const Color(0xFF8A6A1F), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 20),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '“${quote.text}”',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 34, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, height: 1.35, color: Color(0xFFB9C1D6)),
          ),
          const SizedBox(height: 14),
          Text('— ${quote.author}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF8A6A1F))),
        ]),
      ),
    ]);
  }
}
