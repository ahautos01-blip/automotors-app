import 'dart:convert';

import 'package:automotors_base/services/password_recovery_service.dart';
import 'package:automotors_base/password_recovery_page.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/l10n/ui_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final user = <String, dynamic>{
  'id': '11111111-1111-4111-8111-111111111111',
  'email': 'person@example.test',
  'aud': 'authenticated',
  'created_at': '2026-01-01T00:00:00Z',
  'app_metadata': {},
  'user_metadata': {},
};
Map<String, dynamic> session() {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': user['id'], 'exp': 2100000000})))
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.fixture',
    'refresh_token': 'fixture-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': 2100000000,
    'user': user,
  };
}

GoTrueClient client(MockClient mock) => GoTrueClient(
  url: 'https://example.test/auth/v1',
  headers: {'apikey': 'test-key'},
  httpClient: mock,
  autoRefreshToken: false,
  flowType: AuthFlowType.pkce,
  asyncStorage: RecoveryMemoryStorage(),
);
http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('recovery requires verified recovery OTP, preserves password and isolates main session', () async {
    final requests = <http.Request>[];
    final c = client(
      MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/recover')) return jsonResponse({});
        if (r.url.path.endsWith('/verify')) return jsonResponse(session());
        if (r.url.path.endsWith('/user')) return jsonResponse(user);
        return http.Response('', 204);
      }),
    );
    final main = client(MockClient((_) async => jsonResponse({}, 400)));
    await main.setInitialSession(jsonEncode(session()));
    final original = main.currentSession!.accessToken;
    final service = PasswordRecoveryService(c);
    await expectLater(
      service.updatePassword('new-fixture-password'),
      throwsStateError,
    );
    await service.request(' person@example.test ');
    expect(jsonDecode(requests.first.body)['email'], 'person@example.test');
    expect(jsonDecode(requests.first.body)['code_challenge_method'], 's256');
    await expectLater(
      service.request('person@example.test'),
      throwsA(isA<AuthException>()),
    );
    await service.verify('123456');
    final verify = jsonDecode(requests.last.body);
    expect(verify['type'], 'recovery');
    expect(verify['token'], '123456');
    await expectLater(service.updatePassword('short'), throwsArgumentError);
    await service.updatePassword(' new-fixture-password ');
    final update = requests.firstWhere((r) => r.method == 'PUT');
    expect(jsonDecode(update.body)['password'], ' new-fixture-password ');
    expect(main.currentSession!.accessToken, original);
    await service.close();
    await expectLater(
      service.updatePassword('another-password'),
      throwsStateError,
    );
    main.dispose();
  });
  test('invalid or expired OTP cannot update a password', () async {
    var updates = 0;
    final service = PasswordRecoveryService(
      client(
        MockClient((r) async {
          if (r.method == 'PUT') updates++;
          if (r.url.path.endsWith('/recover')) return jsonResponse({});
          return jsonResponse({
            'msg': 'Expired token',
            'code': 'otp_expired',
          }, 403);
        }),
      ),
    );
    await service.request('person@example.test');
    await expectLater(service.verify('654321'), throwsA(isA<AuthException>()));
    await expectLater(
      service.updatePassword('new-fixture-password'),
      throwsStateError,
    );
    expect(updates, 0);
    await service.close();
  });
  test('a recovery response for a different email is rejected', () async {
    final wrong = session();
    wrong['user'] = {...user, 'email': 'other@example.test'};
    final service = PasswordRecoveryService(
      client(
        MockClient((r) async {
          if (r.url.path.endsWith('/recover')) return jsonResponse({});
          if (r.url.path.endsWith('/verify')) return jsonResponse(wrong);
          return http.Response('', 204);
        }),
      ),
    );
    await service.request('person@example.test');
    await expectLater(service.verify('123456'), throwsA(isA<AuthException>()));
    await expectLater(
      service.updatePassword('new-fixture-password'),
      throwsStateError,
    );
    await service.close();
  });
  test('password update can retry without consuming the OTP twice', () async {
    var updates = 0, verifications = 0;
    final service = PasswordRecoveryService(
      client(
        MockClient((r) async {
          if (r.url.path.endsWith('/recover')) return jsonResponse({});
          if (r.url.path.endsWith('/verify')) {
            verifications++;
            return jsonResponse(session());
          }
          if (r.method == 'PUT') {
            updates++;
            return updates == 1
                ? jsonResponse({'msg': 'Try again'}, 503)
                : jsonResponse(user);
          }
          return http.Response('', 204);
        }),
      ),
    );
    await service.request('person@example.test');
    await service.verify('123456');
    await expectLater(
      service.updatePassword('new-fixture-password'),
      throwsA(isA<AuthException>()),
    );
    await service.updatePassword('new-fixture-password');
    expect(verifications, 1);
    expect(updates, 2);
  });
  testWidgets(
    'complete recovery checks matching passwords and returns to login',
    (t) async {
      var updates = 0;
      final recovery = PasswordRecoveryService(
        client(
          MockClient((r) async {
            if (r.url.path.endsWith('/recover')) return jsonResponse({});
            if (r.url.path.endsWith('/verify')) return jsonResponse(session());
            if (r.method == 'PUT') {
              updates++;
              return jsonResponse(user);
            }
            return http.Response('', 204);
          }),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PasswordRecoveryPage(
                        initialEmail: 'person@example.test',
                        createService: () => recovery,
                      ),
                    ),
                  );
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result ?? 'cancelled')),
                    );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Enviar código'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField), '123456');
      await t.tap(find.text('Comprobar código'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byType(TextFormField).at(0),
        'new-fixture-password',
      );
      await t.enterText(find.byType(TextFormField).at(1), 'different-password');
      await t.tap(find.text('Guardar nueva contraseña'));
      await t.pumpAndSettle();
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(updates, 0);
      await t.enterText(
        find.byType(TextFormField).at(1),
        'new-fixture-password',
      );
      await t.runAsync(() async {
        await t.tap(find.text('Guardar nueva contraseña'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pumpAndSettle();
      expect(updates, 1);
      expect(find.text('person@example.test'), findsOneWidget);
      expect(find.byType(PasswordRecoveryPage), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'recovery email form validates and renders on a narrow screen in $language',
      (t) async {
        await t.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: PasswordRecoveryPage(
              createService: () =>
                  throw StateError('Must validate before requesting'),
            ),
          ),
        );
        await t.tap(find.text(translateUiMessage('Enviar código', language)));
        await t.pumpAndSettle();
        expect(
          find.text(translateUiMessage('Introduce un correo válido', language)),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
