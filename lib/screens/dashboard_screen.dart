import 'package:flutter/material.dart';

import '../models/site_config.dart';
import '../services/limit_guard.dart';
import '../services/settings_store.dart';
import '../services/usage_stats.dart';
import '../services/usage_tracker.dart';
import '../sites/registry.dart';
import '../theme.dart';
import '../widgets/aura_tile.dart';
import '../widgets/enough_mark.dart';
import '../widgets/moment_card.dart';
import '../widgets/open_site.dart';
import '../widgets/pin_gate.dart';
import '../widgets/reels_pass_sheet.dart';
import '../widgets/site_glyph.dart';
import 'global_settings_screen.dart';
import 'insights_screen.dart';
import 'site_settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([UsageTracker.instance, SettingsStore.instance]),
          builder: (context, _) {
            final s = SettingsStore.instance;
            final home = [
              for (final id in s.homeSites) ?siteByIdOrNull(id),
            ];
            final today = UsageTracker.instance.todayBySite();
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _Header(home: home, today: today)),
              if (home.isEmpty)
                const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.86,
                    children: [
                      for (final site in home)
                        _HomeTile(site: site, used: today[site.id] ?? Duration.zero),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 22),
                    child: MomentCard(),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(0, 26, 0, 40),
                    child: Center(child: _AddButton(size: 48)),
                  ),
                ),
              ],
            ]);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- header --

class _Header extends StatelessWidget {
  const _Header({required this.home, required this.today});
  final List<SiteConfig> home;
  final Map<String, Duration> today;

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    final s = SettingsStore.instance;
    final now = DateTime.now();

    final used = home.fold(Duration.zero, (a, site) => a + (today[site.id] ?? Duration.zero));
    final budgetMin = home.fold(0, (a, site) => a + s.dailyLimit(site.id));
    final budget = Duration(minutes: budgetMin);
    final frac = budgetMin == 0 ? 0.0 : (used.inSeconds / budget.inSeconds).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(children: [
        Row(children: [
          Text('${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
              style: text.labelSmall?.copyWith(color: t.muted, letterSpacing: 0.4)),
          const Spacer(),
          _RoundIcon(
            icon: Icons.bar_chart_rounded,
            tooltip: 'Insights',
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const InsightsScreen())),
          ),
          const SizedBox(width: 8),
          _RoundIcon(
            icon: Icons.tune_rounded,
            tooltip: 'Settings',
            onTap: () => openGlobalSettings(context),
          ),
        ]),
        const SizedBox(height: 28),
        const EnoughMark(size: 44),
        const SizedBox(height: 14),
        Text('Enough.', style: text.displaySmall),
        const SizedBox(height: 10),
        Text(
          'Your socials, without the scroll.\nOpen what you need, nothing more.',
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: t.muted, height: 1.35),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: 104,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 4,
              backgroundColor: t.line,
              color: frac >= 1 ? Tokens.danger : Tokens.accent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          used == Duration.zero
              ? 'Nothing opened today'
              : budgetMin == 0
                  ? '${formatDuration(used)} today'
                  : '${formatDuration(used)} of ${formatDuration(budget)} today',
          style: text.labelSmall?.copyWith(color: t.muted),
        ),
      ]),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 19, color: t.ink)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ home tile --

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.site, required this.used});
  final SiteConfig site;
  final Duration used;

  @override
  Widget build(BuildContext context) {
    final s = SettingsStore.instance;
    final now = DateTime.now();
    final limit = s.dailyLimit(site.id);
    final status = limitStatus(
        used: used, limitMinutes: limit, snoozed: s.snoozeUsed(site.id, now));
    final inFocus = s.focusEnabled &&
        s.focusSites.contains(site.id) &&
        inFocusWindow(
            now: now, startMinute: s.focusStart, endMinute: s.focusEnd, weekdays: s.focusDays);
    final focusLocked = inFocus && s.focusMode == FocusMode.lock;
    final limitLocked = status.level == LimitLevel.blocked;

    String caption;
    if (focusLocked) {
      caption = 'Focus until ${_fmt(s.focusEnd)}';
    } else if (limitLocked) {
      caption = 'Opens again tomorrow';
    } else if (inFocus) {
      caption = 'Messages only';
    } else if (limit == 0) {
      caption = used == Duration.zero ? 'No limit' : '${formatDuration(used)} today';
    } else if (used == Duration.zero) {
      caption = '$limit min a day';
    } else {
      caption = '${formatDuration(status.remaining)} left today';
    }

    return AuraTile(
      site: site,
      caption: caption,
      locked: focusLocked || limitLocked,
      warning: status.level == LimitLevel.warning,
      progress: limit == 0 ? null : (used.inSeconds / (limit * 60)).clamp(0.0, 1.0),
      onTap: () => openSite(context, site),
      onLongPress: () => _tileMenu(context, site),
    );
  }

  static String _fmt(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

Future<void> _tileMenu(BuildContext context, SiteConfig site) {
  final t = Tokens.of(context);
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SiteGlyph(site: site, size: 52),
          const SizedBox(height: 12),
          Text(site.name, style: Theme.of(ctx).textTheme.titleLarge),
          if (site.tagline.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(site.tagline,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: t.muted)),
            ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.arrow_outward_rounded),
            title: const Text('Open'),
            onTap: () {
              Navigator.pop(ctx);
              openSite(context, site);
            },
          ),
          if (site.shortVideo != null)
            ListTile(
              leading: const Icon(Icons.hourglass_bottom_rounded),
              title: Text(reelsPassLabel(DateTime.now())),
              onTap: () {
                Navigator.pop(ctx);
                openReelsPass(context);
              },
            ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Limits and filters'),
            onTap: () async {
              Navigator.pop(ctx);
              if (!await requireUnlock(context) || !context.mounted) return;
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SiteSettingsScreen(site: site)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline_rounded, color: Tokens.danger),
            title: const Text('Remove from home', style: TextStyle(color: Tokens.danger)),
            onTap: () async {
              Navigator.pop(ctx);
              if (!await requireUnlock(context)) return;
              await SettingsStore.instance.removeHomeSite(site.id);
            },
          ),
        ]),
      ),
    ),
  );
}

