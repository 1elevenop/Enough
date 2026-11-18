import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/site_config.dart';
import '../services/native.dart';
import '../services/settings_store.dart';
import '../services/site_data.dart';
import '../sites/registry.dart';
import '../theme.dart';
import '../widgets/site_glyph.dart';

class _Dns {
  const _Dns(this.name, this.host, this.blurb);
  final String name, host, blurb;
}

const _presets = [
  _Dns('Cloudflare', 'one.one.one.one', 'Fast, no filtering'),
  _Dns('Cloudflare Family', 'family.cloudflare-dns.com', 'Blocks malware and adult sites'),
  _Dns('AdGuard', 'dns.adguard-dns.com', 'Blocks ads and trackers'),
  _Dns('AdGuard Family', 'family.adguard-dns.com', 'Ads, trackers and adult sites'),
  _Dns('Quad9', 'dns.quad9.net', 'Blocks known malicious domains'),
];

/// Private DNS presets, tracker blocking, screen privacy and per-site data.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> with WidgetsBindingObserver {
  final _s = SettingsStore.instance;
  (String?, String?) _dns = (null, null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readDns();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readDns();
  }

  Future<void> _readDns() async {
    final d = await Native.privateDns();
    if (mounted) setState(() => _dns = d);
  }

  String get _dnsStatus => switch (_dns) {
        (null, _) => 'Current setting unknown',
        ('off', _) => 'Private DNS is off',
        ('opportunistic', _) => 'Private DNS is automatic',
        ('hostname', final h) => 'Using ${_nameFor(h)}',
        (final m, _) => 'Private DNS: $m',
      };

  /// Android keeps the last hostname even in "automatic" mode, so only a
  /// hostname-mode setting counts as in use.
  bool _inUse(String host) => _dns.$1 == 'hostname' && _dns.$2 == host;

  static String _nameFor(String? host) {
    for (final p in _presets) {
      if (p.host == host) return '${p.name} ($host)';
    }
    if (host != null && host.endsWith('.dns.nextdns.io')) return 'NextDNS';
    return host ?? 'a custom server';
  }

  Future<void> _use(String host) async {
    await Clipboard.setData(ClipboardData(text: host));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      content: Text('Copied $host. In Settings, open Private DNS (on Samsung: '
          'More connection settings), choose "Hostname" and paste it.'),
    ));
    await Native.openNetworkSettings();
  }

  Future<void> _nextDns() async {
    final c = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('NextDNS'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Configuration ID', hintText: 'e.g. abc123'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Use')),
        ],
      ),
    );
    if (id == null || !RegExp(r'^[a-zA-Z0-9]{4,16}$').hasMatch(id)) return;
    await _use('${id.toLowerCase()}.dns.nextdns.io');
  }

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListenableBuilder(
        listenable: _s,
        builder: (context, _) => ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          const _Header('Private DNS'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '$_dnsStatus. A DNS provider can block trackers and harmful sites for '
              'every app on this phone. Enough never changes system settings: tap a '
              'provider to copy its hostname and open Android\'s settings.',
              style: text.bodySmall?.copyWith(color: t.muted),
            ),
          ),
          for (final p in _presets)
            ListTile(
              leading: Icon(
                _inUse(p.host) ? Icons.check_circle_rounded : Icons.dns_outlined,
                color: _inUse(p.host) ? Tokens.accent : null,
              ),
              title: Text(p.name),
              subtitle: Text('${p.blurb} · ${p.host}'),
              onTap: () => _use(p.host),
            ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('NextDNS'),
            subtitle: const Text('Your own filter list · enter your ID'),
            onTap: _nextDns,
          ),
          const _Header('Web'),
          SwitchListTile(
            title: const Text('Block trackers'),
            subtitle: Text(_s.blockTrackers
                ? '${_s.trackersBlocked(DateTime.now())} blocked today. '
                    'Analytics and ad hosts never load.'
                : 'Analytics and ad hosts load normally'),
            value: _s.blockTrackers,
            onChanged: (v) => _s.setPrivacy(trackers: v),
          ),
          SwitchListTile(
            title: const Text('Allow third-party cookies'),
            subtitle: const Text('Some logins (Google, Facebook) need them. '
                'Turning this off can sign you out or break login.'),
            value: _s.thirdPartyCookies,
            onChanged: (v) => _s.setPrivacy(thirdPartyCookies: v),
          ),
          const ListTile(
            leading: Icon(Icons.edit_off_outlined),
            title: Text('No form history'),
            subtitle: Text('The browser inside Enough keeps no autofill history. '
                'Your password manager still works as usual.'),
          ),
          const _Header('Screen'),
          SwitchListTile(
            title: const Text('Screen privacy'),
            subtitle: const Text('Blocks screenshots and hides Enough in recent apps'),
            value: _s.screenPrivacy,
            onChanged: (v) async {
              await _s.setPrivacy(screen: v);
              await Native.setSecure(v);
            },
          ),
          const _Header('Your sites'),
          for (final site in _sites())
            ListTile(
              leading: SiteGlyph(site: site, size: 34),
              title: Text(site.name),
              subtitle: Text(_siteSummary(site)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => _SiteSheet(site: site),
              ),
            ),
        ]),
      ),
    );
  }

  List<SiteConfig> _sites() => [
        for (final id in _s.homeSites)
          if (siteByIdOrNull(id) case final s? when !s.isExternal) s,
      ];

  String _siteSummary(SiteConfig site) => [
        if (site.needsMedia) 'Camera: ${_mediaLabel(_s.mediaDecision(site.id))}',
        if (_s.forgetOnClose(site.id)) 'Forgets on close',
      ].join(' · ').ifEmpty('Data kept between visits');
}

String _mediaLabel(MediaDecision d) => switch (d) {
      MediaDecision.ask => 'ask',
      MediaDecision.allow => 'allowed',
      MediaDecision.deny => 'blocked',
    };

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _SiteSheet extends StatelessWidget {
  const _SiteSheet({required this.site});
  final SiteConfig site;

  @override
  Widget build(BuildContext context) {
    final s = SettingsStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 20),
          SiteGlyph(site: site, size: 44),
          const SizedBox(height: 10),
          Text(site.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (site.needsMedia)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Camera and microphone'),
                const SizedBox(height: 8),
                SegmentedButton<MediaDecision>(
                  segments: const [
                    ButtonSegment(value: MediaDecision.ask, label: Text('Ask')),
                    ButtonSegment(value: MediaDecision.allow, label: Text('Allow')),
                    ButtonSegment(value: MediaDecision.deny, label: Text('Block')),
                  ],
                  selected: {s.mediaDecision(site.id)},
                  onSelectionChanged: (v) => s.setMediaDecision(site.id, v.first),
                ),
              ]),
            ),
          SwitchListTile(
            title: const Text('Forget on close'),
            subtitle: const Text('Sign out and clear data each time you leave'),
            value: s.forgetOnClose(site.id),
            onChanged: (v) => s.setForgetOnClose(site.id, v),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Tokens.danger),
            title: const Text('Sign out and clear data',
                style: TextStyle(color: Tokens.danger)),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Clear ${site.name} data?'),
                  content: const Text('You\'ll be signed out. Cookies and stored '
                      'data for this site are deleted.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (ok != true) return;
              await clearSiteData(site);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${site.name} data cleared')));
              }
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Tokens.of(context).muted, letterSpacing: 0.8)),
      );
}
