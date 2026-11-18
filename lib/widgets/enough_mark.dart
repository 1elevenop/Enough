import 'package:flutter/material.dart';

/// The Enough mark: a neon, overloaded brain cut by one clean line,
/// calm below it. Masters live in `branding/`.
class EnoughMark extends StatelessWidget {
  const EnoughMark({super.key, this.size = 64, this.background = false});

  /// Width and height of the square the mark is fitted into.
  final double size;

  /// Draw the dark rounded-square app-icon canvas behind the mark.
  final bool background;

  static const canvas = Color(0xFF120D1A);

  @override
  Widget build(BuildContext context) {
    final dark = background || Theme.of(context).brightness == Brightness.dark;
    final mark = Image.asset(
      dark ? 'assets/brand/mark.png' : 'assets/brand/mark_light.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Enough',
    );
    if (!background) return mark;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: canvas,
        borderRadius: BorderRadius.circular(size * 0.23),
      ),
      child: mark,
    );
  }
}
