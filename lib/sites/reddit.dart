import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

const reddit = SiteConfig(
  id: 'reddit',
  name: 'Reddit',
  glyph: FontAwesomeIcons.redditAlien,
  color: Color(0xFFFF4500),
  gradient: [Color(0xFFFF8A4C), Color(0xFFE03D00)],
  tagline: 'Search and your subreddits, no Popular',
  startUrl: 'https://www.reddit.com/search/?q=',
  allowedHosts: ['reddit.com', 'redd.it', 'redditmedia.com', 'redditstatic.com'],
  safeRoute: 'https://www.reddit.com/search/?q=',
  messagesRoute: 'https://chat.reddit.com/',
  messagesPaths: [r'^/message', r'^/chat', r'^/room', r'^/login'],
  searchRoute: 'https://www.reddit.com/search/?q={q}',
  postSelector: 'shreddit-post, article',
  // Reddit's network security blocks the WebView user agent ("; wv").
  stripWebViewUa: true,
  categories: {
    r'^/search': RouteCategory.search,
    r'^/(message|chat|room)': RouteCategory.messages,
    r'^/r/[^/]+/comments/': RouteCategory.watch,
    r'^/(user|u)/': RouteCategory.profile,
    r'^/submit': RouteCategory.create,
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
      id: 'hide_home',
      label: 'Hide Home, Popular and All',
      description: 'The front page opens search instead',
      blockedPaths: [r'^/$', r'^/(best|hot|new|top|rising)/?$', r'^/r/(popular|all)(/|$)'],
      hideSelectors: [
        'a[href="/r/popular/"]',
        'a[href="/r/all/"]',
        'faceplate-tracker[noun="popular"]',
      ],
    ),
    FeatureToggle(
      id: 'hide_trending',
      label: 'Hide trending and recommendations',
      hideSelectors: [
        'trending-searches-ui',
        'reddit-recent-pages',
        '#right-sidebar-container',
        'shreddit-ad-post',
        'shreddit-comments-page-ad',
      ],
    ),
  ],
);
