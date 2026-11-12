import 'package:supabase_flutter/supabase_flutter.dart';

class RecoveryMemoryStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

/// Owns a temporary recovery session; never shares the signed-in app session.
class PasswordRecoveryService {
  final GoTrueClient client;
  String? _email;
  String? _verifiedId;
  bool _closed = false;
  DateTime? _lastRequest;
  PasswordRecoveryService(this.client);

  Future<void> request(String email) async {
    if (_closed) throw StateError('Recovery closed');
    if (_lastRequest != null &&
        DateTime.now().difference(_lastRequest!) <
            const Duration(seconds: 60)) {
      throw const AuthException(
        'Espera un minuto antes de solicitar otro correo.',
      );
    }
    _verifiedId = null;
    await client
        .resetPasswordForEmail(email.trim())
        .timeout(const Duration(seconds: 20));
    if (_closed) return;
    _email = email.trim();
    _lastRequest = DateTime.now();
  }

  Future<void> verify(String code) async {
    if (_closed || _email == null) throw StateError('Request recovery first');
    _verifiedId = null;
    final response = await client
        .verifyOTP(email: _email!, token: code.trim(), type: OtpType.recovery)
        .timeout(const Duration(seconds: 20));
    if (_closed) {
      await close();
      throw StateError('Recovery closed');
    }
    if (response.session == null ||
        response.user == null ||
        response.user!.email?.toLowerCase() != _email!.toLowerCase()) {
      await client.signOut(scope: SignOutScope.local);
      throw const AuthException('Invalid recovery');
    }
    _verifiedId = response.user!.id;
  }

  Future<void> updatePassword(String password) async {
    if (_closed ||
        _verifiedId == null ||
        client.currentUser?.id != _verifiedId) {
      throw StateError('Verify recovery first');
    }
    if (password.length < 8) throw ArgumentError('Password too short');
    final response = await client
        .updateUser(UserAttributes(password: password))
        .timeout(const Duration(seconds: 20));
    if (response.user?.id != _verifiedId) {
      throw StateError('Recovery user changed');
    }
    await close();
  }

  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    _verifiedId = null;
    try {
      await client
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    client.dispose();
  }
}
