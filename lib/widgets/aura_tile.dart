import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/site_config.dart';
import '../theme.dart';

/// Home-screen tile. Active: full brand gradient with a glass emblem.
/// Locked: soft neutral card with a blurred brand aura and a lock.
class AuraTile extends StatefulWidget {
  const AuraTile({
    super.key,
    required this.site,
    required this.caption,
    this.progress,
    this.locked = false,
    this.warning = false,
    this.onTap,
    this.onLongPress,
  });

  final SiteConfig site;
  final String caption;

  /// 0..1 share of today's limit used; null hides the line.
  final double? progress;
  final bool locked;
  final bool warning;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<AuraTile> createState() => _AuraTileState();
}

class _AuraTileState extends State<AuraTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final site = widget.site;
    final locked = widget.locked;
    final fg = locked ? t.ink : site.onGradient;
    final colors = site.gradient.length > 1 ? site.gradient : [site.color, site.color];

    final body = Stack(fit: StackFit.expand, children: [
      if (!locked) ...[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
        ),
        // Soft light from the top-left, like the reference cards.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.7, -0.9),
              radius: 1.1,
              colors: [Colors.white.withValues(alpha: .30), Colors.white.withValues(alpha: 0)],
            ),
          ),
        ),
      ] else ...[
        ColoredBox(color: t.locked),
        Center(
          child: Transform.translate(
            offset: const Offset(0, -14),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    colors.last.withValues(alpha: .55),
                    colors.first.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
        child: Column(children: [
          const Spacer(flex: 3),
          _Emblem(site: site, locked: locked, fg: fg),
          const Spacer(flex: 2),
          Text(
            site.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.caption,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: locked ? t.muted : fg.withValues(alpha: .82),
                ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: SizedBox(
            height: 3,
            width: 56,
            child: widget.progress == null
                ? null
                : ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: widget.progress,
                      minHeight: 3,
                      backgroundColor:
                          locked ? t.line : fg.withValues(alpha: .22),
                      color: widget.warning || locked ? Tokens.accent : fg,
                    ),
                  ),
          ),
          ),
        ]),
      ),
    ]);

    return AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tokens.radius),
          boxShadow: locked
              ? null
              : [
                  BoxShadow(
                    color: colors.last.withValues(alpha: .28),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                    spreadRadius: -10,
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radius),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onHighlightChanged: (v) => setState(() => _down = v),
              splashColor: fg.withValues(alpha: .08),
              highlightColor: Colors.transparent,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.site, required this.locked, required this.fg});
  final SiteConfig site;
  final bool locked;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .65),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.lock_rounded, size: 16, color: Colors.black.withValues(alpha: .55)),
      );
    }
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: fg.withValues(alpha: .14),
        border: Border.all(color: fg.withValues(alpha: .26)),
      ),
      alignment: Alignment.center,
      child: FaIcon(site.glyph, size: 26, color: fg),
    );
  }
}
