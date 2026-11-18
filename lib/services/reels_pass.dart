import 'settings_store.dart';

sealed class PassStatus {
  const PassStatus();
}

class PassLocked extends PassStatus {
  const PassLocked();
}

class PassActive extends PassStatus {
  const PassActive(this.remaining);
  final Duration remaining;
}

class PassCooling extends PassStatus {
  const PassCooling(this.remaining);
  final Duration remaining;
}

/// A Reels pass: a short window of Reels/Shorts, then a cooldown.
/// Pure value; [ReelsPassStore] persists it.
class ReelsPass {
  const ReelsPass({
    this.passUntil,
    this.cooldownUntil,
    this.passMinutes = 10,
    this.cooldownHours = 3,
  });

  final DateTime? passUntil;
  final DateTime? cooldownUntil;
  final int passMinutes;
  final int cooldownHours;

  PassStatus status(DateTime now) {
    if (passUntil != null && now.isBefore(passUntil!)) {
      return PassActive(passUntil!.difference(now));
    }
    if (cooldownUntil != null && now.isBefore(cooldownUntil!)) {
      return PassCooling(cooldownUntil!.difference(now));
    }
    return const PassLocked();
  }

  bool isActive(DateTime now) => status(now) is PassActive;

  /// Starts a pass. Returns null unless the pass is locked.
  ReelsPass? start(DateTime now) {
    if (status(now) is! PassLocked) return null;
    final until = now.add(Duration(minutes: passMinutes));
    return _with(until, until.add(Duration(hours: cooldownHours)));
  }

  /// Ends a running pass now; the cooldown starts from now.
  ReelsPass end(DateTime now) {
    if (status(now) is! PassActive) return this;
    return _with(null, now.add(Duration(hours: cooldownHours)));
  }

  ReelsPass _with(DateTime? pass, DateTime? cool) => ReelsPass(
        passUntil: pass,
        cooldownUntil: cool,
        passMinutes: passMinutes,
        cooldownHours: cooldownHours,
      );
}

/// Reads and writes the pass through [SettingsStore].
extension ReelsPassStore on SettingsStore {
  ReelsPass get reelsPass => ReelsPass(
        passUntil: reelsPassUntil,
        cooldownUntil: reelsCooldownUntil,
        passMinutes: reelsPassMinutes,
        cooldownHours: reelsCooldownHours,
      );

  Future<bool> startReelsPass(DateTime now) async {
    final next = reelsPass.start(now);
    if (next == null) return false;
    await setReelsWindow(passUntil: next.passUntil, cooldownUntil: next.cooldownUntil);
    return true;
  }

  Future<void> endReelsPass(DateTime now) async {
    final next = reelsPass.end(now);
    await setReelsWindow(passUntil: next.passUntil, cooldownUntil: next.cooldownUntil);
  }
}

/// "2h 41m", "8m", "45s".
String formatShort(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m';
  return '${d.inSeconds}s';
}
