import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

const pinterest = SiteConfig(
  id: 'pinterest',
  name: 'Pinterest',
  glyph: FontAwesomeIcons.pinterestP,
  color: Color(0xFFE60023),
  gradient: [Color(0xFFFF5A6E), Color(0xFFC8001E)],
  tagline: 'Search and boards, capped feed',
  startUrl: 'https://www.pinterest.com/',
  allowedHosts: ['pinterest.com', 'pinimg.com', 'pin.it'],
  safeRoute: 'https://www.pinterest.com/',
  searchRoute: 'https://www.pinterest.com/search/pins/?q={q}',
  postSelector: '[data-grid-item="true"], div[data-test-id="pin"]',
  categories: {
    r'^/search': RouteCategory.search,
    r'^/pin/': RouteCategory.watch,
    r'^/pin-builder': RouteCategory.create,
    r'^/(today|ideas)': RouteCategory.feed,
    r'^/(?!$)[^/]+/?$': RouteCategory.profile,
  },
  features: [
    FeatureToggle(
      id: 'block_today',
      label: 'Block Today and Explore',
      blockedPaths: [r'^/today', r'^/ideas'],
      hideSelectors: ['a[href="/today/"]', 'a[href^="/ideas"]', 'a[data-test-id="today-tab"]'],
    ),
    FeatureToggle(
      id: 'hide_more_like',
      label: 'Hide "More to explore" under pins',
      hideSelectors: ['[data-test-id="relatedPins"]', '[data-test-id="more-ideas"]'],
    ),
  ],
);
