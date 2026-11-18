import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

const threads = SiteConfig(
  id: 'threads',
  name: 'Threads',
  glyph: FontAwesomeIcons.threads,
  color: Color(0xFF8E8E93),
  gradient: [Color(0xFF5C5C63), Color(0xFF1A1A1D)],
  tagline: 'Following and activity, capped feed',
  startUrl: 'https://www.threads.com/activity',
  allowedHosts: ['threads.com', 'threads.net', 'instagram.com', 'cdninstagram.com', 'facebook.com'],
  safeRoute: 'https://www.threads.com/activity',
  searchRoute: 'https://www.threads.com/search?q={q}',
  postSelector: 'div[data-pressable-container="true"]',
  categories: {
    r'^/search': RouteCategory.search,
    r'^/activity': RouteCategory.profile,
    r'^/@[^/]+/post/': RouteCategory.watch,
    r'^/@': RouteCategory.profile,
  },
  commonToggles: [
    CommonToggles.grayscale,
    CommonToggles.noAutoplay,
    CommonToggles.feedCap,
    CommonToggles.blurMedia,
    CommonToggles.keywordFilter,
  ],
  features: [
    FeatureToggle(
      id: 'hide_for_you',
      label: 'Hide the For You feed',
      description: 'Home opens your activity instead',
      blockedPaths: [r'^/$', r'^/for_you'],
    ),
  ],
);
