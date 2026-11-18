import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

// Selectors are drafts; tune against live pages on the phone.
const bluesky = SiteConfig(
  id: 'bluesky',
  name: 'Bluesky',
  glyph: FontAwesomeIcons.bluesky,
  color: Color(0xFF1185FE),
  gradient: [Color(0xFF5AB0FF), Color(0xFF0A6FE0)],
  tagline: 'Notifications first, no Discover',
  startUrl: 'https://bsky.app/notifications',
  allowedHosts: ['bsky.app', 'bsky.social', 'bsky.network'],
  safeRoute: 'https://bsky.app/notifications',
  messagesRoute: 'https://bsky.app/messages',
  messagesPaths: [r'^/messages'],
  searchRoute: 'https://bsky.app/search?q={q}',
  postSelector: '[data-testid^="feedItem-by-"]',
  categories: {
    r'^/messages': RouteCategory.messages,
    r'^/search': RouteCategory.search,
    r'^/notifications': RouteCategory.profile,
    r'^/profile/[^/]+/post/': RouteCategory.watch,
    r'^/profile/': RouteCategory.profile,
  },
  features: [
    FeatureToggle(
      id: 'hide_discover',
      label: 'Hide the Discover feed',
      description: 'Only people you follow',
      blockedPaths: [r'^/feeds', r'^/profile/[^/]+/feed/'],
      hideSelectors: [
        '[data-testid="homeScreenFeedTabs-Discover"]',
        '[data-testid*="Discover"]',
        'a[href="/feeds"]',
      ],
    ),
  ],
);
