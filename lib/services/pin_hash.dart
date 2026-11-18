import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PIN storage format: `v2$<iterations>$<salt b64>$<hash b64>`
/// (PBKDF2-HMAC-SHA256). Older installs stored `sha256('focusfeed:'+pin)`
/// as hex; [verifyPin] still accepts that so callers can migrate it.
class PinHash {
  static const iterations = 30000;
  static const _legacyPrefix = 'focusfeed:';

  static String create(String pin, {int iterations = iterations, Uint8List? salt}) {
    salt ??= _randomBytes(16);
    final dk = pbkdf2(utf8.encode(pin), salt, iterations, 32);
    return 'v2\$$iterations\$${base64.encode(salt)}\$${base64.encode(dk)}';
  }

  static bool isLegacy(String stored) => !stored.startsWith('v2\$');

  static bool verifyPin(String pin, String stored) {
    if (isLegacy(stored)) {
      final h = sha256.convert(utf8.encode('$_legacyPrefix$pin')).toString();
      return constantTimeEquals(utf8.encode(h), utf8.encode(stored));
    }
    final parts = stored.split('\$');
    if (parts.length != 4) return false;
    final n = int.tryParse(parts[1]);
    if (n == null || n < 1 || n > 10000000) return false;
    try {
      final salt = base64.decode(parts[2]);
      final want = base64.decode(parts[3]);
      final got = pbkdf2(utf8.encode(pin), salt, n, want.length);
      return constantTimeEquals(got, want);
    } on FormatException {
      return false;
    }
  }

  /// RFC 8018 PBKDF2 with HMAC-SHA256.
  static Uint8List pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    for (var block = 1; out.length < length; block++) {
      final u0 = hmac.convert([
        ...salt,
        (block >> 24) & 0xff, (block >> 16) & 0xff, (block >> 8) & 0xff, block & 0xff,
      ]).bytes;
      final t = Uint8List.fromList(u0);
      var u = u0;
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }
    return Uint8List.sublistView(out.toBytes(), 0, length);
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }
}

/// Wrong-PIN lockout: free tries, then 30 s doubling up to 15 min.
class PinLockout {
  static const freeTries = 5;
  static const base = Duration(seconds: 30);
  static const cap = Duration(minutes: 15);

  /// Lockout to apply after [failures] consecutive wrong PINs (zero if none).
  static Duration after(int failures) {
    if (failures < freeTries) return Duration.zero;
    final steps = min(failures - freeTries, 10);
    final d = base * pow(2, steps).toInt();
    return d > cap ? cap : d;
  }
}
