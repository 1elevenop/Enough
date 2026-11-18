import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/site_config.dart';
import '../services/injector.dart';
import '../services/limit_guard.dart';
import '../services/reels_pass.dart';
import '../services/route_guard.dart';
import '../services/settings_store.dart';
import '../services/site_data.dart';
import '../services/trackers.dart';
import '../services/usage_stats.dart';
import '../services/usage_tracker.dart';
import '../sites/youtube.dart';
import '../theme.dart';
import '../widgets/site_glyph.dart';
import '../widgets/media_permission.dart';
import '../widgets/pin_gate.dart';
import '../widgets/reels_pass_sheet.dart';
import 'site_settings_screen.dart';
import '../widgets/quote_line.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    super.key,
    required this.site,
    this.initialUrl,
    this.sessionLength,
    this.messagesOnly = false,
  });

  final SiteConfig site;
  final String? initialUrl;
  final Duration? sessionLength;
  final bool messagesOnly;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with WidgetsBindingObserver {
  final _settings = SettingsStore.instance;
  final _tracker = UsageTracker.instance;

  InAppWebViewController? _web;
  late RouteGuard _guard;
  late String _script;
  String? _userAgent;
  bool _ready = false;
  double _progress = 0;

  Timer? _ticker;
  DateTime? _sessionEnd;
  LimitStatus _status = const LimitStatus(LimitLevel.none, Duration.zero, Duration.zero);
  bool _sessionOver = false;
  bool _counting = true;
  bool _passActive = false;

  /// What a page's camera/mic request will get: granted, denied or prompt.
  String? _mediaState;

  SiteConfig get site => widget.site;
  String get _startUrl => widget.initialUrl ?? site.startUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _buildRules();
    if (widget.sessionLength != null) {
      _sessionEnd = DateTime.now().add(widget.sessionLength!);
    }
    _tracker.enterSite(site.id, site.categorize(Uri.parse(_startUrl).path));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
    _prepare();
  }

  void _buildRules() {
    final enabled = _settings.enabledIds(site);
    _passActive = site.shortVideo != null && _settings.reelsPass.isActive(DateTime.now());
    _guard = RouteGuard(site, enabled,
        messagesOnly: widget.messagesOnly, shortVideoAllowed: _passActive);
    _script = buildInjection(
      site: site,
      enabled: enabled,
      guard: _guard,
      keywords: _settings.blocklist,
      feedCap: _settings.feedCapCount,
      trackers: _settings.blockTrackers ? TrackerList.instance.forSite(site) : const [],
      mediaState: _mediaState,
    );
  }

  Future<void> _prepare() async {
    if (site.needsMedia) {
      _mediaState = switch (_settings.mediaDecision(site.id)) {
        MediaDecision.deny => 'denied',
        MediaDecision.ask => 'prompt',
        MediaDecision.allow =>
          await Permission.camera.isGranted && await Permission.microphone.isGranted
              ? 'granted'
              : 'prompt',
      };
      _buildRules();
    }
    if (site.id == youtube.id) await _applyRestrictedMode();
    if (site.stripWebViewUa || site.desktopMode) {
      var ua = await InAppWebViewController.getDefaultUserAgent();
      ua = ua.replaceAll('; wv', '').replaceAll(RegExp(r'Version/\d+\.\d+ '), '');
      if (site.desktopMode) {
        // Same Chrome version, desktop Linux platform, no "Mobile".
        ua = ua
            .replaceFirst(RegExp(r'\([^)]*Android[^)]*\)'), '(X11; Linux x86_64)')
            .replaceAll(' Mobile', '');
      }
      _userAgent = ua;
    }
    if (mounted) setState(() => _ready = true);
  }

  /// YouTube Restricted Mode lives in bit f2=8000000 of the PREF cookie.
  Future<void> _applyRestrictedMode() async {
    final on = _settings.enabledIds(site).contains(youtubeRestrictedMode);
    final url = WebUri('https://www.youtube.com');
    final cm = CookieManager.instance();
    final existing = await cm.getCookie(url: url, name: 'PREF');
    final parts = <String, String>{};
    for (final kv in (existing?.value?.toString() ?? '').split('&')) {
      final i = kv.indexOf('=');
      if (i > 0) parts[kv.substring(0, i)] = kv.substring(i + 1);
    }
    if (on) {
      parts['f2'] = '8000000';
    } else {
      parts.remove('f2');
    }
    await cm.setCookie(
      url: url,
      name: 'PREF',
      value: parts.entries.map((e) => '${e.key}=${e.value}').join('&'),
      domain: '.youtube.com',
      path: '/',
      isSecure: true,
      expiresDate: DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch,
    );
  }

  static const _native = MethodChannel('focusfeed/webview');

  /// Sets client hints on the native WebView (Chrome brand, and desktop
  /// for desktop-mode sites) before the first request, then loads the page.
  bool get _nativeHints => site.desktopMode || site.stripWebViewUa;

  Future<void> _startDesktop(InAppWebViewController c) async {
    // Let the platform view attach to the window so native code can find it.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    String status;
    try {
      status = await _native.invokeMethod<String>(site.desktopMode ? 'desktopClientHints' : 'chromeClientHints') ?? 'null';
    } on PlatformException catch (e) {
      status = 'error ${e.code}';
    }
    if (kDebugMode) debugPrint('[desktop] client hints: $status');
    if (status == 'unsupported') {
      _toast('This phone\'s WebView can\'t fully pose as desktop. Snapchat may refuse.');
    }
    await c.loadUrl(urlRequest: URLRequest(url: WebUri(_startUrl)));
  }

  // ---- time limits -----------------------------------------------------
  void _tick() {
    final now = DateTime.now();
    final status = limitStatus(
      used: _tracker.usedToday(site.id),
      limitMinutes: _settings.dailyLimit(site.id),
      snoozed: _settings.snoozeUsed(site.id, now),
    );
    final sessionOver = _sessionEnd != null && now.isAfter(_sessionEnd!);
    final blocked = status.level == LimitLevel.blocked || sessionOver;
    if (blocked && _counting) {
      _counting = false;
      _tracker.leaveSite();
      _pauseMedia();
    } else if (!blocked && !_counting) {
      _counting = true;
      _tracker.enterSite(site.id, RouteCategory.feed);
      _refreshCategory();
    }
    if (site.shortVideo != null && _settings.reelsPass.isActive(now) != _passActive) {
      final ended = _passActive;
      _applyRules();
      if (ended && mounted) showReelsTimeUp(context);
    }
    if (mounted) {
      setState(() {
        _status = status;
        _sessionOver = sessionOver;
      });
    }
  }

  void _pauseMedia() => _web?.evaluateJavascript(
      source: "document.querySelectorAll('video,audio').forEach(function(m){m.pause()})");

  Future<void> _snooze() async {
    await _settings.useSnooze(site.id, DateTime.now());
    _tick();
  }

  // ---- navigation ------------------------------------------------------
  Future<void> _refreshCategory() async {
    final url = await _web?.getUrl();
    if (url != null) _onUrl(url);
  }

  /// Path of the page currently shown, used to tell if a reel was opened
  /// from a DM.
  String? _lastPath;

  void _onUrl(Uri url) {
    if (!site.ownsHost(url.host)) return;
    final path = url.path.isEmpty ? '/' : url.path;
    // The same URL arrives from several callbacks; only check real changes.
    if (path != _lastPath) {
      final decision = _guard.check(url, fromPath: _lastPath);
      if (kDebugMode) {
        debugPrint('[guard] ${_mask(_lastPath)} -> ${_mask(path)}: '
            '${decision is Redirect ? 'REDIRECT ${decision.reason}' : 'allow'}');
      }
      if (decision is Redirect) {
        _web?.loadUrl(urlRequest: URLRequest(url: WebUri(decision.url)));
        _toast(decision.reason);
        return;
      }
      _lastPath = path;
    }
    final cat = site.categorize(path);
    if (_counting) _tracker.setCategory(cat);
    _web?.evaluateJavascript(
        source: 'window.__ffSetCap && window.__ffSetCap(${cat == RouteCategory.feed})');
  }

  /// Hides ids and usernames in debug logs, keeping the route's shape.
  static String _mask(String? p) => p == null
      ? 'start'
      : p
          .replaceAll(RegExp(r'/t/[^/]+'), '/t/<chat>')
          .replaceAll(RegExp(r'/(reels?|p)/[^/]+'), r'/$1/<id>')
          .replaceAll(RegExp(r'^/(?!direct|reels?/|explore|accounts)[^/]+/'), '/<user>/');

  Future<NavigationActionPolicy> _shouldOverride(
      InAppWebViewController c, NavigationAction action) async {
    final url = action.request.url;
    if (url == null || !action.isForMainFrame) return NavigationActionPolicy.ALLOW;
    switch (_guard.check(url, fromPath: _lastPath)) {
      case Allow():
        return NavigationActionPolicy.ALLOW;
      case Redirect(:final url, :final reason):
        c.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
        _toast(reason);
        return NavigationActionPolicy.CANCEL;
      case OpenExternally(:final url):
        final uri = Uri.tryParse(url);
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return NavigationActionPolicy.CANCEL;
    }
  }

  DateTime _lastToast = DateTime(2000);
  void _toast(String msg) {
    if (!mounted || DateTime.now().difference(_lastToast).inSeconds < 3) return;
    _lastToast = DateTime.now();
    final unlock = msg == reelsOffReason && site.shortVideo != null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: Duration(seconds: unlock ? 4 : 2),
        action: unlock ? SnackBarAction(label: 'Unlock', onPressed: _reelsPass) : null,
      ));
  }

  Future<void> _openSettings() async {
    if (!await requireUnlock(context) || !mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => SiteSettingsScreen(site: site)));
    if (!mounted) return;
    await _applyRules();
  }

  /// Rebuilds the injected rules and reloads so changes apply at once.
  Future<void> _applyRules() async {
    _buildRules();
    await _web?.removeAllUserScripts();
    await _web?.addUserScript(userScript: _userScript());
    if (site.id == youtube.id) await _applyRestrictedMode();
    await _web?.reload();
  }

  Future<void> _reelsPass() async {
    if (await openReelsPass(context) && mounted) await _applyRules();
  }

  UserScript _userScript() => UserScript(
        source: _script,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
      );

  // ---- lifecycle -------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tracker.resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _tracker.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _tracker.leaveSite();
    if (_settings.forgetOnClose(site.id)) clearSiteData(site);
    super.dispose();
  }

  // ---- UI --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final blocked = _status.level == LimitLevel.blocked || _sessionOver;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (!blocked && await _web?.canGoBack() == true) {
          await _web!.goBack();
        } else {
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 56,
          centerTitle: false,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Row(children: [
            SiteGlyph(site: site, size: 28),
            const SizedBox(width: 10),
            Text(site.name, style: Theme.of(context).textTheme.titleMedium),
            if (widget.messagesOnly) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Tokens.of(context).surfaceSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Focus', style: Theme.of(context).textTheme.labelSmall),
              ),
            ],
          ]),
          actions: [
            _TimeChip(status: _status, sessionEnd: _sessionEnd),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              color: Tokens.of(context).surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onSelected: (v) => switch (v) {
                'reload' => _web?.reload(),
                'reels' => _reelsPass(),
                _ => _openSettings(),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'reload', child: Text('Reload')),
                if (site.shortVideo != null)
                  PopupMenuItem(value: 'reels', child: Text(reelsPassLabel(DateTime.now()))),
                const PopupMenuItem(value: 'settings', child: Text('Limits and filters')),
              ],
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: AnimatedOpacity(
              opacity: _progress < 1 ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: site.color,
              ),
            ),
          ),
        ),
        body: Stack(children: [
          if (_ready)
            InAppWebView(
              // Desktop mode starts blank so the client hints are set
              // natively before the first request goes out.
              initialUrlRequest:
                  _nativeHints ? null : URLRequest(url: WebUri(_startUrl)),
              initialUserScripts: UnmodifiableListView([_userScript()]),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                thirdPartyCookiesEnabled: _settings.thirdPartyCookies,
                contentBlockers: _settings.blockTrackers
                    ? TrackerList.instance.blockersFor(site)
                    : const [],
                useShouldOverrideUrlLoading: true,
                useHybridComposition: true,
                mediaPlaybackRequiresUserGesture: !site.needsMedia,
                allowsInlineMediaPlayback: true,
                supportMultipleWindows: false,
                userAgent: _userAgent ?? '',
                preferredContentMode: site.desktopMode
                    ? UserPreferredContentMode.DESKTOP
                    : UserPreferredContentMode.RECOMMENDED,
                useWideViewPort: true,
                loadWithOverviewMode: site.desktopMode,
                builtInZoomControls: site.desktopMode,
                displayZoomControls: false,
              ),
              onWebViewCreated: (c) {
                _web = c;
                if (_nativeHints) _startDesktop(c);
                // The bridge is visible to every script on the page, so only
                // the site's own top frame may call it, and args are checked.
                void handle(String name, void Function(List<dynamic> args) f,
                    {bool ownHostOnly = false}) {
                  c.addJavaScriptHandler(
                      handlerName: name,
                      callback: (JavaScriptHandlerFunctionData d) {
                        if (!d.isMainFrame) return;
                        if (ownHostOnly && !site.ownsHost(d.origin.host)) return;
                        f(d.args);
                      });
                }

                handle('activity', (_) => _tracker.activity());
                handle('routeChanged', (args) {
                  final a = args.isEmpty ? null : args.first;
                  if (a is! String || a.length > 4096) return;
                  final u = Uri.tryParse(a);
                  if (u != null && (u.scheme == 'https' || u.scheme == 'http')) _onUrl(u);
                }, ownHostOnly: true);
                handle('reelSwipeBlocked', (_) {
                  if (kDebugMode) debugPrint('[guard] DM reel viewer: swipe blocked');
                  _toast('Only the reel sent to you. Swiping is off.');
                }, ownHostOnly: true);
                handle('trackers', (args) {
                  final a = args.isEmpty ? null : args.first;
                  final n = a is num ? a.toInt().clamp(0, 500) : 0;
                  if (n > 0) _settings.addTrackersBlocked(DateTime.now(), n);
                }, ownHostOnly: true);
                handle('goHome', (_) {
                  if (mounted) Navigator.of(context).pop();
                });
              },
              shouldOverrideUrlLoading: _shouldOverride,
              onUpdateVisitedHistory: (c, url, _) {
                if (url != null) _onUrl(url);
              },
              onLoadStop: (c, url) {
                if (url != null) _onUrl(url);
              },
              onProgressChanged: (c, p) => setState(() => _progress = p / 100),
              onPermissionRequest: (c, req) => handleMediaRequest(context, site, req),
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (_status.level == LimitLevel.warning && !blocked)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _Banner(
                  text: '${formatDuration(_status.remaining)} left on ${site.name} today'),
            ),
          if (blocked)
            Positioned.fill(
              child: _BlockedOverlay(
                site: site,
                sessionOver: _sessionOver,
                canSnooze: !_sessionOver && !_settings.snoozeUsed(site.id, DateTime.now()),
                onSnooze: _snooze,
              ),
            ),
        ]),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.status, required this.sessionEnd});
  final LimitStatus status;
  final DateTime? sessionEnd;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    Duration? left;
    if (sessionEnd != null) left = sessionEnd!.difference(DateTime.now());
    if (status.level != LimitLevel.none &&
        (left == null || status.remaining < left)) {
      left = status.remaining;
    }
    if (left == null) return const SizedBox.shrink();
    if (left.isNegative) left = Duration.zero;
    final warn = left.inMinutes < 5;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: warn ? Tokens.danger.withValues(alpha: .12) : t.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timelapse_rounded, size: 14, color: warn ? Tokens.danger : t.muted),
          const SizedBox(width: 5),
          Text(
            '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: warn ? Tokens.danger : t.ink),
          ),
        ]),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Material(
      color: t.ink,
      borderRadius: BorderRadius.circular(20),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: t.canvas, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class _BlockedOverlay extends StatelessWidget {
  const _BlockedOverlay({
    required this.site,
    required this.sessionOver,
    required this.canSnooze,
    required this.onSnooze,
  });
  final SiteConfig site;
  final bool sessionOver;
  final bool canSnooze;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    final c = site.gradient.isNotEmpty ? site.gradient.last : site.color;
    return ColoredBox(
      color: t.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            const Spacer(flex: 3),
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(alignment: Alignment.center, children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                          colors: [c.withValues(alpha: .55), c.withValues(alpha: 0)]),
                    ),
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: t.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Icon(sessionOver ? Icons.hourglass_empty_rounded : Icons.lock_rounded,
                      size: 26, color: t.ink),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text(sessionOver ? 'Session complete' : 'That\'s enough for today',
                textAlign: TextAlign.center, style: text.headlineMedium),
            const SizedBox(height: 10),
            Text(
              sessionOver
                  ? 'You set this session yourself, and you kept it.'
                  : '${site.name} is resting until midnight.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: t.muted),
            ),
            const SizedBox(height: 28),
            const QuoteLine(),
            const Spacer(flex: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back home'),
              ),
            ),
            if (canSnooze)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton(
                  onPressed: onSnooze,
                  child: Text('Five more minutes',
                      style: text.labelLarge?.copyWith(color: t.muted)),
                ),
              ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
