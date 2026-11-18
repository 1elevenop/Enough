import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/site_config.dart';

/// Well-known analytics and ad hosts (assets/trackers.json), matched as
/// domain suffixes. A site's own [SiteConfig.allowedHosts] are never blocked
/// on that site.
class TrackerList {
  TrackerList(this.hosts);

  static TrackerList? _instance;
  static TrackerList get instance => _instance ?? TrackerList(const []);

  static Future<void> load() async {
    final raw = jsonDecode(await rootBundle.loadString('assets/trackers.json'));
    _instance = TrackerList(List<String>.from(raw['hosts'] as List));
  }

  final List<String> hosts;

  static bool _under(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

  /// Hosts to block on [site]: drops any the site owns or depends on.
  List<String> forSite(SiteConfig site) => [
        for (final h in hosts)
          if (!site.allowedHosts.any((a) => _under(h, a) || _under(a, h))) h,
      ];

  bool blocks(SiteConfig site, String host) =>
      forSite(site).any((h) => _under(host, h));

  /// Full-URL regex for the content blocker (Android matches the whole URL).
  static String urlPattern(List<String> hosts) {
    final alt = hosts.map(RegExp.escape).join('|');
    return r'^https?://([^/?#]*\.)?(' '$alt' r')([:/?#].*)?$';
  }

  List<ContentBlocker> blockersFor(SiteConfig site) {
    final list = forSite(site);
    if (list.isEmpty) return const [];
    return [
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: urlPattern(list)),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
    ];
  }
}
