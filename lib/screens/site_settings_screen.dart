import 'package:flutter/material.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';
import '../services/settings_store.dart';

/// Per-site toggles and daily limit. Callers gate this behind the PIN.
class SiteSettingsScreen extends StatelessWidget {
  const SiteSettingsScreen({super.key, required this.site});
  final SiteConfig site;

  static const _groups = {
    ToggleGroup.distraction: 'Hide distractions',
    ToggleGroup.wellbeing: 'Wellbeing',
    ToggleGroup.filter: 'Content filter',
  };

  @override
  Widget build(BuildContext context) {
    final s = SettingsStore.instance;
    return Scaffold(
      appBar: AppBar(title: Text('${site.name} settings')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final limit = s.dailyLimit(site.id);
          if (site.isExternal) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text(site.note ?? 'Opens the ${site.name} app.'),
              const SizedBox(height: 12),
              const Text('The intent prompt and focus hours still apply before '
                  'the app opens. In "Locked" focus mode it won\'t open at all.'),
            ]);
          }
          return ListView(children: [
            _Header('Daily limit'),
            ListTile(
              title: Text(limit == 0 ? 'No limit' : '$limit minutes a day'),
              subtitle: Slider(
                value: limit.toDouble(),
                min: 0,
                max: 120,
                divisions: 24,
                label: limit == 0 ? 'Off' : '$limit min',
                onChanged: (v) => s.setDailyLimit(site.id, v.round()),
              ),
            ),
            for (final g in _groups.entries) ...[
              if (site.allToggles.any((t) => t.group == g.key)) _Header(g.value),
              for (final t in site.allToggles.where((t) => t.group == g.key))
                SwitchListTile(
                  title: Text(t.label),
                  subtitle: t.description.isEmpty ? null : Text(t.description),
                  value: s.isEnabled(site, t),
                  onChanged: (v) => s.setEnabled(site, t, v),
                ),
            ],
            if (site.note != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(site.note!, style: Theme.of(context).textTheme.bodySmall),
              ),
          ]);
        },
      ),
    );
  }
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