// ----------------------------------------------------------- empty state --

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const _AddButton(size: 60),
        const SizedBox(height: 16),
        Text('Add your socials', style: text.titleMedium),
        const SizedBox(height: 4),
        Text('Only the ones you actually need.',
            style: text.bodySmall?.copyWith(color: t.muted)),
      ]),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: t.surface,
        shape: CircleBorder(side: BorderSide(color: t.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showAddSocialSheet(context),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.add_rounded, size: size * 0.42, color: t.ink),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- add sheet --

Future<void> showAddSocialSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddSheet(),
    );

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    final s = SettingsStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final added = s.homeSites.toSet();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Add a social', style: text.headlineSmall),
              const SizedBox(height: 6),
              Text('Each one opens without its feed.',
                  style: text.bodyMedium?.copyWith(color: t.muted)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final site in sites)
                      _AddRow(site: site, added: added.contains(site.id)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.site, required this.added});
  final SiteConfig site;
  final bool added;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final s = SettingsStore.instance;
    return InkWell(
      onTap: () async {
        if (!added) {
          await s.addHomeSite(site.id);
          if (site.note != null && context.mounted) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Before you open ${site.name}'),
                content: Text(site.note!),
                actions: [
                  FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
                ],
              ),
            );
          }
        } else if (await requireUnlock(context)) {
          await s.removeHomeSite(site.id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(children: [
          SiteGlyph(site: site, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(site.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(site.tagline,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted)),
            ]),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: added ? t.ink : Colors.transparent,
              border: Border.all(color: added ? t.ink : t.line, width: 1.5),
            ),
            child: Icon(added ? Icons.check_rounded : Icons.add_rounded,
                size: 17, color: added ? t.canvas : t.ink),
          ),
        ]),
      ),
    );
  }
}
