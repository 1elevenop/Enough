import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/settings_store.dart';

/// Asks for the PIN (or biometrics) before protected settings open.
/// Returns true straight away when no PIN is set.
Future<bool> requireUnlock(BuildContext context) async {
  final s = SettingsStore.instance;
  if (!s.hasPin) return true;

  if (s.biometricUnlock) {
    try {
      final auth = LocalAuthentication();
      if (await auth.isDeviceSupported() &&
          await auth.authenticate(
            localizedReason: 'Unlock focus settings',
            biometricOnly: true,
          )) {
        return true;
      }
    } catch (_) {
      // Fall through to the PIN.
    }
  }
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (_) => const _PinDialog(),
      ) ??
      false;
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _c = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _error = _lockMessage();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String? _lockMessage() {
    final until = SettingsStore.instance.pinLockedUntil;
    if (until == null) return null;
    final s = until.difference(DateTime.now()).inSeconds + 1;
    return 'Too many tries. Wait ${s >= 60 ? '${(s / 60).ceil()} min' : '$s s'}.';
  }

  Future<void> _submit() async {
    if (_busy) return;
    final locked = _lockMessage();
    if (locked != null) {
      setState(() => _error = locked);
      return;
    }
    setState(() => _busy = true);
    final ok = await SettingsStore.instance.checkPin(_c.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = _lockMessage() ?? 'Wrong PIN';
      });
      _c.clear();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Enter PIN'),
        content: TextField(
          controller: _c,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: InputDecoration(errorText: _error),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Unlock')),
        ],
      );
}

/// Dialog to set a new PIN. Returns the PIN or null.
Future<String?> askNewPin(BuildContext context) async {
  final a = TextEditingController(), b = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Set a PIN'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Needed to change filters, limits and focus hours, '
                'so you can\'t switch them off on impulse.'),
            TextField(
              controller: a,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'PIN (4–8 digits)'),
            ),
            TextField(
              controller: b,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: InputDecoration(labelText: 'Repeat PIN', errorText: error),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!RegExp(r'^\d{4,8}$').hasMatch(a.text)) {
                  setState(() => error = 'Use 4 to 8 digits');
                } else if (a.text != b.text) {
                  setState(() => error = 'PINs don\'t match');
                } else {
                  Navigator.pop(ctx, a.text);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    },
  );
}
