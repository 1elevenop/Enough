import 'dart:convert';
import 'dart:typed_data';

import 'package:brainrot_wrapper/services/pin_hash.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('PBKDF2 matches RFC 7914 test vector', () {
    final dk = PinHash.pbkdf2(utf8.encode('passwd'), utf8.encode('salt'), 1, 64);
    expect(_hex(dk),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783');
  });

  test('v2 hash verifies the right PIN only', () {
    final h = PinHash.create('1234', iterations: 1000);
    expect(h.startsWith('v2\$1000\$'), isTrue);
    expect(PinHash.isLegacy(h), isFalse);
    expect(PinHash.verifyPin('1234', h), isTrue);
    expect(PinHash.verifyPin('1235', h), isFalse);
  });

  test('salt makes equal PINs hash differently', () {
    expect(PinHash.create('1234', iterations: 10), isNot(PinHash.create('1234', iterations: 10)));
    final fixed = Uint8List(16);
    expect(PinHash.create('1234', iterations: 10, salt: fixed),
        PinHash.create('1234', iterations: 10, salt: fixed));
  });

  test('legacy sha256 hashes still verify', () {
    final legacy = sha256.convert(utf8.encode('focusfeed:4321')).toString();
    expect(PinHash.isLegacy(legacy), isTrue);
    expect(PinHash.verifyPin('4321', legacy), isTrue);
    expect(PinHash.verifyPin('0000', legacy), isFalse);
  });

  test('malformed stored values are rejected', () {
    for (final s in ['v2\$', 'v2\$x\$a\$b', 'v2\$0\$AAAA\$AAAA', 'v2\$10\$!!\$AAAA']) {
      expect(PinHash.verifyPin('1234', s), isFalse, reason: s);
    }
  });

  test('lockout: free tries, then doubling, capped', () {
    expect(PinLockout.after(4), Duration.zero);
    expect(PinLockout.after(5), const Duration(seconds: 30));
    expect(PinLockout.after(6), const Duration(seconds: 60));
    expect(PinLockout.after(7), const Duration(seconds: 120));
    expect(PinLockout.after(50), const Duration(minutes: 15));
  });
}
