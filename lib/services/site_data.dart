import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/site_config.dart';

/// Signs out of [site] by deleting its cookies and web storage
/// (every origin under its allowed hosts).
Future<void> clearSiteData(SiteConfig site) async {
  final cm = CookieManager.instance();
  final urls = {
    for (final h in site.allowedHosts) ...['https://$h', 'https://www.$h', 'https://m.$h'],
    for (final u in [site.startUrl, site.safeRoute, ?site.messagesRoute])
      Uri.parse(u).replace(path: '/', query: '').toString(),
  };
  for (final u in urls) {
    final host = Uri.parse(u).host;
    await cm.deleteCookies(url: WebUri(u));
    await cm.deleteCookies(url: WebUri(u), domain: '.$host');
    final dot = host.indexOf('.');
    if (dot > 0 && host.indexOf('.', dot + 1) > 0) {
      await cm.deleteCookies(url: WebUri(u), domain: host.substring(dot));
    }
  }
  final storage = WebStorageManager.instance();
  for (final o in await storage.getOrigins()) {
    final host = Uri.tryParse(o.origin ?? '')?.host;
    if (host != null && site.ownsHost(host)) await storage.deleteOrigin(origin: o.origin!);
  }
}
