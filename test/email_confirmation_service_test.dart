import 'dart:convert';

import 'package:automotors_base/services/email_confirmation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryVerifier extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  test('only exact native confirmation callbacks are accepted and not auto signed in', () {
    final valid = Uri.parse('$emailConfirmationRedirect?code=once');
    expect(isEmailConfirmationUri(valid), isTrue);
    expect(automaticallyHandleAuthUri(valid), isFalse);
    for (final link in [
      'https://auth/verify-email?code=x',
      'com.automotors.automotorsbase://evil/verify-email?code=x',
      'com.automotors.automotorsbase://auth/elsewhere?code=x',
    ]) {
      expect(isEmailConfirmationUri(Uri.parse(link)), isFalse);
    }
    expect(
      automaticallyHandleAuthUri(
        Uri.parse('https://example.test/oauth?code=x'),
      ),
      isTrue,
    );
    expect(
      automaticallyHandleAuthUri(Uri.parse('https://example.test/advert')),
      isFalse,
    );
  });
  test(
    'success requires server verification; duplicate link opens only once',
    () async {
      var calls = 0;
      final handler = EmailConfirmationHandler(
        verify: (code) async {
          calls++;
          expect(code, 'once');
          return 'verified@example.test';
        },
      );
      final uri = Uri.parse('$emailConfirmationRedirect?code=once');
      final result = await handler.handle(uri);
      expect(result!.verified, isTrue);
      expect(result.email, 'verified@example.test');
      expect(await handler.handle(uri), isNull);
      expect(calls, 1);
    },
  );
  test(
    'fake success, implicit tokens, errors and malformed codes never verify',
    () async {
      var calls = 0;
      final handler = EmailConfirmationHandler(
        verify: (_) async {
          calls++;
          return 'x@example.test';
        },
      );
      for (final suffix in [
        '?verified=true',
        '#access_token=pretend',
        '?error=expired&code=ignored',
        '?code=a&code=b',
      ]) {
        expect(
          (await handler.handle(
            Uri.parse('$emailConfirmationRedirect$suffix'),
          ))!.verified,
          isFalse,
        );
      }
      expect(calls, 0);
    },
  );
  test(
    'expired server code produces recoverable error without leaking details',
    () async {
      final handler = EmailConfirmationHandler(
        verify: (_) async => throw const AuthException('private detail'),
      );
      final result = await handler.handle(
        Uri.parse('$emailConfirmationRedirect?code=expired'),
      );
      expect(result!.verified, isFalse);
      expect(result.email, isNull);
      expect(result.message, isNot(contains('private detail')));
    },
  );
  for (final confirmed in [true, false]) {
    test(
      'isolated PKCE exchange validates confirmed=$confirmed without signing in main client',
      () async {
        final storage = MemoryVerifier();
        await storage.setItem(
          key: 'supabase.auth.token-code-verifier',
          value: 'fixture-verifier',
        );
        final requests = <http.Request>[];
        final payload = base64Url
            .encode(
              utf8.encode(
                jsonEncode({
                  'sub': '11111111-1111-4111-8111-111111111111',
                  'exp': 2100000000,
                }),
              ),
            )
            .replaceAll('=', '');
        final mock = MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/token'))
            return http.Response(
              jsonEncode({
                'access_token': 'e30.$payload.fixture',
                'refresh_token': 'fixture-refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'expires_at': 2100000000,
                'user': {
                  'id': '11111111-1111-4111-8111-111111111111',
                  'email': 'verified@example.test',
                  'aud': 'authenticated',
                  'created_at': '2026-01-01T00:00:00Z',
                  if (confirmed) 'email_confirmed_at': '2026-01-01T00:00:00Z',
                  'app_metadata': {},
                  'user_metadata': {},
                },
              }),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          if (r.url.path.endsWith('/logout'))
            return http.Response('', 204, request: r);
          return http.Response('{}', 400, request: r);
        });
        final main = SupabaseClient(
          'https://example.test',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        await main.auth.setInitialSession(
          jsonEncode({
            'access_token': 'e30.$payload.existing',
            'refresh_token': 'existing-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'expires_at': 2100000000,
            'user': {
              'id': '22222222-2222-4222-8222-222222222222',
              'email': 'existing@example.test',
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          }),
        );
        final result = await exchangeEmailConfirmation(
          'fixture-code',
          () => SupabaseClient(
            'https://example.test',
            'test-key',
            httpClient: mock,
            authOptions: AuthClientOptions(
              autoRefreshToken: false,
              pkceAsyncStorage: storage,
            ),
          ),
        );
        expect(result, confirmed ? 'verified@example.test' : null);
        expect(main.auth.currentUser!.email, 'existing@example.test');
        final token = requests.firstWhere((r) => r.url.path.endsWith('/token'));
        expect(jsonDecode(token.body), {
          'auth_code': 'fixture-code',
          'code_verifier': 'fixture-verifier',
        });
        expect(token.url.queryParameters['grant_type'], 'pkce');
        await main.dispose();
      },
    );
  }
}
