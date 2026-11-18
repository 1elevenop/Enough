import 'package:flutter/material.dart';

import '../content/awareness.dart';
import '../services/usage_tracker.dart';
import '../theme.dart';
import 'daily_art.dart';

/// Home "moment" card: today's life math, a fact and a quote, swipeable,
/// over the day's generative art.
class MomentCard extends StatefulWidget {
  const MomentCard({super.key});

  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _Page {
  const _Page(this.label, this.text, [this.caption]);
  final String label, text;
  final String? caption;
}

class _MomentCardState extends State<MomentCard> {
  List<String> _math = const [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _loadMath();
  }

  Future<void> _loadMath() async {
    final now = DateTime.now();
    final sessions = await UsageTracker.instance
        .sessionsBetween(now.subtract(const Duration(days: 15)), now);
    if (mounted) setState(() => _math = lifeMath(sessions, now));
  }

  List<_Page> _pages(DateTime now) {
    final seed = daySeed(now);
    final fact = facts[seed % facts.length];
    final quote = quoteOfDay(now);
    return [
      for (final m in _math) _Page('Your week', m),
      _Page('Worth knowing', fact.text, fact.source),
      _Page('A thought', '“${quote.text}”', '${quote.author}, ${quote.work}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final pages = _pages(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 196,
          color: t.surface,
          child: Stack(children: [
            Positioned.fill(child: DailyArt(seed: daySeed(now))),
            PageView.builder(
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final p = pages[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.label.toUpperCase(),
                        style: text.labelSmall?.copyWith(color: t.muted, letterSpacing: 0.8)),
                    const Spacer(),
                    Text(p.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(height: 1.3)),
                    if (p.caption != null) ...[
                      const SizedBox(height: 6),
                      Text(p.caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: t.muted)),
                    ],
                  ]),
                );
              },
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i == _index ? t.ink : t.muted.withValues(alpha: .4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
