// One-off: installs the launcher/splash PNGs from branding/ (the Affinity
// masters) into the places the Android build reads them from.
// Run with: flutter test tool/render_icon_test.dart
// then:     dart run flutter_launcher_icons
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _copies = {
  'branding/logo/enough-icon-1024.png': 'assets/icon/icon.png',
  'branding/android/foreground.png': 'assets/icon/foreground.png',
  'branding/android/monochrome.png': 'assets/icon/monochrome.png',
  'branding/android/splash_mark.png': 'android/app/src/main/res/drawable-nodpi/splash_mark.png',
};

void main() {
  test('install launcher icons from branding/', () {
    _copies.forEach((from, to) {
      File(to).createSync(recursive: true);
      File(from).copySync(to);
    });
  });
}
