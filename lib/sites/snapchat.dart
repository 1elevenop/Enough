import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

/// EXPERIMENTAL: Snapchat for Web only serves computers, so this tab
/// presents itself as desktop Chrome on Linux (user agent, client hints,
/// desktop layout). Snapchat may detect this and lock the account.
const snapchat = SiteConfig(
  id: 'snapchat',
  name: 'Snapchat',
  glyph: FontAwesomeIcons.snapchat,
  color: Color(0xFFFFC400),
  gradient: [Color(0xFFFFE86B), Color(0xFFFFC21A)],
  onGradient: Color(0xFF16140C),
  tagline: 'Chats on the web, no Spotlight',
  // snapchat.com/web bounces logged-out visitors through /feed <-> /download;
  // the accounts login page continues to the web client afterwards.
  startUrl:
      'https://accounts.snapchat.com/v2/login?continue=https%3A%2F%2Fwww.snapchat.com%2Fweb',
  allowedHosts: ['snapchat.com', 'sc-cdn.net', 'sc-static.net', 'snap.com', 'snapkit.com'],
  safeRoute: 'https://www.snapchat.com/web',
  messagesRoute: 'https://www.snapchat.com/web',
  messagesPaths: [r'.*'],
  categories: {r'.*': RouteCategory.messages},
  needsMedia: true,
  mediaWarmup: true,
  desktopMode: true,
  // Autoplay/blur would break calls; keep only the gentle ones.
  commonToggles: [CommonToggles.grayscale],
  blockedPaths: [r'^/spotlight', r'^/discover', r'^/stories'],
  // Matched on the live web client (Nov 2026): Stories/Spotlight buttons.
  alwaysHide: [
    'a[href*="/spotlight"]',
    'a[href*="/discover"]',
    '[title="View Spotlight Stories"]',
    '[title="View stories"]',
    '[title*="Spotlight"]',
    'div:has(> [title="View Spotlight Stories"])',
  ],
  note: 'Experimental: Snapchat for Web is made for computers, so this tab '
      'pretends to be a desktop browser. Snapchat may flag or lock the '
      'account. Using a spare account is safer.',
);
