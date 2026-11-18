import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';
import 'services/native.dart';
import 'services/reminders.dart';
import 'services/settings_store.dart';
import 'services/trackers.dart';
import 'services/usage_tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    // Lets chrome://inspect attach to pages while tuning selectors.
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  final settings = await SettingsStore.load();
  await UsageTracker.load();
  await TrackerList.load();
  if (settings.screenPrivacy) await Native.setSecure(true);
  await Reminders.init();
  if (settings.weeklyReport) {
    Reminders.setWeekly(true).ignore();
  }
  runApp(const EnoughApp());
}

class EnoughApp extends StatelessWidget {
  const EnoughApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enough',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: SettingsStore.instance.onboarded
          ? const DashboardScreen()
          : const OnboardingScreen(),
    );
  }
}
