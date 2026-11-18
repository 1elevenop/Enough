import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feature_toggle.dart';
import '../models/site_config.dart';
import 'pin_hash.dart';

enum FocusMode { lock, messagesOnly }

const defaultBlocklist = <String>[
  'nsfw', 'onlyfans', 'nude', 'nudes', 'porn', 'xxx', '18+', 'sexy',
  'thirst trap', 'lewd', 'hentai', 'leaked',
];

/// Every user preference, persisted with shared_preferences.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._p);

  static late SettingsStore instance;

  static Future<SettingsStore> load() async {
    instance = SettingsStore._(await SharedPreferences.getInstance());
    return instance;
  }

  final SharedPreferences _p;

  void _changed() => notifyListeners();

  // ---- home screen -----------------------------------------------------
  /// Site ids the user added to the home screen, in order. Starts empty.
  List<String> get homeSites => _p.getStringList('home.sites') ?? const [];

  Future<void> addHomeSite(String id) async {
    if (homeSites.contains(id)) return;
    await _p.setStringList('home.sites', [...homeSites, id]);
    _changed();
  }

  Future<void> removeHomeSite(String id) async {
    await _p.setStringList('home.sites', homeSites.where((s) => s != id).toList());
    _changed();
  }

  Future<void> moveHomeSite(int from, int to) async {
    final list = [...homeSites];
    if (from < 0 || from >= list.length) return;
    final id = list.removeAt(from);
    list.insert(to.clamp(0, list.length), id);
    await _p.setStringList('home.sites', list);
    _changed();
  }

  // ---- feature toggles -------------------------------------------------
  bool isEnabled(SiteConfig site, FeatureToggle t) =>
      _p.getBool('toggle.${site.id}.${t.id}') ?? t.defaultOn;

  Future<void> setEnabled(SiteConfig site, FeatureToggle t, bool v) async {
    await _p.setBool('toggle.${site.id}.${t.id}', v);
    _changed();
  }

  Set<String> enabledIds(SiteConfig site) => {
        for (final t in site.allToggles)
          if (isEnabled(site, t)) t.id,
      };

  // ---- limits ----------------------------------------------------------
  /// Daily limit in minutes; 0 means no limit.
  int dailyLimit(String siteId) => _p.getInt('limit.$siteId') ?? 30;

  Future<void> setDailyLimit(String siteId, int minutes) async {
    await _p.setInt('limit.$siteId', minutes);
    _changed();
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool snoozeUsed(String siteId, DateTime now) =>
      _p.getBool('snooze.$siteId.${_day(now)}') ?? false;

  Future<void> useSnooze(String siteId, DateTime now) async {
    await _p.setBool('snooze.$siteId.${_day(now)}', true);
    _changed();
  }

  /// How often an external-app site was opened today.
  int opensToday(String siteId, DateTime now) =>
      _p.getInt('opens.$siteId.${_day(now)}') ?? 0;

  Future<void> recordOpen(String siteId, DateTime now) async {
    await _p.setInt('opens.$siteId.${_day(now)}', opensToday(siteId, now) + 1);
    _changed();
  }

  // ---- friction --------------------------------------------------------
  bool get intentPrompt => _p.getBool('intentPrompt') ?? true;
  Future<void> setIntentPrompt(bool v) async {
    await _p.setBool('intentPrompt', v);
    _changed();
  }

  int get breathingSeconds => _p.getInt('breathingSeconds') ?? 10;
  Future<void> setBreathingSeconds(int v) async {
    await _p.setInt('breathingSeconds', v);
    _changed();
  }

  int get feedCapCount => _p.getInt('feedCap') ?? 20;
  Future<void> setFeedCapCount(int v) async {
    await _p.setInt('feedCap', v);
    _changed();
  }

  // ---- content filter --------------------------------------------------
  List<String> get blocklist =>
      _p.getStringList('blocklist') ?? List.of(defaultBlocklist);

  Future<void> setBlocklist(List<String> words) async {
    final clean = {
      for (final w in words)
        if (w.trim().isNotEmpty) w.trim().toLowerCase(),
    }.toList();
    await _p.setStringList('blocklist', clean);
    _changed();
  }

  // ---- focus hours -----------------------------------------------------
  bool get focusEnabled => _p.getBool('focus.enabled') ?? false;
  int get focusStart => _p.getInt('focus.start') ?? 9 * 60; // minutes
  int get focusEnd => _p.getInt('focus.end') ?? 17 * 60;
  Set<int> get focusDays =>
      (_p.getStringList('focus.days') ?? ['1', '2', '3', '4', '5'])
          .map(int.parse)
          .toSet();
  Set<String> get focusSites =>
      (_p.getStringList('focus.sites') ?? ['youtube', 'instagram', 'facebook', 'x'])
          .toSet();
  FocusMode get focusMode =>
      FocusMode.values[_p.getInt('focus.mode') ?? FocusMode.messagesOnly.index];

  Future<void> setFocus({
    bool? enabled,
    int? start,
    int? end,
    Set<int>? days,
    Set<String>? siteIds,
    FocusMode? mode,
  }) async {
    if (enabled != null) await _p.setBool('focus.enabled', enabled);
    if (start != null) await _p.setInt('focus.start', start);
    if (end != null) await _p.setInt('focus.end', end);
    if (days != null) {
      await _p.setStringList('focus.days', days.map((d) => '$d').toList());
    }
    if (siteIds != null) await _p.setStringList('focus.sites', siteIds.toList());
    if (mode != null) await _p.setInt('focus.mode', mode.index);
    _changed();
  }

  // ---- lock ------------------------------------------------------------
  bool get hasPin => _p.getString('pinHash') != null;

  /// When wrong-PIN lockout ends, or null if not locked.
  DateTime? get pinLockedUntil {
    final t = _time('pin.lockedUntil');
    return t != null && t.isAfter(DateTime.now()) ? t : null;
  }

  /// Checks [pin], counting failures toward [PinLockout]. Always false while
  /// locked out. Upgrades a legacy hash to PBKDF2 on success.
  Future<bool> checkPin(String pin) async {
    final stored = _p.getString('pinHash');
    if (stored == null || pinLockedUntil != null) return false;
    final ok = await compute(_verify, [pin, stored]);
    if (ok) {
      await _p.remove('pin.failures');
      await _p.remove('pin.lockedUntil');
      if (PinHash.isLegacy(stored)) await _p.setString('pinHash', await _create(pin));
    } else {
      final n = (_p.getInt('pin.failures') ?? 0) + 1;
      await _p.setInt('pin.failures', n);
      final wait = PinLockout.after(n);
      if (wait > Duration.zero) await _setTime('pin.lockedUntil', DateTime.now().add(wait));
    }
    return ok;
  }

  static bool _verify(List<String> a) => PinHash.verifyPin(a[0], a[1]);
  static Future<String> _create(String pin) => compute(PinHash.create, pin);

  Future<void> setPin(String? pin) async {
    if (pin == null) {
      await _p.remove('pinHash');
    } else {
      await _p.setString('pinHash', await _create(pin));
    }
    await _p.remove('pin.failures');
    await _p.remove('pin.lockedUntil');
    _changed();
  }

  bool get biometricUnlock => _p.getBool('biometric') ?? true;
  Future<void> setBiometricUnlock(bool v) async {
    await _p.setBool('biometric', v);
    _changed();
  }

  // ---- reminders -------------------------------------------------------
  bool get weeklyReport => _p.getBool('weeklyReport') ?? true;
  Future<void> setWeeklyReport(bool v) async {
    await _p.setBool('weeklyReport', v);
    _changed();
  }

  // ---- camera / microphone ---------------------------------------------
  MediaDecision mediaDecision(String siteId) =>
      MediaDecision.values.asNameMap()[_p.getString('media.$siteId')] ?? MediaDecision.ask;

  Future<void> setMediaDecision(String siteId, MediaDecision d) async {
    await _p.setString('media.$siteId', d.name);
    _changed();
  }

  // ---- reels pass ------------------------------------------------------
  DateTime? _time(String k) {
    final ms = _p.getInt(k);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _setTime(String k, DateTime? t) =>
      t == null ? _p.remove(k) : _p.setInt(k, t.millisecondsSinceEpoch);

  DateTime? get reelsPassUntil => _time('reels.passUntil');
  DateTime? get reelsCooldownUntil => _time('reels.cooldownUntil');

  Future<void> setReelsWindow({DateTime? passUntil, DateTime? cooldownUntil}) async {
    await _setTime('reels.passUntil', passUntil);
    await _setTime('reels.cooldownUntil', cooldownUntil);
    _changed();
  }

  int get reelsPassMinutes => _p.getInt('reels.passMinutes') ?? 10;
  int get reelsCooldownHours => _p.getInt('reels.cooldownHours') ?? 3;

  Future<void> setReelsDurations({int? passMinutes, int? cooldownHours}) async {
    if (passMinutes != null) await _p.setInt('reels.passMinutes', passMinutes);
    if (cooldownHours != null) await _p.setInt('reels.cooldownHours', cooldownHours);
    _changed();
  }

  // ---- privacy ---------------------------------------------------------
  bool get blockTrackers => _p.getBool('privacy.trackers') ?? true;
  bool get thirdPartyCookies => _p.getBool('privacy.thirdPartyCookies') ?? true;
  bool get screenPrivacy => _p.getBool('privacy.screen') ?? false;

  Future<void> setPrivacy({bool? trackers, bool? thirdPartyCookies, bool? screen}) async {
    if (trackers != null) await _p.setBool('privacy.trackers', trackers);
    if (thirdPartyCookies != null) {
      await _p.setBool('privacy.thirdPartyCookies', thirdPartyCookies);
    }
    if (screen != null) await _p.setBool('privacy.screen', screen);
    _changed();
  }

  bool forgetOnClose(String siteId) => _p.getBool('privacy.forget.$siteId') ?? false;
  Future<void> setForgetOnClose(String siteId, bool v) async {
    await _p.setBool('privacy.forget.$siteId', v);
    _changed();
  }

  int trackersBlocked(DateTime now) => _p.getInt('trackers.${_day(now)}') ?? 0;

  /// Batched by the caller; no listener notification to avoid rebuild storms.
  Future<void> addTrackersBlocked(DateTime now, int n) =>
      _p.setInt('trackers.${_day(now)}', trackersBlocked(now) + n);

  // ---- first run -------------------------------------------------------
  bool get onboarded => _p.getBool('onboarded') ?? false;
  Future<void> setOnboarded() async {
    await _p.setBool('onboarded', true);
    _changed();
  }
}

enum MediaDecision { ask, allow, deny }
