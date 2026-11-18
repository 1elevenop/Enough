import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

const youtubeRestrictedMode = 'restricted_mode';

const youtube = SiteConfig(
  id: 'youtube',
  name: 'YouTube',
  glyph: FontAwesomeIcons.youtube,
  color: Color(0xFFFF0033),
  gradient: [Color(0xFFFF5A4F), Color(0xFFD7141A)],
  tagline: 'Search and subscriptions, no Shorts',
  startUrl: 'https://m.youtube.com/feed/subscriptions',
  allowedHosts: ['youtube.com', 'youtu.be', 'google.com', 'accounts.google.com'],
  safeRoute: 'https://m.youtube.com/feed/subscriptions',
  searchRoute: 'https://m.youtube.com/results?search_query={q}',
  postSelector:
      'ytm-rich-item-renderer, ytm-video-with-context-renderer, ytm-compact-video-renderer',
  // Matched against live m.youtube.com markup (Nov 2026).
  metricSelectors: [
    r'.ytmBadgeAndBylineRendererItemByline:has([aria-label$=" views"])',
    r'.ytmBadgeAndBylineRendererItemByline:has([aria-label$=" view"])',
    r'.ytVideoSubtitleViewModelSubstring[aria-label$=" views"]',
    r'.ytVideoSubtitleViewModelSubstring[aria-label$=" likes"]',
    r'.ytVideoSubtitleViewModelSubstring[aria-label$=" like"]',
    'like-button-view-model .ytSpecButtonShapeNextButtonTextContent',
    '.watch-card-single-hero-subtitle',
  ],
  // Shorts need a Reels pass.
  shortVideo: ShortVideoRules(
    blockedPaths: [r'^/shorts'],
    hideSelectors: [
        'ytm-reel-shelf-renderer',
        'ytm-shorts-lockup-view-model',
        'ytm-shorts-lockup-view-model-v2',
        'ytm-rich-section-renderer:has(ytm-shorts-lockup-view-model)',
        'grid-shelf-view-model:has(ytm-shorts-lockup-view-model)',
        'ytm-item-section-renderer:has(> * > grid-shelf-view-model ytm-shorts-lockup-view-model)',
        'ytm-pivot-bar-item-renderer:has(.pivot-shorts)',
        '*:has(> .pivot-shorts)',
        'ytm-chip-cloud-chip-renderer:has(a[href^="/shorts"])',
        // Whole result cards that link to a Short (search, channel, related).
        'ytm-video-with-context-renderer:has(a[href^="/shorts"])',
        'ytm-compact-video-renderer:has(a[href^="/shorts"])',
        'ytm-rich-item-renderer:has(a[href^="/shorts"])',
        'ytm-video-with-context-renderer:has([data-style="SHORTS"])',
      ],
  ),
  categories: {
    r'^/shorts': RouteCategory.shorts,
    r'^/results': RouteCategory.search,
    r'^/watch': RouteCategory.watch,
    r'^/(@|channel/|c/|user/)': RouteCategory.profile,
    r'^/feed/(library|history|playlists)': RouteCategory.profile,
  },
  features: [
    FeatureToggle(
      id: 'hide_home',
      label: 'Hide Home feed',
      description: 'Home redirects to Subscriptions',
      blockedPaths: [r'^/$'],
      hideSelectors: [
        'ytm-pivot-bar-item-renderer:has(.pivot-w2w)',
        '*:has(> .pivot-w2w)',
      ],
    ),
    FeatureToggle(
      id: 'hide_related',
      label: 'Hide recommendations under videos',
      description: 'No "up next" rabbit hole',
      hideSelectors: [
        'ytm-item-section-renderer[section-identifier="related-items"]',
        'ytm-watch-next-secondary-results-renderer',
        '.ytp-endscreen-content',
        '.ytp-ce-element',
        'ytm-single-column-watch-next-results-renderer ytm-item-section-renderer:has(ytm-video-with-context-renderer)',
      ],
    ),
    FeatureToggle(
      id: 'hide_comments',
      label: 'Hide comments',
      defaultOn: false,
      hideSelectors: [
        'ytm-comments-entry-point-header-renderer',
        'ytm-comment-section-renderer',
        'ytm-engagement-panel-section-list-renderer[target-id*="comment"]',
      ],
    ),
    FeatureToggle(
      id: youtubeRestrictedMode,
      label: 'Restricted Mode',
      description: 'YouTube\'s own filter for mature content',
      group: ToggleGroup.filter,
    ),
  ],
);
