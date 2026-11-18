import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'feature_toggle.dart';

/// What kind of page the user is on. Drives the useful-vs-scroll split.
enum RouteCategory {
  messages(true, 'Messages'),
  search(true, 'Search'),
  create(true, 'Posting'),
  watch(null, 'Watching'),
  shorts(false, 'Short videos'),
  profile(null, 'Profiles'),
  feed(false, 'Feed scrolling');

  const RouteCategory(this.productive, this.label);

  /// true = useful, false = scroll, null = neutral.
  final bool? productive;
  final String label;
}

class ExternalApp {
  const ExternalApp({required this.launchUrl, required this.storeUrl});

  /// Deep link that opens the app (e.g. `snapchat://`).
  final String launchUrl;

  /// Play Store page used when the app isn't installed.
  final String storeUrl;
}

/// Short-video rules (Reels, Shorts). Lifted only while a Reels pass runs.
class ShortVideoRules {
  const ShortVideoRules({
    this.blockedPaths = const [],
    this.hideSelectors = const [],
    this.dmOnlyPaths = const [],
  });

  final List<String> blockedPaths;
  final List<String> hideSelectors;

  /// Paths that open only from a DM (see [SiteConfig.dmSourcePaths]).
  final List<String> dmOnlyPaths;
}

class SiteConfig {
  const SiteConfig({
    required this.id,
    required this.name,
    required this.glyph,
    required this.color,
    required this.gradient,
    this.onGradient = Colors.white,
    this.tagline = '',
    required this.startUrl,
    required this.allowedHosts,
    required this.safeRoute,
    this.blockedPaths = const [],
    this.alwaysHide = const [],
    this.shortVideo,
    this.dmSourcePaths = const [],
    this.features = const [],
    this.commonToggles = const [
      CommonToggles.grayscale,
      CommonToggles.hideMetrics,
      CommonToggles.noAutoplay,
      CommonToggles.feedCap,
      CommonToggles.blurMedia,
      CommonToggles.keywordFilter,
    ],
    this.postSelector = '',
    this.metricSelectors = const [],
    this.categories = const {},
    this.messagesRoute,
    this.messagesPaths = const [],
    this.searchRoute,
    this.needsMedia = false,
    this.mediaWarmup = false,
    this.stripWebViewUa = false,
    this.externalApp,
    this.desktopMode = false,
    this.note,
  });

  final String id;
  final String name;
  /// Brand mark (Font Awesome).
  final FaIconData glyph;

  /// Brand color for charts and accents.
  final Color color;

  /// Tile gradient, top-left to bottom-right.
  final List<Color> gradient;

  /// Text/icon color on top of [gradient].
  final Color onGradient;

  /// One line shown in the add sheet, e.g. "Chats, no Spotlight".
  final String tagline;
  final String startUrl;

  /// Host suffixes that stay inside the WebView. Others open externally.
  final List<String> allowedHosts;

  /// Where blocked routes are sent.
  final String safeRoute;

  /// Regex path patterns that are always blocked. Not user-switchable.
  final List<String> blockedPaths;

  /// Selectors that are always hidden. Not user-switchable.
  final List<String> alwaysHide;

  /// Reels/Shorts rules, covered by the Reels pass.
  final ShortVideoRules? shortVideo;

  /// Where a DM-only short video may be opened from.
  final List<String> dmSourcePaths;

  final List<FeatureToggle> features;

  /// Ids from [CommonToggles] this site supports.
  final List<String> commonToggles;

  /// Selector for one feed item (keyword filter + feed cap).
  final String postSelector;

  /// Selectors for like/view/follower counts.
  final List<String> metricSelectors;

  /// Regex path pattern -> category. First match wins; default is feed.
  final Map<String, RouteCategory> categories;

  final String? messagesRoute;

  /// Paths allowed in messages-only focus mode.
  final List<String> messagesPaths;

  /// Search URL with `{q}` placeholder.
  final String? searchRoute;

  /// Needs camera/microphone passthrough. Add CAMERA, RECORD_AUDIO and
  /// MODIFY_AUDIO_SETTINGS to AndroidManifest.xml before enabling this.
  final bool needsMedia;

  /// Request camera and mic once at page load (when already allowed) so the
  /// WebView holds the grant before the site's own camera starts. Snapchat
  /// needs this; it briefly lights the camera indicator.
  final bool mediaWarmup;

  /// Remove the `; wv` WebView marker from the user agent.
  final bool stripWebViewUa;

  /// When set, the tile opens this native app instead of a WebView.
  final ExternalApp? externalApp;

  bool get isExternal => externalApp != null;

  /// Present a desktop Linux Chrome: user agent, client hints, desktop
  /// layout. For sites that refuse phones (Snapchat for Web). Experimental.
  final bool desktopMode;

  /// Shown to the user before opening (e.g. login caveats).
  final String? note;

  List<FeatureToggle> get allToggles => [
        ...features,
        ...CommonToggles.all.where((t) => commonToggles.contains(t.id)),
      ];

  bool ownsHost(String host) => allowedHosts
      .any((h) => host == h || host.endsWith('.$h'));

  RouteCategory categorize(String path) {
    for (final e in categories.entries) {
      if (RegExp(e.key).hasMatch(path)) return e.value;
    }
    return RouteCategory.feed;
  }
}
