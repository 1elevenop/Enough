import 'package:brainrot_wrapper/content/awareness.dart';
import 'package:brainrot_wrapper/models/site_config.dart';
import 'package:brainrot_wrapper/services/usage_stats.dart';
import 'package:flutter_test/flutter_test.dart';

UsageSession s(DateTime start, int minutes) =>
    UsageSession('x', RouteCategory.feed, start, start.add(Duration(minutes: minutes)));

void main() {
  final now = DateTime(2026, 11, 18, 20);

  test('days a year at this week\'s pace', () {
    // 60 min a day for 7 days = 420 min/week -> 420*52/1440 = 15.2 -> 15 days.
    final sessions = [for (var i = 0; i < 7; i++) s(DateTime(2026, 11, 18 - i, 9), 60)];
    expect(lifeMath(sessions, now).first, 'At this week\'s pace: 15 days a year on socials.');
  });

  test('compares with last week', () {
    final sessions = [
      s(DateTime(2026, 11, 17, 9), 30), // this week
      s(DateTime(2026, 11, 10, 9), 50), // last week
    ];
    expect(lifeMath(sessions, now), contains('You\'ve spent 20 fewer minutes than last week.'));
  });

  test('nothing to say without data', () {
    expect(lifeMath(const [], now), isEmpty);
  });

  test('every fact has a source, every quote an author', () {
    expect(facts.every((f) => f.source.isNotEmpty), isTrue);
    expect(quotes.every((q) => q.author.isNotEmpty && q.work.isNotEmpty), isTrue);
  });
}
