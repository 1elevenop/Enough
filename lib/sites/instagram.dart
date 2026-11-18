import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

const instagram = SiteConfig(
  id: 'instagram',
  name: 'Instagram',
  glyph: FontAwesomeIcons.instagram,
  color: Color(0xFFDD2A7B),
  gradient: [Color(0xFFFF9A5A), Color(0xFFE1306C), Color(0xFF8A3AB9)],
  tagline: 'DMs only, no Reels or Explore',
  startUrl: 'https://www.instagram.com/direct/inbox/',
  allowedHosts: ['instagram.com', 'cdninstagram.com', 'facebook.com'],
  safeRoute: 'https://www.instagram.com/direct/inbox/',
  messagesRoute: 'https://www.instagram.com/direct/inbox/',
  messagesPaths: [r'^/direct', r'^/accounts'],
  // Reels need a Reels pass. Without one, the Reels tab, reels feed and
  // profile reels tabs are blocked; a single reel (/reel/<id> or
  // /<username>/reel/<id>) opens only when tapped inside a DM.
  shortVideo: ShortVideoRules(
    blockedPaths: [r'^/reels(/|$)', r'^/[^/]+/reels/?$'],
    dmOnlyPaths: [r'^/([^/]+/)?reel/'],
    hideSelectors: [
      'a[href="/reels/"]',
      'a[href^="/reels/"]',
      'div:has(> a[href="/reels/"])',
      r'a[href$="/reels/"]',
      'main article:has(a[href*="/reel/"])',
    ],
  ),
  dmSourcePaths: [r'^/direct'],
  postSelector: 'article',
  metricSelectors: [
    // Like/comment counts next to the icons (matched on live markup Nov 2026).
    'main article section div > span[role="button"]',
    r'section a[href$="/liked_by/"]',
    r'section span:has(> a[href$="/liked_by/"])',
    r'a[href$="/followers/"] span',
    r'a[href$="/following/"] span',
    'header ul li span span',
  ],
  categories: {
    r'^/direct': RouteCategory.messages,
    r'^/create': RouteCategory.create,
    r'^/([^/]+/)?reels?(/|$)': RouteCategory.shorts,
    r'^/explore': RouteCategory.feed,
    r'^/p/': RouteCategory.watch,
    r'^/(stories)/': RouteCategory.watch,
    r'^/(?!$)[^/]+/?$': RouteCategory.profile,
  },
  features: [
    FeatureToggle(
      id: 'block_explore',
      label: 'Block Explore',
      blockedPaths: [r'^/explore'],
      hideSelectors: [
        'a[href="/explore/"]',
        'div:has(> a[href="/explore/"])',
      ],
    ),
    FeatureToggle(
      id: 'hide_home_feed',
      label: 'Hide Home feed',
      description: 'Home opens your messages instead',
      defaultOn: false,
      blockedPaths: [r'^/$'],
    ),
    FeatureToggle(
      id: 'hide_suggested',
      label: 'Hide suggested posts and accounts',
      hideSelectors: [
        'article:has(a[href*="suggested"])',
        'div[role="presentation"]:has(> div > a[href="/explore/people/"])',
        'a[href="/explore/people/"]',
      ],
    ),
  ],
);
