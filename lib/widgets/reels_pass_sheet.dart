import 'package:flutter/material.dart';

import '../services/reels_pass.dart';
import '../services/settings_store.dart';
import '../theme.dart';
import 'pin_gate.dart';

/// Label for the unlock entry point, e.g. "Reels pass" or "Available in 2h 41m".
String reelsPassLabel(DateTime now) => switch (SettingsStore.instance.reelsPass.status(now)) {
      PassLocked() => 'Reels pass',
      PassActive(:final remaining) => 'Reels pass · ${formatShort(remaining)} left',
      PassCooling(:final remaining) => 'Reels available in ${formatShort(remaining)}',
    };

/// Runs the unlock flow. Returns true when a new pass started or a running
/// pass was ended (the caller should rebuild its rules).
Future<bool> openReelsPass(BuildContext context) async {
  final s = SettingsStore.instance;
  final status = s.reelsPass.status(DateTime.now());
  switch (status) {
    case PassCooling(:final remaining):
      await _info(context,
          title: 'Reels are resting',
          body: 'Available in ${formatShort(remaining)}. '
              'The wait is part of the deal you made with yourself.');
      return false;
    case PassActive(:final remaining):
      final end = await _confirm(context,
          title: '${formatShort(remaining)} of Reels left',
          body: 'End the pass now? The ${s.reelsCooldownHours}-hour rest starts right away.',
          yes: 'End now',
          no: 'Keep watching');
      if (end != true) return false;
      await s.endReelsPass(DateTime.now());
      return true;
    case PassLocked():
      break;
  }

  if (!s.hasPin) {
    if (!context.mounted) return false;
    final pin = await askNewPin(context);
    if (pin == null) return false;
    await s.setPin(pin);
  } else {
    if (!context.mounted || !await requireUnlock(context)) return false;
  }
  if (!context.mounted) return false;
  final go = await _confirm(context,
      title: '${s.reelsPassMinutes} minutes of Reels',
      body: 'Then ${s.reelsCooldownHours} hours off. Reels, Shorts and '
          'Facebook Watch open everywhere until the timer ends.',
      yes: 'Start',
      no: 'Not now');
  if (go != true) return false;
  return s.startReelsPass(DateTime.now());
}

/// Shown when a pass runs out.
Future<void> showReelsTimeUp(BuildContext context) => _info(context,
    title: 'Reels time\'s up',
    body: 'That was the time you chose. Reels are resting for '
        '${SettingsStore.instance.reelsCooldownHours} hours.');

Future<void> _info(BuildContext context, {required String title, required String body}) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _PassSheet(
        title: title,
        body: body,
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))],
      ),
    );

Future<bool?> _confirm(BuildContext context,
        {required String title, required String body, required String yes, required String no}) =>
    showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => _PassSheet(title: title, body: body, actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(no)),
      ]),
    );

class _PassSheet extends StatelessWidget {
  const _PassSheet({required this.title, required this.body, required this.actions});
  final String title, body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = Tokens.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hourglass_bottom_rounded, size: 32, color: t.ink),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: text.titleLarge),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: t.muted)),
          const SizedBox(height: 20),
          for (final a in actions) SizedBox(width: double.infinity, child: a),
        ]),
      ),
    );
  }
}
