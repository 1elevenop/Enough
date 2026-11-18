import '../models/site_config.dart';

class UsageSession {
  const UsageSession(this.site, this.category, this.start, this.end);
  final String site;
  final RouteCategory category;
  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);
}

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// Portion of [s] that falls inside the calendar day containing [day].
Duration overlapWithDay(UsageSession s, DateTime day) {
  final from = dayStart(day);
  final to = DateTime(from.year, from.month, from.day + 1);
  final a = s.start.isAfter(from) ? s.start : from;
  final b = s.end.isBefore(to) ? s.end : to;
  return b.isAfter(a) ? b.difference(a) : Duration.zero;
}

Map<String, Duration> totalsBySite(Iterable<UsageSession> sessions, DateTime day) {
  final out = <String, Duration>{};
  for (final s in sessions) {
    final d = overlapWithDay(s, day);
    if (d > Duration.zero) out[s.site] = (out[s.site] ?? Duration.zero) + d;
  }
  return out;
}

Map<RouteCategory, Duration> totalsByCategory(
    Iterable<UsageSession> sessions, DateTime day) {
  final out = <RouteCategory, Duration>{};
  for (final s in sessions) {
    final d = overlapWithDay(s, day);
    if (d > Duration.zero) out[s.category] = (out[s.category] ?? Duration.zero) + d;
  }
  return out;
}

/// Share of tracked time spent on useful pages, ignoring neutral ones.
/// Returns null when there's no useful or scroll time to compare.
double? productiveRatio(Map<RouteCategory, Duration> byCat) {
  var useful = Duration.zero, scroll = Duration.zero;
  byCat.forEach((c, d) {
    if (c.productive == true) useful += d;
    if (c.productive == false) scroll += d;
  });
  final total = useful + scroll;
  if (total == Duration.zero) return null;
  return useful.inMilliseconds / total.inMilliseconds;
}

/// Consecutive days, ending yesterday (today counts if already within
/// limits), where every limited site stayed under its limit.
int underLimitStreak({
  required Iterable<UsageSession> sessions,
  required Map<String, int> limitsMinutes,
  required DateTime today,
  int maxDays = 365,
}) {
  final limited = {
    for (final e in limitsMinutes.entries)
      if (e.value > 0) e.key: Duration(minutes: e.value),
  };
  if (limited.isEmpty) return 0;
  final list = sessions.toList();
  final earliest = list.isEmpty
      ? dayStart(today)
      : dayStart(list.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b));

  bool ok(DateTime day) {
    final totals = totalsBySite(list, day);
    return limited.entries
        .every((e) => (totals[e.key] ?? Duration.zero) <= e.value);
  }

  var streak = ok(today) ? 1 : 0;
  for (var i = 1; i <= maxDays; i++) {
    final day = DateTime(today.year, today.month, today.day - i);
    if (day.isBefore(earliest)) break;
    if (!ok(day)) break;
    streak++;
  }
  return streak;
}

String formatDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  if (d.inMinutes > 0) return '${m}m';
  return '${d.inSeconds}s';
}
