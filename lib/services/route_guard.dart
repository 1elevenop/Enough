import '../models/site_config.dart';

sealed class RouteDecision {
  const RouteDecision();
}

class Allow extends RouteDecision {
  const Allow();
}

class Redirect extends RouteDecision {
  const Redirect(this.url, this.reason);
  final String url;
  final String reason;
}

class OpenExternally extends RouteDecision {
  const OpenExternally(this.url);
  final String url;
}

/// Toast text for a blocked short video; the WebView adds an Unlock action.
const reelsOffReason = 'Reels are off';

/// Decides what happens to a main-frame navigation.
class RouteGuard {
  /// With [shortVideoAllowed] (a Reels pass is running), the site's
  /// short-video rules are skipped.
  RouteGuard(this.site, Set<String> enabledIds,
      {this.messagesOnly = false, this.shortVideoAllowed = false})
      : blocked = [
          ...site.blockedPaths,
          if (!shortVideoAllowed) ...?site.shortVideo?.blockedPaths,
          for (final t in site.allToggles)
            if (enabledIds.contains(t.id)) ...t.blockedPaths,
        ].map(RegExp.new).toList(),
        allowedInFocus = [
          ...site.messagesPaths,
          // A reel tapped in a DM is still messaging.
          ...?site.shortVideo?.dmOnlyPaths,
        ].map(RegExp.new).toList(),
        dmOnly = [if (!shortVideoAllowed) ...?site.shortVideo?.dmOnlyPaths]
            .map(RegExp.new)
            .toList(),
        dmSource = site.dmSourcePaths.map(RegExp.new).toList();

  final SiteConfig site;
  final bool messagesOnly;
  final bool shortVideoAllowed;
  final List<RegExp> blocked;
  final List<RegExp> allowedInFocus;
  final List<RegExp> dmOnly;
  final List<RegExp> dmSource;

  List<String> get dmOnlySources => dmOnly.map((r) => r.pattern).toList();
  List<String> get dmSourceSources => dmSource.map((r) => r.pattern).toList();

  /// Regex sources the injected JS uses to block SPA navigations itself.
  List<String> get blockedSources => blocked.map((r) => r.pattern).toList();
  List<String> get focusSources =>
      allowedInFocus.map((r) => r.pattern).toList();

  String get _focusTarget => site.messagesRoute ?? site.safeRoute;

  /// [fromPath] is the path of the page the user is leaving, if known.
  RouteDecision check(Uri uri, {String? fromPath}) {
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      // intent://, market:// etc. — never load those inside the WebView.
      return uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob'
          ? const Allow()
          : OpenExternally(uri.toString());
    }
    if (!site.ownsHost(uri.host)) return OpenExternally(uri.toString());

    final path = uri.path.isEmpty ? '/' : uri.path;
    if (messagesOnly && !allowedInFocus.any((r) => r.hasMatch(path))) {
      if (_samePage(uri, _focusTarget)) return const Allow();
      return Redirect(_focusTarget, 'Focus hours: messages only');
    }
    if (blocked.any((r) => r.hasMatch(path))) {
      if (_samePage(uri, site.safeRoute)) return const Allow();
      final short = !shortVideoAllowed &&
          (site.shortVideo?.blockedPaths ?? const <String>[])
              .any((p) => RegExp(p).hasMatch(path));
      return Redirect(site.safeRoute, short ? reelsOffReason : 'Blocked to keep you focused');
    }
    if (dmOnly.any((r) => r.hasMatch(path))) {
      final fromDm = fromPath != null && dmSource.any((r) => r.hasMatch(fromPath));
      if (!fromDm) {
        return Redirect(site.messagesRoute ?? site.safeRoute,
            'Reels only open from your DMs');
      }
    }
    return const Allow();
  }

  static bool _samePage(Uri a, String b) {
    final u = Uri.parse(b);
    return a.host == u.host && a.path == u.path;
  }
}
