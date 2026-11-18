/// A switch the user can flip per site. Enabled toggles contribute CSS,
/// selectors to hide, and path patterns to block.
class FeatureToggle {
  const FeatureToggle({
    required this.id,
    required this.label,
    this.description = '',
    this.css = '',
    this.hideSelectors = const [],
    this.blockedPaths = const [],
    this.defaultOn = true,
    this.group = ToggleGroup.distraction,
  });

  final String id;
  final String label;
  final String description;

  /// Raw CSS injected at document start.
  final String css;

  /// Selectors hidden with `display:none !important`.
  final List<String> hideSelectors;

  /// Regex sources matched against the URL path; matches are redirected.
  final List<String> blockedPaths;

  final bool defaultOn;
  final ToggleGroup group;
}

enum ToggleGroup { distraction, wellbeing, filter }

/// Toggles every site gets. Their behaviour is driven by site-level
/// selectors (post, metric, media) in [SiteConfig].
class CommonToggles {
  static const grayscale = 'grayscale';
  static const blurMedia = 'blur_media';
  static const hideMetrics = 'hide_metrics';
  static const noAutoplay = 'no_autoplay';
  static const feedCap = 'feed_cap';
  static const keywordFilter = 'keyword_filter';

  static const List<FeatureToggle> all = [
    FeatureToggle(
      id: grayscale,
      label: 'Grayscale mode',
      description: 'Drains the colour so feeds feel less rewarding',
      defaultOn: false,
      group: ToggleGroup.wellbeing,
    ),
    FeatureToggle(
      id: hideMetrics,
      label: 'Hide likes and view counts',
      description: 'Removes the numbers that drive comparison',
      defaultOn: true,
      group: ToggleGroup.wellbeing,
    ),
    FeatureToggle(
      id: noAutoplay,
      label: 'No autoplay',
      description: 'Videos only play after you tap them',
      defaultOn: true,
      group: ToggleGroup.wellbeing,
    ),
    FeatureToggle(
      id: feedCap,
      label: 'Feed cap',
      description: 'Stops the feed after a set number of posts',
      defaultOn: true,
      group: ToggleGroup.wellbeing,
    ),
    FeatureToggle(
      id: blurMedia,
      label: 'Blur images and videos',
      description: 'Tap a blurred item to reveal it',
      defaultOn: false,
      group: ToggleGroup.filter,
    ),
    FeatureToggle(
      id: keywordFilter,
      label: 'Keyword filter',
      description: 'Hides posts containing words from your blocklist',
      defaultOn: true,
      group: ToggleGroup.filter,
    ),
  ];
}
