import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

const xSite = SiteConfig(
  id: 'x',
  name: 'X',
  glyph: FontAwesomeIcons.xTwitter,
  color: Color(0xFF71767B),
  gradient: [Color(0xFF4A4B50), Color(0xFF111113)],
  tagline: 'Notifications first, no For You',
  startUrl: 'https://x.com/notifications',
  allowedHosts: ['x.com', 'twitter.com', 'twimg.com'],
  safeRoute: 'https://x.com/notifications',
  messagesRoute: 'https://x.com/messages',
  messagesPaths: [r'^/messages', r'^/i/flow', r'^/login'],
  searchRoute: 'https://x.com/search?q={q}',
  postSelector: 'article[data-testid="tweet"]',
  metricSelectors: [
    '[data-testid="reply"] span',
    '[data-testid="retweet"] span',
    '[data-testid="like"] span',
    '[data-testid="unlike"] span',
    'a[href*="/analytics"]',
    r'a[href$="/followers"] span',
    r'a[href$="/verified_followers"] span',
    r'a[href$="/following"] span',
  ],
  categories: {
    r'^/messages': RouteCategory.messages,
    r'^/search': RouteCategory.search,
    r'^/compose': RouteCategory.create,
    r'^/notifications': RouteCategory.profile,
    r'^/home': RouteCategory.feed,
    r'^/[^/]+/status/': RouteCategory.watch,
    r'^/(?!$)[^/]+/?$': RouteCategory.profile,
  },
  features: [
    FeatureToggle(
      id: 'block_explore',
      label: 'Block Explore and trends',
      blockedPaths: [r'^/explore'],
      hideSelectors: [
        'a[href="/explore"]',
        '[aria-label="Timeline: Trending now"]',
        'div[data-testid="sidebarColumn"]',
      ],
    ),
    FeatureToggle(
      id: 'hide_home',
      label: 'Hide Home timeline',
      description: 'Home opens notifications instead',
      blockedPaths: [r'^/home'],
      hideSelectors: ['a[href="/home"]'],
    ),
    FeatureToggle(
      id: 'hide_who_to_follow',
      label: 'Hide "Who to follow"',
      hideSelectors: [
        'aside[aria-label="Who to follow"]',
        'div[data-testid="UserCell"]:has(+ div a[href*="/i/connect_people"])',
      ],
    ),
  ],
);
