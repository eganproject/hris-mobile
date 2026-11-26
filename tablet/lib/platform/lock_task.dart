import 'package:flutter/services.dart';

/// Sematkan aplikasi (screen pinning Android) supaya tablet tidak dipakai untuk
/// hal lain. Android menampilkan konfirmasi sekali saat pertama dipasang.
class LockTask {
  static const _channel = MethodChannel('hris_tablet/lock');

  static Future<bool> start() async => await _channel.invokeMethod<bool>('start').catchError((_) => false) ?? false;

  static Future<bool> stop() async => await _channel.invokeMethod<bool>('stop').catchError((_) => false) ?? false;

  static Future<bool> isLocked() async => await _channel.invokeMethod<bool>('isLocked').catchError((_) => false) ?? false;
}
