import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/site_config.dart';
import '../services/settings_store.dart';
import '../theme.dart';
import 'site_glyph.dart';

final _mediaTypes = [
  PermissionResourceType.CAMERA,
  PermissionResourceType.MICROPHONE,
  PermissionResourceType.CAMERA_AND_MICROPHONE,
];

/// Handles a page's camera/microphone request: our own per-site prompt,
/// then the Android runtime permission. Grants only the camera/mic subset;
/// everything else is denied.
Future<PermissionResponse> handleMediaRequest(
    BuildContext context, SiteConfig site, PermissionRequest req) async {
  if (kDebugMode) debugPrint('[media] ${site.id} asks for ${req.resources}');
  final media = req.resources.where(_mediaTypes.contains).toList();
  PermissionResponse deny() =>
      PermissionResponse(resources: req.resources, action: PermissionResponseAction.DENY);
  if (!site.needsMedia || media.isEmpty) return deny();

  final store = SettingsStore.instance;
  var decision = store.mediaDecision(site.id);
  if (decision == MediaDecision.deny) return deny();
  if (decision == MediaDecision.ask) {
    if (!context.mounted) return deny();
    final ok = await _askSheet(context, site, media);
    if (ok == null) return deny(); // dismissed: ask again next time
    decision = ok ? MediaDecision.allow : MediaDecision.deny;
    await store.setMediaDecision(site.id, decision);
    if (!ok) return deny();
  }

  final wantsCam = media.any((r) => r != PermissionResourceType.MICROPHONE);
  final wantsMic = media.any((r) => r != PermissionResourceType.CAMERA);
  final perms = [if (wantsCam) Permission.camera, if (wantsMic) Permission.microphone];
  final results = await perms.request();
  if (results.values.every((s) => s.isGranted)) {
    return PermissionResponse(resources: media, action: PermissionResponseAction.GRANT);
  }
  if (results.values.any((s) => s.isPermanentlyDenied) && context.mounted) {
    await _settingsSheet(context, site);
  }
  return deny();
}

String _what(List<PermissionResourceType> media) {
  final cam = media.any((r) => r != PermissionResourceType.MICROPHONE);
  final mic = media.any((r) => r != PermissionResourceType.CAMERA);
  return cam && mic ? 'camera and microphone' : (cam ? 'camera' : 'microphone');
}

Future<bool?> _askSheet(
        BuildContext context, SiteConfig site, List<PermissionResourceType> media) =>
    showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => _Sheet(
        site: site,
        title: '${site.name} wants your ${_what(media)}',
        body: 'For calls and snaps. Enough remembers your answer for '
            '${site.name}; you can change it in Settings → Privacy.',
        primary: 'Allow',
        onPrimary: () => Navigator.pop(ctx, true),
        secondary: 'Don\'t allow',
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );

Future<void> _settingsSheet(BuildContext context, SiteConfig site) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _Sheet(
        site: site,
        title: 'Android is blocking the camera',
        body: 'Enough was denied camera or microphone access earlier. '
            'Turn it on in Android settings, then try again.',
        primary: 'Open settings',
        onPrimary: () {
          Navigator.pop(ctx);
          openAppSettings();
        },
        secondary: 'Not now',
        onSecondary: () => Navigator.pop(ctx),
      ),
    );

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.site,
    required this.title,
    required this.body,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
  });
  final SiteConfig site;
  final String title, body, primary, secondary;
  final VoidCallback onPrimary, onSecondary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SiteGlyph(site: site, size: 44),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: text.titleLarge),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: Tokens.of(context).muted)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onPrimary, child: Text(primary)),
          ),
          TextButton(onPressed: onSecondary, child: Text(secondary)),
        ]),
      ),
    );
  }
}
