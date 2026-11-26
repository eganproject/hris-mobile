import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Periksa PIN terhadap hash dari server: pbkdf2_sha256$iterasi$salt$hash
/// (sama dengan App\Support\TabletPin di HRIS). Dipakai untuk PIN HR tablet dan
/// PIN cadangan karyawan, termasuk saat internet putus.
bool verifyPin(String pin, String? stored) {
  if (stored == null) return false;
  final parts = stored.split(r'$');
  if (parts.length != 4 || parts[0] != 'pbkdf2_sha256') return false;
  final iterations = int.tryParse(parts[1]) ?? 0;
  if (iterations < 1) return false;
  try {
    final salt = base64Decode(parts[2]);
    final expected = base64Decode(parts[3]);
    final got = pbkdf2Sha256(utf8.encode(pin), salt, iterations, expected.length);
    if (got.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < got.length; i++) {
      diff |= got[i] ^ expected[i];
    }
    return diff == 0;
  } catch (_) {
    return false;
  }
}

Uint8List pbkdf2Sha256(List<int> password, List<int> salt, int iterations, int length) {
  final hmac = Hmac(sha256, password);
  final out = BytesBuilder();
  var block = 1;
  while (out.length < length) {
    final first = hmac.convert([...salt, (block >> 24) & 0xff, (block >> 16) & 0xff, (block >> 8) & 0xff, block & 0xff]).bytes;
    final acc = Uint8List.fromList(first);
    var u = first;
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < acc.length; j++) {
        acc[j] ^= u[j];
      }
    }
    out.add(acc);
    block++;
  }
  return Uint8List.fromList(out.toBytes().sublist(0, length));
}
