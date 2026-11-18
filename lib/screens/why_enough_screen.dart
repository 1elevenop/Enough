import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/enough_mark.dart';
import '../widgets/quote_line.dart';

const _manifesto = [
  'Most apps are paid for with your attention. The longer you stay, the more '
      'they earn, so they are built to make leaving hard.',
  'Enough is built the other way round. It is designed to be closed.',
  'It keeps the parts of your socials that connect you to people: messages, '
      'search, the things you came to do. It removes the parts that consume '
      'you: the endless feed, the autoplay, the numbers that make you compare.',
  'There are no ads here, no tracking and no feed. Your usage stays on this '
      'phone. Nothing is sold, because there is nothing to sell.',
  'The limits are yours. You set them while you\'re calm, and Enough holds '
      'them for you when you\'re not.',
  'A full cup doesn\'t need more poured into it. Some days, a little is enough.',
];

/// The short manifesto behind the app.
class WhyEnoughScreen extends StatelessWidget {
  const WhyEnoughScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = Tokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Why Enough')),
      body: ListView(padding: const EdgeInsets.fromLTRB(28, 12, 28, 40), children: [
        const Center(child: EnoughMark(size: 64)),
        const SizedBox(height: 24),
        for (final p in _manifesto)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(p, style: text.bodyLarge?.copyWith(height: 1.5)),
          ),
        const SizedBox(height: 12),
        Divider(color: t.line),
        const SizedBox(height: 20),
        const QuoteLine(),
      ]),
    );
  }
}
