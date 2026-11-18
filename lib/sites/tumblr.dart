import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

// Selectors are drafts; tune against live pages on the phone.
const tumblr = SiteConfig(
  id: 'tumblr',
  name: 'Tumblr',
  glyph: FontAwesomeIcons.tumblr,
  color: Color(0xFF35465C),
  gradient: [Color(0xFF56708F), Color(0xFF1F2B3A)],
  tagline: 'Blogs you follow, no Explore',
  startUrl: 'https://www.tumblr.com/dashboard/following',
  allowedHosts: ['tumblr.com'],
  safeRoute: 'https://www.tumblr.com/dashboard/following',
  searchRoute: 'https://www.tumblr.com/search/{q}',
  postSelector: 'article',
  categories: {
    r'^/search': RouteCategory.search,
    r'^/new': RouteCategory.create,
    r'^/(explore|dashboard)': RouteCategory.feed,
    r'^/[^/]+/?$': RouteCategory.profile,
  },
  features: [
    FeatureToggle(
      id: 'block_explore',
      label: 'Block Explore',
      blockedPaths: [r'^/explore'],
      hideSelectors: ['a[href^="/explore"]'],
    ),
    FeatureToggle(
      id: 'hide_for_you',
      label: 'Hide "For you"',
      description: 'The dashboard shows only blogs you follow',
      blockedPaths: [r'^/dashboard/stuff_for_you', r'^/dashboard/?$'],
      hideSelectors: ['a[href="/dashboard/stuff_for_you"]'],
    ),
  ],
);
