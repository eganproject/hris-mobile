import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hris_tablet/core/models.dart';
import 'package:hris_tablet/ui/screens/rest_screen.dart';

void main() {
  test('berkas kutipan berisi 100 kutipan lengkap dengan tokohnya', () {
    final quotes = parseQuotes(File('assets/quotes/kutipan.txt').readAsStringSync());
    expect(quotes, hasLength(100));
    for (final q in quotes) {
      expect(q.text, isNotEmpty);
      expect(q.author, isNotEmpty);
    }
    expect(quotes.map((q) => q.text).toSet(), hasLength(100));
  });

  test('baris kosong atau tanpa tokoh dilewati', () {
    final quotes = parseQuotes('Kalimat satu.|Tokoh A\n\nTanpa tokoh\n Kalimat dua. | Tokoh B \n');
    expect(quotes.map((q) => '${q.text}/${q.author}'), ['Kalimat satu./Tokoh A', 'Kalimat dua./Tokoh B']);
  });

  test('lama layar istirahat ikut pengaturan dari web, bawaan 1 menit', () {
    expect(TabletSettings.fromJson(const {}).idleMinutes, 1);
    expect(TabletSettings.fromJson(const {'idle_minutes': 0}).idleMinutes, 0);
    expect(TabletSettings.fromJson(const {'idle_minutes': 5}).idleMinutes, 5);
  });
}
