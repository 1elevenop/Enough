<p align="center">
  <img src="branding/github/readme-banner.png" alt="Enough: your socials, without the scroll" width="100%">
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-ff2bd6.svg"></a>
  <img alt="Platform: Android" src="https://img.shields.io/badge/platform-Android-120d1a.svg">
  <img alt="Built with Flutter" src="https://img.shields.io/badge/built%20with-Flutter-ffe14d.svg">
</p>

**Enough** is an Android app that opens the mobile web versions of your social apps inside one calm, controlled browser. You keep messages, search and the people you follow. The feeds built to keep you scrolling (Reels, Shorts, Explore, For You) are hidden or blocked before they load.

> Not affiliated with, endorsed by or sponsored by any of the platforms below. All trademarks belong to their owners.

## Features

- **Feed cleaning.** Custom CSS and JavaScript are injected before each page finishes loading. A `MutationObserver` keeps removing distracting elements as new content streams in.
- **Route guard.** Navigation to restricted paths (`/shorts/`, `/reels/`, `/explore/`…) is intercepted and redirected to a safe page. A reel someone sends you in DMs still plays, but swiping to the next one is blocked.
- **Reels pass.** Unlock Reels / Shorts for a short window behind your PIN, followed by a cooldown.
- **Daily limits and focus hours.** Set per-site time limits, plus a "messages only" focus mode.
- **Insights.** See time spent per site, split into useful and endless-feed time, with streaks and a weekly report.
- **Privacy.** Tracker and ad-host blocking, a third-party cookie toggle, Private DNS presets, blank screenshots and recents preview, and per-site camera/mic decisions.
- **PIN lock.** Settings are protected by a PIN (salted PBKDF2, with lockout after repeated wrong tries) or biometrics, so you can't switch things off on impulse.

### Supported sites

YouTube · Instagram · Facebook · Messenger · X · Threads · Reddit · LinkedIn · Pinterest · Tumblr · Bluesky · Discord · Snapchat (web) · WhatsApp (web) · Telegram (web)

Snapchat for Web is limited by Snapchat itself: chat and calls work, but Memories, Stories management and most account settings do not, and login uses a QR code scanned from the official app.

## Build

Requirements: Flutter (Dart SDK ^3.13) and the Android SDK.

```sh
flutter pub get
flutter run                 # debug build on a connected device / emulator
flutter test                # unit tests
```

### Release builds

Release builds use R8 shrinking. Sign them with your own key. Create it once with `keytool` (it asks for passwords; never commit them):

```sh
keytool -genkey -v -keystore ~/keys/enough-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias enough
```

Copy `android/key.properties.example` to `android/key.properties` (gitignored) and fill it in. Then run:

```sh
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

Without `key.properties`, release builds fall back to the debug key and Gradle prints a warning.

## How it works

| Layer | What it does |
|---|---|
| `lib/sites/*.dart` | One config per platform: start URL, allowed hosts, CSS selectors to hide, route rules |
| `lib/services/cleaner_js.dart`, `injector.dart` | CSS/JS injected at document start; a `MutationObserver` re-applies the rules |
| `lib/services/route_guard.dart` | Classifies URLs and redirects restricted routes |
| `lib/services/trackers.dart` + `assets/trackers.json` | Native content blockers for known tracker hosts |
| `lib/screens/webview_screen.dart` | The WebView (`flutter_inappwebview`), permission handling and the JS bridge |

## Privacy

Everything stays on your device. Enough has no server, no account, no analytics and no ads. Settings and usage stats are stored locally and are **excluded from Android backups**, as are WebView cookies (your logged-in sessions). Traffic is HTTPS-only.

Your logins happen directly on each platform's own website inside the WebView. Enough never sees or stores your passwords.

## Security

See [SECURITY.md](SECURITY.md) for how to report a vulnerability.

## Contributing

Issues and pull requests are welcome. Before opening a PR, run `flutter analyze` and `flutter test` and make sure both pass. When a site changes its markup, the fix usually goes in that site's file under `lib/sites/`.

## License

[MIT](LICENSE) © 2026 Jaydeep G. (1elevenop)
