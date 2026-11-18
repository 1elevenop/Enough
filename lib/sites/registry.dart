import '../models/site_config.dart';
import 'bluesky.dart';
import 'discord.dart';
import 'facebook.dart';
import 'instagram.dart';
import 'linkedin.dart';
import 'messenger.dart';
import 'pinterest.dart';
import 'reddit.dart';
import 'snapchat.dart';
import 'telegram.dart';
import 'threads.dart';
import 'tumblr.dart';
import 'whatsapp.dart';
import 'x.dart';
import 'youtube.dart';

/// Every supported social, in the order the add sheet shows them.
const List<SiteConfig> sites = [
  instagram,
  youtube,
  snapchat,
  discord,
  reddit,
  xSite,
  threads,
  facebook,
  pinterest,
  whatsapp,
  telegram,
  messenger,
  linkedin,
  bluesky,
  tumblr,
];

SiteConfig? siteByIdOrNull(String id) {
  for (final s in sites) {
    if (s.id == id) return s;
  }
  return null;
}

SiteConfig siteById(String id) => siteByIdOrNull(id)!;
