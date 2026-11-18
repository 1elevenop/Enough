import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/site_config.dart';

/// Round brand badge: gradient disc with the white (or dark) brand mark.
class SiteGlyph extends StatelessWidget {
  const SiteGlyph({super.key, required this.site, this.size = 40});

  final SiteConfig site;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: site.gradient.length > 1 ? site.gradient : [site.color, site.color],
          ),
        ),
        alignment: Alignment.center,
        child: FaIcon(site.glyph, size: size * 0.46, color: site.onGradient),
      );
}
