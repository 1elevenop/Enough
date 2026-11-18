import '../services/usage_stats.dart';

/// A sourced fact. Every number has a source and year, checked against the
/// source before shipping.
class Fact {
  const Fact(this.text, this.source);
  final String text;
  final String source;
}

const facts = [
  Fact('The typical social media user spends 2 hours 23 minutes a day on it.',
      'DataReportal, Digital 2024 Global Overview (GWI data)'),
  Fact('Teens who spend more than 3 hours a day on social media face double the '
      'risk of depression and anxiety symptoms.',
      'U.S. Surgeon General advisory, 2023'),
  Fact('Nearly half of U.S. teens say they are online "almost constantly".',
      'Pew Research Center, 2024'),
  Fact('Limiting Facebook, Instagram and Snapchat to 10 minutes each a day for '
      'three weeks significantly reduced loneliness and depression.',
      'Hunt et al., Journal of Social and Clinical Psychology, 2018'),
  Fact('Four weeks without Facebook increased well-being and time spent with '
      'family and friends.',
      'Allcott et al., American Economic Review, 2020'),
];

/// Short lines from public-domain works and translations.
class Quote {
  const Quote(this.text, this.author, this.work);
  final String text, author, work;
}

const quotes = [
  Quote('It is not that we have a short space of time, but that we waste much of it.',
      'Seneca', 'On the Shortness of Life'),
  Quote('Life is long if you know how to use it.', 'Seneca', 'On the Shortness of Life'),
  Quote('Very little is needed to make a happy life.', 'Marcus Aurelius', 'Meditations'),
  Quote('Men are disturbed not by things, but by the views which they take of things.',
      'Epictetus', 'Enchiridion'),
  Quote('The cost of a thing is the amount of what I will call life which is '
      'required to be exchanged for it.', 'Henry David Thoreau', 'Walden'),
  Quote('Our life is frittered away by detail. Simplify, simplify.',
      'Henry David Thoreau', 'Walden'),
  Quote('All the unhappiness of men arises from one single fact, that they cannot '
      'stay quietly in their own chamber.', 'Blaise Pascal', 'Pensées'),
  Quote('He who is satisfied with his lot is rich.', 'Lao Tzu', 'Tao Te Ching'),
];

/// Same quote all day, a different one tomorrow.
Quote quoteOfDay(DateTime now) => quotes[_dayIndex(now) % quotes.length];

int _dayIndex(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

int daySeed(DateTime now) => _dayIndex(now);

/// "Life math" lines computed from the user's own sessions over the last
/// two weeks. Empty when there isn't a full week of data yet.
List<String> lifeMath(List<UsageSession> sessions, DateTime now) {
  final today = dayStart(now);
  Duration window(int fromDaysAgo, int toDaysAgo) {
    var total = Duration.zero;
    for (var i = toDaysAgo; i < fromDaysAgo; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      for (final s in sessions) {
        total += overlapWithDay(s, day);
      }
    }
    return total;
  }

  final thisWeek = window(7, 0);
  final lastWeek = window(14, 7);
  final out = <String>[];
  if (thisWeek > Duration.zero) {
    // Days per year at this week's pace, rounded to whole days.
    final daysPerYear = (thisWeek.inMinutes * 52 / (60 * 24)).round();
    if (daysPerYear >= 1) {
      out.add('At this week\'s pace: $daysPerYear '
          '${daysPerYear == 1 ? 'day' : 'days'} a year on socials.');
    } else {
      out.add('At this week\'s pace: less than a day a year on socials.');
    }
  }
  if (lastWeek > Duration.zero && thisWeek > Duration.zero) {
    final diff = lastWeek - thisWeek;
    if (diff.inMinutes >= 1) {
      out.add('You\'ve spent ${diff.inMinutes} fewer minutes than last week.');
    } else if (diff.inMinutes <= -1) {
      out.add('${-diff.inMinutes} more minutes than last week. Tomorrow is a fresh start.');
    }
  }
  return out;
}
