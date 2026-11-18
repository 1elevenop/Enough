import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soft aura blobs and fine line circles, seeded by the date so each day
/// looks different.
class DailyArtPainter extends CustomPainter {
  const DailyArtPainter(this.seed, {this.dark = false});

  final int seed;
  final bool dark;

  static const palette = [
    Color(0xFFF2B233),
    Color(0xFFFF9A5A),
    Color(0xFFE1306C),
    Color(0xFF8A3AB9),
    Color(0xFF5AA2FF),
    Color(0xFF5BE38C),
    Color(0xFF5BC8F5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final colors = [...palette]..shuffle(rnd);
    final m = size.shortestSide;

    for (var i = 0; i < 3; i++) {
      final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = m * (0.35 + rnd.nextDouble() * 0.4);
      final color = colors[i];
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35)
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: dark ? .45 : .38),
            color.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final ink = (dark ? Colors.white : const Color(0xFF111113)).withValues(alpha: .18);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = ink;
    final center = Offset(size.width * (0.55 + rnd.nextDouble() * 0.35),
        size.height * (0.2 + rnd.nextDouble() * 0.6));
    final rings = 3 + rnd.nextInt(4);
    for (var i = 1; i <= rings; i++) {
      canvas.drawCircle(center, m * 0.09 * i, line);
    }
    for (var i = 0; i < 2; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        m * (0.05 + rnd.nextDouble() * 0.1),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(DailyArtPainter old) => old.seed != seed || old.dark != dark;
}

/// Fills its box with today's art.
class DailyArt extends StatelessWidget {
  const DailyArt({super.key, required this.seed});
  final int seed;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: DailyArtPainter(seed, dark: Theme.of(context).brightness == Brightness.dark),
        child: const SizedBox.expand(),
      );
}
