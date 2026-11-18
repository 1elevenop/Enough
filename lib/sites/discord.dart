import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';

const discord = SiteConfig(
  id: 'discord',
  name: 'Discord',
  glyph: FontAwesomeIcons.discord,
  color: Color(0xFF5865F2),
  gradient: [Color(0xFF8D96FF), Color(0xFF4752C4)],
  tagline: 'Friends and servers, no Discover',
  startUrl: 'https://discord.com/channels/@me',
  allowedHosts: ['discord.com', 'discordapp.com', 'discord.gg', 'discordapp.net', 'discord.media'],
  safeRoute: 'https://discord.com/channels/@me',
  messagesRoute: 'https://discord.com/channels/@me',
  messagesPaths: [r'^/channels/@me', r'^/login', r'^/register'],
  categories: {
    r'^/channels/@me': RouteCategory.messages,
    r'^/channels/': RouteCategory.profile, // server channels: neutral
    r'^/(discovery|guild-discovery|servers)': RouteCategory.feed,
  },
  commonToggles: [CommonToggles.grayscale, CommonToggles.noAutoplay],
  features: [
    FeatureToggle(
      id: 'block_discovery',
      label: 'Block server Discovery',
      description: 'No browsing for new servers to fall into',
      blockedPaths: [r'^/discovery', r'^/guild-discovery', r'^/servers'],
      hideSelectors: [
        '[data-list-item-id="guildsnav___guild-discover-button"]',
        r'div[aria-label="Discover"]',
        'a[href^="/discovery"]',
      ],
    ),
    FeatureToggle(
      id: 'hide_shop',
      label: 'Hide Nitro and Shop',
      blockedPaths: [r'^/store', r'^/shop', r'^/nitro'],
      hideSelectors: ['a[href="/store"]', 'a[href="/shop"]', 'a[href^="/nitro"]'],
    ),
  ],
);
