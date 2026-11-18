import 'package:brainrot_wrapper/services/reels_pass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 11, 18, 12);

  test('locked, then active, then cooling, then locked again', () {
    const pass = ReelsPass(passMinutes: 10, cooldownHours: 3);
    expect(pass.status(t0), isA<PassLocked>());

    final started = pass.start(t0)!;
    final active = started.status(t0.add(const Duration(minutes: 4)));
    expect((active as PassActive).remaining, const Duration(minutes: 6));

    final cooling = started.status(t0.add(const Duration(minutes: 11)));
    expect(cooling, isA<PassCooling>());
    expect((cooling as PassCooling).remaining, const Duration(hours: 2, minutes: 59));

    expect(started.status(t0.add(const Duration(hours: 3, minutes: 10))), isA<PassLocked>());
  });

  test('cannot start during a pass or a cooldown', () {
    final started = const ReelsPass().start(t0)!;
    expect(started.start(t0.add(const Duration(minutes: 1))), isNull);
    expect(started.start(t0.add(const Duration(hours: 1))), isNull);
    expect(started.start(t0.add(const Duration(hours: 4))), isNotNull);
  });

  test('ending early starts the cooldown now', () {
    final started = const ReelsPass(cooldownHours: 2).start(t0)!;
    final ended = started.end(t0.add(const Duration(minutes: 3)));
    final s = ended.status(t0.add(const Duration(minutes: 4)));
    expect((s as PassCooling).remaining, const Duration(hours: 1, minutes: 59));
  });

  test('formatShort', () {
    expect(formatShort(const Duration(hours: 2, minutes: 41)), '2h 41m');
    expect(formatShort(const Duration(minutes: 8, seconds: 3)), '8m');
    expect(formatShort(const Duration(seconds: 45)), '45s');
  });
}
