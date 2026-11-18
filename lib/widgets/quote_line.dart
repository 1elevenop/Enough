import 'package:flutter/material.dart';

import '../content/awareness.dart';
import '../theme.dart';

/// Today's quote, small and quiet.
class QuoteLine extends StatelessWidget {
  const QuoteLine({super.key});

  @override
  Widget build(BuildContext context) {
    final q = quoteOfDay(DateTime.now());
    final text = Theme.of(context).textTheme;
    final muted = Tokens.of(context).muted;
    return Column(children: [
      Text('“${q.text}”',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic, height: 1.4)),
      const SizedBox(height: 6),
      Text('${q.author}, ${q.work}', style: text.bodySmall?.copyWith(color: muted)),
    ]);
  }
}
