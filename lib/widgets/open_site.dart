import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/site_config.dart';
import '../screens/webview_screen.dart';
import '../services/limit_guard.dart';
import '../services/settings_store.dart';
import '../theme.dart';
import 'site_glyph.dart';
import 'quote_line.dart';

enum OpenIntent { message, search, post, browse }

/// Opens a site through the friction steps: focus hours, then the intent
/// prompt (with a breathing pause for "just browsing").
Future<void> openSite(BuildContext context, SiteConfig site, {String? url}) async {
  final s = SettingsStore.instance;
  final focusOn = s.focusEnabled &&
      s.focusSites.contains(site.id) &&
      inFocusWindow(
        now: DateTime.now(),
        startMinute: s.focusStart,
        endMinute: s.focusEnd,
        weekdays: s.focusDays,
      );

  if (focusOn && s.focusMode == FocusMode.lock) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_clock),
        title: Text('${site.name} is locked'),
        content: Text('It\'s focus time until ${_fmt(s.focusEnd)}. '
            'Come back after that.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    return;
  }

  var target = url;
  Duration? session;
  if (url == null && s.intentPrompt) {
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IntentSheet(site: site),
    );
    if (choice == null || !context.mounted) return;
    session = choice.session;
    switch (choice.intent) {
      case OpenIntent.message:
        target = site.messagesRoute;
      case OpenIntent.search:
        if (site.searchRoute != null) {
          final q = await _askQuery(context, site);
          if (q == null || !context.mounted) return;
          target = site.searchRoute!.replaceAll('{q}', Uri.encodeQueryComponent(q));
        }
      case OpenIntent.post:
        break;
      case OpenIntent.browse:
        final go = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _BreathingDialog(seconds: s.breathingSeconds),
        );
        if (go != true || !context.mounted) return;
    }
  }

  if (!context.mounted) return;
  final app = site.externalApp;
  if (app != null) {
    await _launchExternal(context, site, app);
    return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WebViewScreen(
        site: site,
        initialUrl: target,
        sessionLength: session,
        messagesOnly: focusOn,
      ),
    ),
  );
}

/// Opens the native app, or its Play Store page when it isn't installed.
Future<void> _launchExternal(BuildContext context, SiteConfig site, ExternalApp app) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(app.launchUrl),
        mode: LaunchMode.externalNonBrowserApplication);
  } catch (_) {
    opened = false;
  }
  if (opened) {
    await SettingsStore.instance.recordOpen(site.id, DateTime.now());
    return;
  }
  messenger.showSnackBar(SnackBar(
    content: Text('${site.name} isn\'t installed. Opening the Play Store.'),
  ));
  await launchUrl(Uri.parse(app.storeUrl), mode: LaunchMode.externalApplication);
}

String _fmt(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

Future<String?> _askQuery(BuildContext context, SiteConfig site) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Search ${site.name}'),
      content: TextField(
        controller: c,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) => Navigator.pop(ctx, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? null : c.text.trim()),
          child: const Text('Search'),
        ),
      ],
    ),
  );
}

class _Choice {
  const _Choice(this.intent, this.session);
  final OpenIntent intent;
  final Duration? session;
}

class _IntentSheet extends StatefulWidget {
  const _IntentSheet({required this.site});
  final SiteConfig site;

  @override
  State<_IntentSheet> createState() => _IntentSheetState();
}

class _IntentSheetState extends State<_IntentSheet> {
  int? _minutes = 10;

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;

    Widget option(OpenIntent i, IconData icon, String label, String hint,
            {bool enabled = true}) =>
        Opacity(
          opacity: enabled ? 1 : .35,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Material(
              color: t.canvas,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: enabled
                    ? () => Navigator.pop(
                          context,
                          _Choice(i, _minutes == null ? null : Duration(minutes: _minutes!)),
                        )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: t.surface, shape: BoxShape.circle),
                      child: Icon(icon, size: 19, color: t.ink),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: text.titleMedium?.copyWith(fontSize: 15)),
                        Text(hint, style: text.bodySmall?.copyWith(color: t.muted)),
                      ]),
                    ),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: t.muted),
                  ]),
                ),
              ),
            ),
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SiteGlyph(site: site, size: 48),
          const SizedBox(height: 14),
          Text('Why ${site.name}, right now?', style: text.headlineSmall),
          const SizedBox(height: 6),
          Text('Pick a reason. It helps you leave on time.',
              style: text.bodyMedium?.copyWith(color: t.muted)),
          const SizedBox(height: 18),
          // A timer can't be enforced inside another app.
          if (!site.isExternal)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: t.canvas,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final m in [5, 10, 15, null])
                  GestureDetector(
                    onTap: () => setState(() => _minutes = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _minutes == m ? t.ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        m == null ? 'No timer' : '$m min',
                        style: text.labelLarge?.copyWith(
                          fontSize: 13,
                          color: _minutes == m ? t.canvas : t.ink,
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          if (site.note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 14, 32, 0),
              child: Text(site.note!,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: t.muted)),
            ),
          const SizedBox(height: 16),
          option(OpenIntent.message, Icons.chat_bubble_outline_rounded, 'Message someone',
              'Opens straight to your inbox',
              enabled: site.messagesRoute != null || site.isExternal),
          if (!site.isExternal)
            option(OpenIntent.search, Icons.search_rounded, 'Look something up',
                'Search, then get out', enabled: site.searchRoute != null),
          option(OpenIntent.post, Icons.add_rounded, 'Post or check notifications',
              'In and out'),
          option(OpenIntent.browse, Icons.spa_outlined, 'Just browsing',
              'A short pause first'),
        ]),
      ),
    );
  }
}

class _BreathingDialog extends StatefulWidget {
  const _BreathingDialog({required this.seconds});
  final int seconds;

  @override
  State<_BreathingDialog> createState() => _BreathingDialogState();
}

class _BreathingDialogState extends State<_BreathingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(seconds: 4))
    ..repeat(reverse: true);
  late int _left = widget.seconds;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 0) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    return Dialog.fullscreen(
      backgroundColor: t.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            const Spacer(flex: 3),
            SizedBox(
              width: 240,
              height: 240,
              child: AnimatedBuilder(
                animation: _a,
                builder: (_, _) {
                  final v = Curves.easeInOut.transform(_a.value);
                  return Stack(alignment: Alignment.center, children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        width: 120 + 90 * v,
                        height: 120 + 90 * v,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            Tokens.accent.withValues(alpha: .7),
                            const Color(0xFFFF8A65).withValues(alpha: 0),
                          ]),
                        ),
                      ),
                    ),
                    Text(_a.status == AnimationStatus.forward ? 'Breathe in' : 'Breathe out',
                        style: text.titleMedium?.copyWith(color: t.ink)),
                  ]);
                },
              ),
            ),
            const SizedBox(height: 24),
            Text('Just browsing?', style: text.headlineMedium),
            const SizedBox(height: 10),
            Text(
              'Is this how you want to spend the next few minutes?',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: t.muted),
            ),
            const SizedBox(height: 28),
            const QuoteLine(),
            const Spacer(flex: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("No, I'm good"),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _left > 0 ? null : () => Navigator.pop(context, true),
              child: Text(_left > 0 ? 'Continue in $_left' : 'Continue anyway',
                  style: text.labelLarge?.copyWith(color: t.muted)),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
