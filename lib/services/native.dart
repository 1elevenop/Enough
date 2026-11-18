import 'package:flutter/services.dart';

/// Small platform calls handled in MainActivity.kt.
class Native {
  static const _ch = MethodChannel('focusfeed/webview');

  static Future<void> setSecure(bool on) async {
    try {
      await _ch.invokeMethod('setSecure', on);
    } on PlatformException {
      // Older Android or no activity yet; nothing to do.
    } on MissingPluginException {
      // Tests and non-Android platforms.
    }
  }

  /// `(mode, hostname)`; mode is `off`, `opportunistic`, `hostname` or null
  /// when Android doesn't expose it.
  static Future<(String?, String?)> privateDns() async {
    try {
      final m = await _ch.invokeMapMethod<String, String?>('privateDns');
      return (m?['mode'], m?['specifier']);
    } on PlatformException {
      return (null, null);
    } on MissingPluginException {
      return (null, null);
    }
  }

  static Future<bool> openNetworkSettings() async {
    try {
      return await _ch.invokeMethod<bool>('openNetworkSettings') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
