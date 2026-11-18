enum LimitLevel { none, ok, warning, blocked }

class LimitStatus {
  const LimitStatus(this.level, this.remaining, this.limit);
  final LimitLevel level;
  final Duration remaining;
  final Duration limit;
}

const snoozeExtra = Duration(minutes: 5);
const warnAt = 0.8;

/// [limitMinutes] of 0 means unlimited. A used snooze adds [snoozeExtra].
LimitStatus limitStatus({
  required Duration used,
  required int limitMinutes,
  required bool snoozed,
}) {
  if (limitMinutes <= 0) {
    return const LimitStatus(LimitLevel.none, Duration.zero, Duration.zero);
  }
  final limit = Duration(minutes: limitMinutes) + (snoozed ? snoozeExtra : Duration.zero);
  final remaining = limit - used;
  if (remaining <= Duration.zero) {
    return LimitStatus(LimitLevel.blocked, Duration.zero, limit);
  }
  final level = used.inMilliseconds >= limit.inMilliseconds * warnAt
      ? LimitLevel.warning
      : LimitLevel.ok;
  return LimitStatus(level, remaining, limit);
}

/// True when [now] falls in the focus window. Handles windows that cross
/// midnight (e.g. 22:00–07:00); [weekdays] uses DateTime.weekday (1 = Mon)
/// of the day the window started.
bool inFocusWindow({
  required DateTime now,
  required int startMinute,
  required int endMinute,
  required Set<int> weekdays,
}) {
  if (startMinute == endMinute) return false;
  final m = now.hour * 60 + now.minute;
  if (startMinute < endMinute) {
    return weekdays.contains(now.weekday) && m >= startMinute && m < endMinute;
  }
  if (m >= startMinute) return weekdays.contains(now.weekday);
  if (m < endMinute) {
    final yesterday = now.subtract(const Duration(days: 1)).weekday;
    return weekdays.contains(yesterday);
  }
  return false;
}
