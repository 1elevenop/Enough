import 'package:flutter/material.dart';

import '../services/settings_store.dart';
import '../theme.dart';
import '../widgets/daily_art.dart';
import '../widgets/enough_mark.dart';
import 'dashboard_screen.dart';

class _Page {
  const _Page(this.title, this.body);
  final String title, body;
}

const _pages = [
  _Page('These apps are built to keep you.',
      'The feed is designed to have no end. Every swipe is tuned to make the '
          'next one feel necessary.'),
  _Page('You have one life,\nand it\'s happening off-screen.',
      'The hours go somewhere. You get to choose where.'),
  _Page('Enough keeps what connects you\nand removes what consumes you.',
      'Messages, search and things you meant to do stay. The endless feed '
          'goes. Limits are the ones you set yourself.'),
  _Page('Set your limits.',
      'Pick the socials you actually need. Each one opens without its feed.'),
];

/// First-run introduction. Ends in the add-socials sheet.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _c = PageController();
  int _i = 0;

  bool get _last => _i == _pages.length - 1;

  Future<void> _finish() async {
    await SettingsStore.instance.setOnboarded();
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    // Open the add sheet once the home screen is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = nav.context;
      if (ctx.mounted) showAddSocialSheet(ctx);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: DailyArt(seed: 7 + _i)),
        SafeArea(
          child: Column(children: [
            Expanded(
              child: PageView.builder(
                controller: _c,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const EnoughMark(size: 72),
                    const SizedBox(height: 32),
                    Text(_pages[i].title,
                        textAlign: TextAlign.center, style: text.headlineMedium),
                    const SizedBox(height: 14),
                    Text(_pages[i].body,
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(color: t.muted, height: 1.4)),
                  ]),
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _i ? t.ink : t.muted.withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _last
                      ? _finish
                      : () => _c.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic),
                  child: Text(_last ? 'Choose my socials' : 'Next'),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
