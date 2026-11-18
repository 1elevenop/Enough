import 'dart:convert';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';
import 'cleaner_js.dart';
import 'route_guard.dart';

/// Builds the CSS for a site from its enabled toggles. Each selector gets
/// its own rule, so one selector the browser rejects can't void the rest.
String buildCss(SiteConfig site, Set<String> enabled, {bool shortVideoAllowed = false}) {
  final b = StringBuffer();
  for (final sel in [
    ...site.alwaysHide,
    if (!shortVideoAllowed) ...?site.shortVideo?.hideSelectors,
  ]) {
    b.writeln('$sel{display:none !important}');
  }
  for (final t in site.allToggles) {
    if (!enabled.contains(t.id)) continue;
    for (final sel in t.hideSelectors) {
      b.writeln('$sel{display:none !important}');
    }
    if (t.css.isNotEmpty) b.writeln(t.css);
  }
  if (enabled.contains(CommonToggles.grayscale)) {
    b.writeln('html{filter:grayscale(1) !important}');
  }
  if (enabled.contains(CommonToggles.hideMetrics)) {
    for (final sel in site.metricSelectors) {
      b.writeln('$sel{visibility:hidden !important}');
    }
  }
  if (enabled.contains(CommonToggles.blurMedia)) {
    b.writeln('img:not([data-ff-revealed]),video:not([data-ff-revealed])'
        '{filter:blur(24px) !important;transition:filter .2s}');
  }
  return b.toString();
}

/// The full document-start script for a site.
String buildInjection({
  required SiteConfig site,
  required Set<String> enabled,
  required RouteGuard guard,
  required List<String> keywords,
  required int feedCap,
  List<String> trackers = const [],
  String? mediaState,
}) {
  final config = {
    'css': buildCss(site, enabled, shortVideoAllowed: guard.shortVideoAllowed),
    'blocked': guard.blockedSources,
    'focusOnly': guard.messagesOnly ? guard.focusSources : null,
    'focusTarget': site.messagesRoute ?? site.safeRoute,
    'safe': site.safeRoute,
    'desktopMode': site.desktopMode,
    'dmOnly': guard.dmOnlySources,
    'dmSource': guard.dmSourceSources,
    'postSelector': site.postSelector,
    'keywords': enabled.contains(CommonToggles.keywordFilter) ? keywords : const [],
    'feedCap': enabled.contains(CommonToggles.feedCap) ? feedCap : 0,
    'noAutoplay': enabled.contains(CommonToggles.noAutoplay),
    'blurMedia': enabled.contains(CommonToggles.blurMedia),
    'trackers': trackers,
    'media': mediaState,
    'mediaWarmup': site.mediaWarmup,
  };
  return cleanerJsTemplate.replaceFirst('__FF_CONFIG__', jsonEncode(config));
}
