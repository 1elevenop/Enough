import 'package:brainrot_wrapper/models/site_config.dart';
import 'package:brainrot_wrapper/services/limit_guard.dart';
import 'package:brainrot_wrapper/services/usage_stats.dart';
import 'package:flutter_test/flutter_test.dart';

UsageSession s(String site, RouteCategory c, DateTime a, Duration d) =>
    UsageSession(site, c, a, a.add(d));

void main() {
  final day = DateTime(2026, 11, 17);

  group('usage stats', () {
    test('session across midnight is split between days', () {
      final x = s('yt', RouteCategory.feed, DateTime(2026, 11, 16, 23, 50),
          const Duration(minutes: 20));
      expect(overlapWithDay(x, day), const Duration(minutes: 10));
      expect(overlapWithDay(x, DateTime(2026, 11, 16)), const Duration(minutes: 10));
    });

    test('totals per site and productive ratio', () {
      final list = [
        s('yt', RouteCategory.feed, DateTime(2026, 11, 17, 10), const Duration(minutes: 30)),
        s('ig', RouteCategory.messages, DateTime(2026, 11, 17, 11), const Duration(minutes: 10)),
        s('ig', RouteCategory.profile, DateTime(2026, 11, 17, 12), const Duration(minutes: 5)),
      ];
      expect(totalsBySite(list, day),
          {'yt': const Duration(minutes: 30), 'ig': const Duration(minutes: 15)});
      expect(productiveRatio(totalsByCategory(list, day)), closeTo(0.25, 1e-9));
      expect(productiveRatio({}), isNull);
    });

    test('streak counts consecutive days under limit', () {
      final list = [
        // 3 days ago: over limit
        s('yt', RouteCategory.feed, DateTime(2026, 11, 14, 10), const Duration(minutes: 50)),
        s('yt', RouteCategory.feed, DateTime(2026, 11, 15, 10), const Duration(minutes: 10)),
        s('yt', RouteCategory.feed, DateTime(2026, 11, 16, 10), const Duration(minutes: 20)),
        s('yt', RouteCategory.feed, DateTime(2026, 11, 17, 10), const Duration(minutes: 5)),
      ];
      expect(
          underLimitStreak(sessions: list, limitsMinutes: {'yt': 30}, today: day), 3);
      expect(underLimitStreak(sessions: list, limitsMinutes: {'yt': 0}, today: day), 0);
    });
  });

  group('limit status', () {
    test('ok, warning, blocked', () {
      expect(limitStatus(used: const Duration(minutes: 5), limitMinutes: 20, snoozed: false).level,
          LimitLevel.ok);
      expect(limitStatus(used: const Duration(minutes: 17), limitMinutes: 20, snoozed: false).level,
          LimitLevel.warning);
      expect(limitStatus(used: const Duration(minutes: 20), limitMinutes: 20, snoozed: false).level,
          LimitLevel.blocked);
      expect(limitStatus(used: Duration.zero, limitMinutes: 0, snoozed: false).level,
          LimitLevel.none);
    });

    test('snooze adds five minutes', () {
      final st = limitStatus(
          used: const Duration(minutes: 21), limitMinutes: 20, snoozed: true);
      expect(st.level, LimitLevel.warning);
      expect(st.remaining, const Duration(minutes: 4));
    });
  });

  group('focus window', () {
    final weekdays = {1, 2, 3, 4, 5};
    test('daytime window on a weekday', () {
      // 2026-11-17 is a Tuesday.
      expect(
          inFocusWindow(
              now: DateTime(2026, 11, 17, 10), startMinute: 540, endMinute: 1020, weekdays: weekdays),
          isTrue);
      expect(
          inFocusWindow(
              now: DateTime(2026, 11, 17, 18), startMinute: 540, endMinute: 1020, weekdays: weekdays),
          isFalse);
      expect(
          inFocusWindow(
              now: DateTime(2026, 11, 22, 10), startMinute: 540, endMinute: 1020, weekdays: weekdays),
          isFalse); // Sunday
    });

    test('overnight window uses the start day', () {
      // Friday 23:00 -> in; Saturday 02:00 belongs to Friday's window -> in.
      expect(
          inFocusWindow(
              now: DateTime(2026, 11, 20, 23), startMinute: 1320, endMinute: 420, weekdays: weekdays),
          isTrue);
      expect(
          inFocusWindow(
              now: DateTime(2026, 11, 21, 2), startMinute: 1320, endMinute: 420, weekdays: weekdays),
          isTrue);
      // Monday 02:00 belongs to Sunday's window -> out.
      expect(
          inFocusWindow(
              now: DateTime(2026, 11, 23, 2), startMinute: 1320, endMinute: 420, weekdays: weekdays),
          isFalse);
    });
  });
}
