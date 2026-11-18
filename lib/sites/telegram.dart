import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

// The /a/ client: /k/ needs SharedWorker, which Android WebView lacks.
const telegram = SiteConfig(
  id: 'telegram',
  name: 'Telegram',
  glyph: FontAwesomeIcons.telegram,
  color: Color(0xFF229ED9),
  gradient: [Color(0xFF5BC8F5), Color(0xFF1C8AD0)],
  tagline: 'Messages only',
  startUrl: 'https://web.telegram.org/a/',
  allowedHosts: ['telegram.org', 't.me', 'telegram.me'],
  safeRoute: 'https://web.telegram.org/a/',
  messagesRoute: 'https://web.telegram.org/a/',
  messagesPaths: [r'.*'],
  categories: {r'.*': RouteCategory.messages},
  needsMedia: true,
  commonToggles: [CommonToggles.grayscale],
);
