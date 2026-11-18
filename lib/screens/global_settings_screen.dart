import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/site_config.dart';
import '../services/reminders.dart';
import '../services/settings_store.dart';
import '../sites/registry.dart';
import '../widgets/pin_gate.dart';
import '../widgets/site_glyph.dart';
import 'privacy_screen.dart';
import 'why_enough_screen.dart';
import 'site_settings_screen.dart';

/// App-wide settings. Callers gate this behind the PIN.
class GlobalSettingsScreen extends StatelessWidget {
  const GlobalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(children: [
          const _Header('Your socials'),
          for (final site in _home(s))
            ListTile(
              leading: SiteGlyph(site: site, size: 36),
              title: Text(site.name),
              subtitle: Text(site.isExternal
                  ? 'Opens the app'
                  : s.dailyLimit(site.id) == 0
                      ? 'No limit'
                      : '${s.dailyLimit(site.id)} min a day'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SiteSettingsScreen(site: site))),
            ),
          if (_home(s).isEmpty)
            const ListTile(
              title: Text('None yet'),
              subtitle: Text('Add socials with the + on the home screen'),
            ),
          const _Header('Friction'),
          SwitchListTile(
            title: const Text('Ask why before opening a site'),
            subtitle: const Text('Pick a purpose and an optional session timer'),
            value: s.intentPrompt,
            onChanged: s.setIntentPrompt,
          ),
          ListTile(
            title: const Text('Breathing pause for "just browsing"'),
            subtitle: Slider(
              value: s.breathingSeconds.toDouble(),
              min: 3,
              max: 30,
              divisions: 9,
              label: '${s.breathingSeconds}s',
              onChanged: (v) => s.setBreathingSeconds(v.round()),
            ),
            trailing: Text('${s.breathingSeconds}s'),
          ),
          ListTile(
            title: const Text('Feed cap'),
            subtitle: Slider(
              value: s.feedCapCount.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              label: '${s.feedCapCount} posts',
              onChanged: (v) => s.setFeedCapCount(v.round()),
            ),
            trailing: Text('${s.feedCapCount}'),
          ),
          const _Header('Short videos'),
          ListTile(
            title: const Text('Reels pass length'),
            subtitle: Slider(
              value: s.reelsPassMinutes.toDouble().clamp(_minPass.toDouble(), 30),
              min: _minPass.toDouble(),
              max: 30,
              divisions: 30 - _minPass,
              label: '${s.reelsPassMinutes} min',
              onChanged: (v) => s.setReelsDurations(passMinutes: v.round()),
            ),
            trailing: Text('${s.reelsPassMinutes} min'),
          ),
          ListTile(
            title: const Text('Rest after a pass'),
            subtitle: Slider(
              value: s.reelsCooldownHours.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              label: '${s.reelsCooldownHours} h',
              onChanged: (v) => s.setReelsDurations(cooldownHours: v.round()),
            ),
            trailing: Text('${s.reelsCooldownHours} h'),
          ),
          const _Header('Focus hours'),
          SwitchListTile(
            title: const Text('Focus hours'),
            subtitle: Text(
                '${_fmt(s.focusStart)}–${_fmt(s.focusEnd)} on ${_days(s.focusDays)}'),
            value: s.focusEnabled,
            onChanged: (v) => s.setFocus(enabled: v),
          ),
          if (s.focusEnabled) ...[
            ListTile(
              title: const Text('Start'),
              trailing: Text(_fmt(s.focusStart)),
              onTap: () async {
                final t = await _pickTime(context, s.focusStart);
                if (t != null) s.setFocus(start: t);
              },
            ),
            ListTile(
              title: const Text('End'),
              trailing: Text(_fmt(s.focusEnd)),
              onTap: () async {
                final t = await _pickTime(context, s.focusEnd);
                if (t != null) s.setFocus(end: t);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 6, children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_dayNames[d - 1]),
                    selected: s.focusDays.contains(d),
                    onSelected: (on) => s.setFocus(
                        days: on ? ({...s.focusDays, d}) : ({...s.focusDays}..remove(d))),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<FocusMode>(
                segments: const [
                  ButtonSegment(
                      value: FocusMode.messagesOnly,
                      label: Text('Messages only'),
                      icon: Icon(Icons.chat)),
                  ButtonSegment(
                      value: FocusMode.lock, label: Text('Locked'), icon: Icon(Icons.lock)),
                ],
                selected: {s.focusMode},
                onSelectionChanged: (v) => s.setFocus(mode: v.first),
              ),
            ),
            for (final site in _home(s))
              CheckboxListTile(
                title: Text(site.name),
                value: s.focusSites.contains(site.id),
                onChanged: (on) => s.setFocus(
                    siteIds: on == true
                        ? ({...s.focusSites, site.id})
                        : ({...s.focusSites}..remove(site.id))),
              ),
          ],
          const _Header('Privacy'),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Privacy'),
            subtitle: const Text('Private DNS, trackers, screen privacy, site data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
          const _Header('Content filter'),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Blocked words'),
            subtitle: Text('${s.blocklist.length} words. Posts containing them are hidden.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const _BlocklistScreen())),
          ),
          const _Header('Lock'),
          ListTile(
            leading: const Icon(Icons.pin),
            title: Text(s.hasPin ? 'Change PIN' : 'Set a PIN'),
            subtitle: const Text('Protects limits, filters and focus hours'),
            onTap: () async {
              final pin = await askNewPin(context);
              if (pin != null) await s.setPin(pin);
            },
          ),
          if (s.hasPin) ...[
            SwitchListTile(
              title: const Text('Allow fingerprint / face unlock'),
              value: s.biometricUnlock,
              onChanged: s.setBiometricUnlock,
            ),
            ListTile(
              leading: const Icon(Icons.lock_open),
              title: const Text('Remove PIN'),
              onTap: () => s.setPin(null),
            ),
          ],
          const _Header('Reminders'),
          SwitchListTile(
            title: const Text('Weekly report reminder'),
            value: s.weeklyReport,
            onChanged: (v) async {
              await s.setWeeklyReport(v);
              await Reminders.setWeekly(v);
            },
          ),
          const _Header('About'),
          ListTile(
            leading: const Icon(Icons.local_cafe_outlined),
            title: const Text('Why Enough'),
            subtitle: const Text("What this app is for, and what it isn't"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const WhyEnoughScreen())),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  static List<SiteConfig> _home(SettingsStore s) => [
        for (final id in s.homeSites) ?siteByIdOrNull(id),
      ];

  /// Debug builds allow a 1-minute pass for testing expiry.
  static const _minPass = kDebugMode ? 1 : 5;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _days(Set<int> d) {
    if (d.length == 7) return 'every day';
    if (d.length == 5 && d.containsAll({1, 2, 3, 4, 5})) return 'weekdays';
    final l = d.toList()..sort();
    return l.map((i) => _dayNames[i - 1]).join(', ');
  }

  static String _fmt(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  static Future<int?> _pickTime(BuildContext context, int current) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }
}

class _BlocklistScreen extends StatefulWidget {
  const _BlocklistScreen();

  @override
  State<_BlocklistScreen> createState() => _BlocklistScreenState();
}

class _BlocklistScreenState extends State<_BlocklistScreen> {
  final _c = TextEditingController();
  final _s = SettingsStore.instance;

  void _add() {
    final words = _c.text.split(',');
    _s.setBlocklist([..._s.blocklist, ...words]);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Blocked words'), actions: [
          TextButton(
            onPressed: () => _s.setBlocklist(List.of(defaultBlocklist)),
            child: const Text('Reset'),
          ),
        ]),
        body: ListenableBuilder(
          listenable: _s,
          builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Posts, videos and comments containing these words are '
                'hidden. Add topics that pull you in too, like "prank" or "drama".'),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              decoration: InputDecoration(
                hintText: 'Add words, comma separated',
                suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _add),
              ),
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final w in _s.blocklist)
                InputChip(
                  label: Text(w),
                  onDeleted: () =>
                      _s.setBlocklist(_s.blocklist.where((x) => x != w).toList()),
                ),
            ]),
          ]),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

/// Opens global settings after the PIN check.
Future<void> openGlobalSettings(BuildContext context) async {
  if (!await requireUnlock(context) || !context.mounted) return;
  await Navigator.push(
      context, MaterialPageRoute(builder: (_) => const GlobalSettingsScreen()));
}
