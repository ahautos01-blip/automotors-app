import 'dart:convert';

import 'package:automotors_base/chat_offer_panel.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const user = '11111111-1111-4111-8111-111111111111';
  bool incoming = true;
  String status = 'pending';
  final writes = <Map<String, dynamic>>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': user, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture';
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        dynamic data = [];
        if (r.url.path == '/auth/v1/token') {
          data = {
            'access_token': token,
            'refresh_token': 'fixture',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': user,
              'aud': 'authenticated',
              'role': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          };
        } else if (r.url.path.endsWith('/chat_conversations')) {
          data = {'buyer_id': 'other'};
        } else if (r.url.path.endsWith('/rpc/chat_market_action')) {
          final body = Map<String, dynamic>.from(jsonDecode(r.body));
          if (body['p_action'] != 'list') {
            writes.add(body);
            status = body['p_action'] == 'accept' ? 'accepted' : 'rejected';
            data = {'status': status};
          } else {
            data = [
              {
                'id': 'proposal',
                'kind': 'offer',
                'amount': 12000,
                'creator_id': incoming ? 'other' : user,
                'status': status,
              },
            ];
          }
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.setSession('fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    incoming = true;
    status = 'pending';
    writes.clear();
  });
  Widget page({bool enabled = true}) => MaterialApp(
    locale: const Locale('es'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: ChatOfferPanel(conversationId: 'conversation', enabled: enabled),
    ),
  );
  for (final action in ['accept', 'reject']) {
    testWidgets(
      'seller can $action the offer directly in chat after confirmation',
      (tester) async {
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        expect(find.textContaining('12000'), findsOneWidget);
        await tester.tap(
          find.text(action == 'accept' ? 'Aceptar' : 'Rechazar'),
        );
        await tester.pumpAndSettle();
        expect(writes, isEmpty);
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(writes.single['p_action'], action);
        expect(writes.single['p_id'], 'proposal');
        expect(
          find.text(action == 'accept' ? 'Aceptada' : 'Rechazada'),
          findsOneWidget,
        );
        expect(find.text('Aceptar'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('buyer cannot accept their own offer and blocked chats hide it', (
    tester,
  ) async {
    incoming = false;
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.textContaining('12000'), findsOneWidget);
    expect(find.text('Aceptar'), findsNothing);
    await tester.pumpWidget(page(enabled: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('12000'), findsNothing);
    expect(writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
