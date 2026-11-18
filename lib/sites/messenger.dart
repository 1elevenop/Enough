import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

/// messenger.com sends phones to the app store, so this tab uses desktop mode.
const messenger = SiteConfig(
  id: 'messenger',
  name: 'Messenger',
  glyph: FontAwesomeIcons.facebookMessenger,
  color: Color(0xFF0084FF),
  gradient: [Color(0xFF00B2FF), Color(0xFF8A3CFF)],
  tagline: 'Chats and calls only',
  startUrl: 'https://www.messenger.com/',
  allowedHosts: ['messenger.com', 'facebook.com', 'fbcdn.net', 'fbsbx.com'],
  safeRoute: 'https://www.messenger.com/',
  messagesRoute: 'https://www.messenger.com/',
  messagesPaths: [r'.*'],
  categories: {r'.*': RouteCategory.messages},
  needsMedia: true,
  desktopMode: true,
  commonToggles: [CommonToggles.grayscale],
  note: 'Experimental: messenger.com only serves computers, so this tab '
      'pretends to be a desktop browser. Meta may ask you to confirm the login.',
);
