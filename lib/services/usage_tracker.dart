import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/site_config.dart';
import 'usage_stats.dart';

/// Records foreground time per site and page category in SQLite.
/// A segment stays open while the user is active on one site + category,
/// and closes on category change, app pause, leaving the site, or 60s idle.
class UsageTracker extends ChangeNotifier {
  UsageTracker._(this._db);

  static late UsageTracker instance;
  static const idleAfter = Duration(seconds: 60);

  static Future<UsageTracker> load() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'usage.db'),
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE sessions(id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'site TEXT NOT NULL, category TEXT NOT NULL, '
        'start_ms INTEGER NOT NULL, end_ms INTEGER NOT NULL)',
      ),
    );
    instance = UsageTracker._(db);
    await instance._loadToday();
    instance._idleTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => instance._checkIdle());
    return instance;
  }

  final Database _db;
  Timer? _idleTimer;

  String? _site;
  RouteCategory _category = RouteCategory.feed;
  DateTime? _segStart; // null = not counting
  DateTime _lastActivity = DateTime.now();
  bool _paused = false;

  DateTime _todayKey = dayStart(DateTime.now());
  final List<UsageSession> _today = [];

  String? get activeSite => _site;

  Future<void> _loadToday() async {
    _todayKey = dayStart(DateTime.now());
    _today
      ..clear()
      ..addAll(await sessionsBetween(_todayKey, _todayKey.add(const Duration(days: 1))));
  }

  /// Committed sessions overlapping [from, to).
  Future<List<UsageSession>> sessionsBetween(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'sessions',
      where: 'end_ms > ? AND start_ms < ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'start_ms',
    );
    return rows
        .map((r) => UsageSession(
              r['site']! as String,
              RouteCategory.values.firstWhere(
                (c) => c.name == r['category'],
                orElse: () => RouteCategory.feed,
              ),
              DateTime.fromMillisecondsSinceEpoch(r['start_ms']! as int),
              DateTime.fromMillisecondsSinceEpoch(r['end_ms']! as int),
            ))
        .toList();
  }

  /// Committed sessions plus the open segment, for live views.
  List<UsageSession> liveSessions(List<UsageSession> committed) => [
        ...committed,
        ?_open,
      ];

  UsageSession? get _open {
    final s = _segStart;
    if (s == null || _site == null) return null;
    return UsageSession(_site!, _category, s, DateTime.now());
  }

  Duration usedToday(String siteId) {
    final now = DateTime.now();
    if (dayStart(now) != _todayKey) {
      // Day rolled over: today's list is stale. Reload in the background.
      _loadToday().then((_) => notifyListeners());
      return _open?.site == siteId ? overlapWithDay(_open!, now) : Duration.zero;
    }
    return totalsBySite(liveSessions(_today), now)[siteId] ?? Duration.zero;
  }

  Map<String, Duration> todayBySite() =>
      totalsBySite(liveSessions(_today), DateTime.now());

  // ---- events from the WebView screen ---------------------------------
  void enterSite(String siteId, RouteCategory category) {
    _close();
    _site = siteId;
    _category = category;
    _lastActivity = DateTime.now();
    if (!_paused) _segStart = DateTime.now();
  }

  void setCategory(RouteCategory c) {
    if (c == _category) return;
    _close();
    _category = c;
    if (_site != null && !_paused) _segStart = DateTime.now();
  }

  void activity() {
    _lastActivity = DateTime.now();
    if (_site != null && !_paused && _segStart == null) {
      _segStart = DateTime.now();
    }
  }

  void leaveSite() {
    _close();
    _site = null;
  }

  void pause() {
    _paused = true;
    _close();
  }

  void resume() {
    _paused = false;
    activity();
  }

  void _checkIdle() {
    if (_segStart == null) return;
    final now = DateTime.now();
    if (now.difference(_lastActivity) > idleAfter) {
      // Count up to the point the user went idle, plus a short grace period.
      _close(at: _lastActivity.add(const Duration(seconds: 15)));
    } else {
      notifyListeners(); // keeps live counters ticking
    }
  }

  void _close({DateTime? at}) {
    final start = _segStart;
    final site = _site;
    _segStart = null;
    if (start == null || site == null) return;
    var end = at ?? DateTime.now();
    if (end.isAfter(DateTime.now())) end = DateTime.now();
    if (end.difference(start) < const Duration(seconds: 1)) return;
    final s = UsageSession(site, _category, start, end);
    if (overlapWithDay(s, _todayKey) > Duration.zero) _today.add(s);
    _db.insert('sessions', {
      'site': site,
      'category': _category.name,
      'start_ms': start.millisecondsSinceEpoch,
      'end_ms': end.millisecondsSinceEpoch,
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}
