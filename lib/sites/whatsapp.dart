import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

/// WhatsApp Web only serves computers, so this tab uses desktop mode.
const whatsapp = SiteConfig(
  id: 'whatsapp',
  name: 'WhatsApp',
  glyph: FontAwesomeIcons.whatsapp,
  color: Color(0xFF25D366),
  gradient: [Color(0xFF5BE38C), Color(0xFF128C4A)],
  tagline: 'Chats on the web, nothing else',
  startUrl: 'https://web.whatsapp.com/',
  allowedHosts: ['whatsapp.com', 'whatsapp.net'],
  safeRoute: 'https://web.whatsapp.com/',
  messagesRoute: 'https://web.whatsapp.com/',
  messagesPaths: [r'.*'],
  categories: {r'.*': RouteCategory.messages},
  needsMedia: true,
  desktopMode: true,
  commonToggles: [CommonToggles.grayscale],
  note: 'You can\'t scan the QR code with the phone it\'s shown on. On the '
      'login screen tap "Link with phone number instead", then enter the code '
      'in WhatsApp → Linked devices. Experimental: this tab pretends to be a '
      'desktop browser, and WhatsApp may flag or log out the session.',
);
