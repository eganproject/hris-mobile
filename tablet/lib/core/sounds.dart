import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Suara saat absen berhasil (dibuat di ElevenLabs, disetujui Ega 2026-11-27):
/// masuk = "Bekerja yang keras ya!", pulang = "Terima kasih, hati-hati di jalan."
class Sounds {
  Sounds._();
  static final Sounds instance = Sounds._();

  final AudioPlayer _player = AudioPlayer(playerId: 'absen');

  Future<void> init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('suara: $e');
    }
  }

  /// [type]: in | out. Gagal memutar suara tidak boleh mengganggu absen.
  Future<void> clocked(String type) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(type == 'in' ? 'sounds/masuk.mp3' : 'sounds/pulang.mp3'));
    } catch (e) {
      debugPrint('suara: $e');
    }
  }
}
