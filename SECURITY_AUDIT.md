# Security audit: 2026-11-18

Scope: the whole repository, before its first public release. Enough is an **on-device Android app with no backend**: no server, API, database server, accounts or analytics. Checklist items that only apply to a server are marked N/A, with the reason.

| # | Item | Result |
|---|---|---|
| 1 | Hide API keys | **Fine.** The app uses no API keys. A scan of every publishable file found no keys, tokens or private keys. |
| 2 | Check env variables | **Fine.** No `.env` files. Gitignored as a precaution. |
| 3 | Protect admin routes | N/A: no server. The equivalent is the settings lock (see 4). |
| 4 | Proper authentication | **Fixed.** The settings PIN was unsalted SHA-256 (brute-forceable instantly). It is now PBKDF2-HMAC-SHA256 with a random 16-byte salt and 30k iterations, verified in a background isolate. Legacy hashes migrate automatically on the next correct entry. `lib/services/pin_hash.dart`, `lib/services/settings_store.dart` |
| 5 | Check user access | **Fixed.** The JS bridge (`window.flutter_inappwebview.callHandler`) can be reached by any script or iframe on the page. Handlers now accept calls only from the main frame, and URL/tracker handlers only from the site's own hosts. `lib/screens/webview_screen.dart` |
| 6 | Sanitize forms | **Fixed.** Bridge arguments are type-checked and bounded (URL ≤ 4096 chars, http/https only; tracker count clamped to 0–500). The PIN input is digits-only, 4–8. |
| 7 | Protect against XSS | **Fine/Fixed.** No app-generated HTML; injected scripts are static. Bridge hardening (5, 6) limits what hostile page scripts can do. Only the platforms' own sites are loaded. |
| 8 | Rate limiting | **Fixed (local equivalent).** PIN lockout after 5 wrong tries: 30 s, doubling up to 15 min, persisted across restarts. |
| 9 | Secure API endpoints | N/A: the app exposes none. The only exported component is the launcher activity. |
| 10 | CORS settings | N/A: no server. |
| 11 | Security headers | N/A for a server. Client equivalent: `network_security_config.xml` enforces HTTPS only and trusts system CAs only. |
| 12 | Debug mode off | **Fine/Fixed.** WebView remote debugging runs only under `kDebugMode`. Release builds are now minified and shrunk with R8, and Dart code is obfuscated (`--obfuscate --split-debug-info`). |
| 13 | Update dependencies | **Done.** `flutter pub upgrade` moved 10 transitive packages. `flutter_inappwebview 6.2.0-beta.3` is the newest release available (no stable 6.x newer). |
| 14 | Remove unused packages | **Done.** Removed `cupertino_icons` (never used). Every other dependency is imported. |
| 15 | Exposed files | **Fixed.** `.gitignore` now also excludes `.claude/`, `CLAUDE.md`, `plan-*.md`, `android/.kotlin/`, `key.properties`, keystores, `.env*` and `build/symbols/`. PNG exports were stripped of XMP metadata (timestamps/timezone). |
| 16 | Secure database | **Fixed.** Usage data (sqflite), settings and **WebView cookies (logged-in sessions)** were eligible for cloud and adb backup. Backups and device-to-device transfer are now disabled (`allowBackup=false`, `data_extraction_rules.xml`, `backup_rules.xml`). Data lives in app-private storage. |
| 17 | Hash passwords properly | **Fixed.** See 4. Platform passwords are entered on the platforms' own pages and never touched by the app. |
| 18 | Git leaked secrets | **Fine.** The folder had no git history. The repo was initialised fresh, and a pre-commit scan of all publishable files found only intended items (author name in LICENSE/README; `key.properties` *property names* in Gradle). |
| 19 | Full audit | This document. Release APK built, installed on a physical device, launched and opened a site, with no runtime errors. Verified `allowBackup=false`, the cleartext ban and the network config in the built manifest. |
| 20 | No mistakes | `flutter analyze`: no issues. `flutter test`: 46/46 pass, including new PIN hashing/lockout tests with the RFC 7914 PBKDF2 vector. |

## Remaining notes

- **Release signing**: Gradle reads `android/key.properties`. Until you create a keystore, release APKs are signed with the debug key and Gradle warns about it. Do not distribute those builds.
- **google_fonts** downloads Inter / Inter Tight from Google's servers at runtime, which sends your IP address to Google. To stop that, bundle the font files and set `GoogleFonts.config.allowRuntimeFetching = false`.
- A 4–8 digit PIN is a self-control lock, not strong encryption. Someone with root access and the prefs file can still brute-force it offline. It is just much slower now.
- `tool/render_icon_test.dart` now copies the launcher/splash PNGs from `branding/`. It no longer paints the old cup mark.
