import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

// Selectors are drafts; tune against live pages on the phone.
const linkedin = SiteConfig(
  id: 'linkedin',
  name: 'LinkedIn',
  glyph: FontAwesomeIcons.linkedin,
  color: Color(0xFF0A66C2),
  gradient: [Color(0xFF3D8FE0), Color(0xFF0A4F96)],
  tagline: 'Messages and search, no feed',
  startUrl: 'https://www.linkedin.com/messaging/',
  allowedHosts: ['linkedin.com', 'licdn.com'],
  safeRoute: 'https://www.linkedin.com/messaging/',
  messagesRoute: 'https://www.linkedin.com/messaging/',
  messagesPaths: [r'^/messaging', r'^/login', r'^/checkpoint', r'^/uas'],
  searchRoute: 'https://www.linkedin.com/search/results/all/?keywords={q}',
  postSelector: 'div[data-id^="urn:li:activity"], .feed-shared-update-v2, article',
  categories: {
    r'^/messaging': RouteCategory.messages,
    r'^/search': RouteCategory.search,
    r'^/(post|share)': RouteCategory.create,
    r'^/(in|company)/': RouteCategory.profile,
    r'^/(notifications|mynetwork|jobs)': RouteCategory.profile,
  },
  features: [
    FeatureToggle(
      id: 'block_feed',
      label: 'Block the feed',
      description: 'Home opens your messages instead',
      blockedPaths: [r'^/$', r'^/feed'],
      hideSelectors: ['a[href*="/feed/"]'],
    ),
    FeatureToggle(
      id: 'hide_promoted',
      label: 'Hide promoted posts',
      hideSelectors: [
        'div[data-ad-banner]',
        '.feed-shared-update-v2:has(a[href*="/ad/"])',
        'article:has(a[href*="trk=ad"])',
      ],
    ),
  ],
);
