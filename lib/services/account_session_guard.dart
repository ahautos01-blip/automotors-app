import 'package:flutter/foundation.dart';

/// Server-confirmed suspension only; network errors never masquerade as a ban.
class AccountSessionGuard {
  AccountSessionGuard({
    required this.sessionKey,
    required this.isSuspended,
    required this.signOut,
    required this.onSuspended,
  });
  final String? Function() sessionKey;
  final Future<bool> Function() isSuspended;
  final Future<void> Function() signOut;
  final VoidCallback onSuspended;
  int _generation = 0;
  bool _disposed = false;
  Future<void> check() async {
    if (_disposed) return;
    final key = sessionKey();
    final generation = ++_generation;
    if (key == null) return;
    try {
      final suspended = await isSuspended();
      if (_disposed ||
          generation != _generation ||
          key != sessionKey() ||
          !suspended) {
        return;
      }
      try {
        await signOut();
      } catch (_) {
        // Clear the old views even if revoking the refresh token is offline.
      }
      final current = sessionKey();
      if (!_disposed &&
          generation == _generation &&
          (current == null || current == key)) {
        onSuspended();
      }
    } catch (_) {
      /* Existing server policies still enforce suspension offline. */
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
  }
}
