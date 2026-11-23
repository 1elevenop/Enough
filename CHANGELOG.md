# Changelog

All notable changes to Enough are listed here. Versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-23

First public release.

### Added
- Mobile web wrapper for YouTube, Instagram, Facebook, Messenger, X, Threads, Reddit, LinkedIn, Pinterest, Tumblr, Bluesky, Discord, Snapchat, WhatsApp and Telegram.
- Feed cleaning: CSS/JS injected at document start, kept applied by a `MutationObserver`.
- Route guard that blocks Reels, Shorts, Explore and For You feeds while letting shared reels play.
- Reels pass behind the PIN, with a cooldown.
- Per-site daily limits, focus hours and a messages-only mode.
- Insights: time per site, useful vs endless-feed time, streaks and a weekly report.
- Privacy controls: tracker and ad-host blocking, third-party cookie toggle, Private DNS presets, blank screenshots/recents preview, per-site camera/mic decisions.
- Settings PIN (salted PBKDF2 with lockout) or biometric lock.

### Security and privacy
- Inter and Inter Tight are bundled; no fonts are fetched from Google at runtime.
- App data and WebView cookies are excluded from Android backups; HTTPS only.
- Android application ID is `io.github.elevenop.enough`.
