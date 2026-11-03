import 'package:supabase_flutter/supabase_flutter.dart';

const emailConfirmationRedirect =
    'com.automotors.automotorsbase://auth/verify-email';

bool isEmailConfirmationUri(Uri uri) =>
    uri.scheme == 'com.automotors.automotorsbase' &&
    uri.host == 'auth' &&
    uri.path == '/verify-email' &&
    uri.userInfo.isEmpty &&
    !uri.hasPort;

/// Own confirmation callbacks use an isolated PKCE exchange, not the active session.
/// Preserve the SDK's normal detection for other auth flows.
bool automaticallyHandleAuthUri(Uri uri) {
  if (isEmailConfirmationUri(uri)) return false;
  try {
    final params = {
      ...uri.queryParameters,
      ...Uri.splitQueryString(uri.fragment),
    };
    return [
      'access_token',
      'code',
      'error',
      'error_code',
      'error_description',
    ].any(params.containsKey);
  } on FormatException {
    return false;
  }
}

class EmailConfirmationResult {
  final bool verified;
  final String? email;
  const EmailConfirmationResult({required this.verified, this.email});
  String get message => verified
      ? 'Cuenta verificada. Ya puedes iniciar sesión.'
      : 'No se pudo validar este enlace. Si ya confirmaste el correo, inicia sesión. Si ha caducado, solicita uno nuevo desde este iPhone.';
}

class EmailConfirmationHandler {
  final Future<String?> Function(String code) verify;
  final Set<String> _handled = {};
  EmailConfirmationHandler({required this.verify});

  Future<EmailConfirmationResult?> handle(Uri uri) async {
    if (!isEmailConfirmationUri(uri)) return null;
    final key = uri.toString();
    if (!_handled.add(key)) return null;
    if (_handled.length > 32) _handled.remove(_handled.first);
    // Never log URLs or authentication codes.
    try {
      final query = uri.queryParameters;
      if (query.containsKey('error') ||
          query.containsKey('error_code') ||
          uri.fragment.isNotEmpty) {
        return const EmailConfirmationResult(verified: false);
      }
      final code = query['code'];
      if (code == null ||
          code.isEmpty ||
          uri.queryParametersAll['code']!.length != 1) {
        return const EmailConfirmationResult(verified: false);
      }
      final email = await verify(code);
      return EmailConfirmationResult(
        verified: email != null && email.isNotEmpty,
        email: email,
      );
    } catch (_) {
      return const EmailConfirmationResult(verified: false);
    }
  }
}

/// The one-use PKCE code is bound to the verifier stored during signup/resend.
/// This temporary client never persists a session or changes the signed-in account.
Future<String?> exchangeEmailConfirmation(
  String code,
  SupabaseClient Function() createClient,
) async {
  final client = createClient();
  try {
    final response = await client.auth
        .exchangeCodeForSession(code)
        .timeout(const Duration(seconds: 20));
    final user = response.session.user;
    if (user.emailConfirmedAt == null ||
        response.redirectType == 'passwordRecovery')
      return null;
    final email = user.email;
    return email;
  } finally {
    try {
      if (client.auth.currentSession != null)
        await client.auth
            .signOut(scope: SignOutScope.local)
            .timeout(const Duration(seconds: 5));
    } catch (_) {
      /* No session is persisted if temporary revocation is offline. */
    }
    await client.dispose();
  }
}
