import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/site_config.dart';
import '../services/settings_store.dart';
import '../services/usage_stats.dart';
import '../services/usage_tracker.dart';
import '../sites/registry.dart';
import '../theme.dart';
import '../widgets/site_glyph.dart';

const _useful = Color(0xFF2FB574);

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<UsageSession>? _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final from = dayStart(now).subtract(const Duration(days: 60));
    final list = await UsageTracker.instance
        .sessionsBetween(from, dayStart(now).add(const Duration(days: 1)));
    if (mounted) setState(() => _sessions = UsageTracker.instance.liveSessions(list));
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: sessions == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(onRefresh: _load, child: _body(context, sessions)),
    );
  }

  Widget _body(BuildContext context, List<UsageSession> sessions) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final bySite = totalsBySite(sessions, now);
    final byCat = totalsByCategory(sessions, now);
    final total = bySite.values.fold(Duration.zero, (a, b) => a + b);
    final ratio = productiveRatio(byCat);
    final streak = underLimitStreak(
      sessions: sessions,
      limitsMinutes: {
        for (final id in SettingsStore.instance.homeSites)
          id: SettingsStore.instance.dailyLimit(id),
      },
      today: now,
    );
    final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
    final week = [for (final d in days) totalsBySite(sessions, d)];
    final weekTotal = week.expand((m) => m.values).fold(Duration.zero, (a, b) => a + b);
    final usedSites = sites.where((s) => week.any((m) => (m[s.id] ?? Duration.zero) > Duration.zero)).toList();
    final maxSite = bySite.values.fold(Duration.zero, (a, b) => a > b ? a : b);

    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
      Center(child: Text(formatDuration(total), style: text.displaySmall)),
      const SizedBox(height: 6),
      Center(
        child: Text('on socials today', style: text.bodyMedium?.copyWith(color: t.muted)),
      ),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Pill(label: 'Useful', value: ratio == null ? '–' : '${(ratio * 100).round()}%', dot: _useful),
        const SizedBox(width: 8),
        _Pill(label: 'Streak', value: '$streak ${streak == 1 ? 'day' : 'days'}', dot: Tokens.accent),
      ]),
      const SizedBox(height: 10),
      Center(
        child: Text(
          ratio == null
              ? 'Useful time is messaging and searching, compared with scrolling.'
              : ratio >= .6
                  ? 'Mostly messages and search today. That\'s the goal.'
                  : 'Feeds took most of today. Try a lower limit or focus hours.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: t.muted),
        ),
      ),
      const SizedBox(height: 24),
      _Section(
        title: 'Today',
        child: bySite.isEmpty
            ? _empty(context)
            : Column(children: [
                for (final site in sites)
                  if ((bySite[site.id] ?? Duration.zero) > Duration.zero)
                    _SiteRow(site: site, value: bySite[site.id]!, max: maxSite),
              ]),
      ),
      const SizedBox(height: 12),
      _Section(
        title: 'Where the time went',
        child: byCat.isEmpty
            ? _empty(context)
            : Column(children: [
                _StackBar(byCat: byCat),
                const SizedBox(height: 14),
                for (final c in RouteCategory.values)
                  if ((byCat[c] ?? Duration.zero) > Duration.zero)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        _Dot(_catColor(c, t)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(c.label, style: text.bodyMedium)),
                        Text(formatDuration(byCat[c]!),
                            style: text.bodyMedium?.copyWith(color: t.muted)),
                      ]),
                    ),
              ]),
      ),
      const SizedBox(height: 12),
      _Section(
        title: 'This week',
        trailing: formatDuration(weekTotal),
        child: Column(children: [
          SizedBox(height: 180, child: _WeekChart(days: days, week: week)),
          if (usedSites.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 14, runSpacing: 6, children: [
              for (final s in usedSites)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _Dot(s.color),
                  const SizedBox(width: 6),
                  Text(s.name, style: text.bodySmall?.copyWith(color: t.muted)),
                ]),
            ]),
          ],
        ]),
      ),
    ]);
  }

  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Nothing yet today.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Tokens.of(context).muted)),
      );
}

Color _catColor(RouteCategory c, Tokens t) =>
    c.productive == true ? _useful : c.productive == false ? Tokens.danger : t.muted;

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Tokens.radius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: text.titleMedium),
          const Spacer(),
          if (trailing != null)
            Text(trailing!, style: text.bodyMedium?.copyWith(color: t.muted)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value, required this.dot});
  final String label, value;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Dot(dot),
        const SizedBox(width: 8),
        Text(label, style: text.bodySmall?.copyWith(color: t.muted)),
        const SizedBox(width: 6),
        Text(value, style: text.labelLarge?.copyWith(fontSize: 13)),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
      width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.site, required this.value, required this.max});
  final SiteConfig site;
  final Duration value, max;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    final frac = max.inSeconds == 0 ? 0.0 : value.inSeconds / max.inSeconds;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SiteGlyph(site: site, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(site.name, style: text.bodyMedium)),
              Text(formatDuration(value), style: text.bodyMedium?.copyWith(color: t.muted)),
            ]),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (_, c) => Stack(children: [
                Container(
                    height: 5,
                    decoration: BoxDecoration(
                        color: t.surfaceSoft, borderRadius: BorderRadius.circular(3))),
                Container(
                  height: 5,
                  width: c.maxWidth * frac,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                        colors: site.gradient.length > 1 ? site.gradient : [site.color, site.color]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _StackBar extends StatelessWidget {
  const _StackBar({required this.byCat});
  final Map<RouteCategory, Duration> byCat;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final total = byCat.values.fold(0, (a, d) => a + d.inSeconds);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(children: [
          for (final c in RouteCategory.values)
            if ((byCat[c]?.inSeconds ?? 0) > 0)
              Expanded(
                flex: (byCat[c]!.inSeconds * 1000 ~/ (total == 0 ? 1 : total)).clamp(1, 1000),
                child: Container(
                  margin: const EdgeInsets.only(right: 2),
                  color: _catColor(c, t),
                ),
              ),
        ]),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days, required this.week});
  final List<DateTime> days;
  final List<Map<String, Duration>> week;

  static const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    double minutes(Duration d) => d.inSeconds / 60;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < days.length; i++) {
      var acc = 0.0;
      final stack = <BarChartRodStackItem>[];
      for (final s in sites) {
        final m = minutes(week[i][s.id] ?? Duration.zero);
        if (m <= 0) continue;
        stack.add(BarChartRodStackItem(acc, acc + m, s.color));
        acc += m;
      }
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: acc,
          width: 22,
          rodStackItems: stack,
          color: t.surfaceSoft,
          borderRadius: BorderRadius.circular(7),
        ),
      ]));
    }
    return BarChart(BarChartData(
      barGroups: groups,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: t.line, strokeWidth: 1, dashArray: [3, 4]),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            getTitlesWidget: (v, meta) => Text('${v.round()}m',
                style: text.labelSmall?.copyWith(color: t.muted, fontSize: 10)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, meta) {
              final d = days[v.toInt()];
              final isToday = v.toInt() == days.length - 1;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_wd[d.weekday - 1],
                    style: text.labelSmall?.copyWith(
                        color: isToday ? t.ink : t.muted,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => t.ink,
          getTooltipItem: (group, _, rod, _) => BarTooltipItem(
            formatDuration(Duration(seconds: (rod.toY * 60).round())),
            TextStyle(color: t.canvas, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ),
    ));
  }
}
