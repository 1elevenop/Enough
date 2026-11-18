import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

const facebook = SiteConfig(
  id: 'facebook',
  name: 'Facebook',
  glyph: FontAwesomeIcons.facebook,
  color: Color(0xFF1877F2),
  gradient: [Color(0xFF5AA2FF), Color(0xFF1558D6)],
  tagline: 'Groups and Messenger, no Reels',
  startUrl: 'https://m.facebook.com/notifications/',
  allowedHosts: ['facebook.com', 'fbcdn.net', 'messenger.com'],
  safeRoute: 'https://m.facebook.com/notifications/',
  messagesRoute: 'https://m.facebook.com/messages/',
  messagesPaths: [r'^/messages', r'^/login', r'^/checkpoint'],
  // Reels and Watch need a Reels pass. Without one, a single reel opens
  // only when tapped inside Messages.
  shortVideo: ShortVideoRules(
    blockedPaths: [r'^/reels(/|$)', r'^/watch'],
    dmOnlyPaths: [r'^/reel/'],
    hideSelectors: [
      'a[href*="/reels/"]',
      'a[href*="/watch"]',
      'div[aria-label*="Reels"]',
    ],
  ),
  dmSourcePaths: [r'^/messages'],
  searchRoute: 'https://m.facebook.com/search/top/?q={q}',
  postSelector: 'div[data-tracking-duration-id], article, div[data-focusable="true"]',
  metricSelectors: [
    'div[data-sigil="reactions-sentence-container"]',
    'span[data-sigil="reactions-bling-bar"]',
  ],
  categories: {
    r'^/messages': RouteCategory.messages,
    r'^/search': RouteCategory.search,
    r'^/(groups|events|marketplace)': RouteCategory.profile,
    r'^/notifications': RouteCategory.profile,
    r'^/(watch|reels?)(/|$)': RouteCategory.shorts,
  },
  features: [
    FeatureToggle(
      id: 'hide_feed',
      label: 'Hide News Feed',
      description: 'Home opens notifications instead',
      blockedPaths: [r'^/$', r'^/home\.php'],
    ),
  ],
);
