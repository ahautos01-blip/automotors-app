import 'dart:convert';
import 'package:automotors_base/chat_market_page.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const user = '11111111-1111-4111-8111-111111111111';
  bool buyer = true;
  final writes = <Map<String, dynamic>>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final token = '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': user, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture';
    await Supabase.initialize(url: 'https://example.supabase.co', publishableKey: 'test-key',
      debug: false, authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        dynamic data = [];
        if (r.url.path == '/auth/v1/token') {
          data = {'access_token': token, 'refresh_token': 'fixture', 'token_type': 'bearer', 'expires_in': 3600,
            'user': {'id': user, 'aud': 'authenticated', 'role': 'authenticated',
              'app_metadata': {}, 'user_metadata': {}, 'created_at': '2026-01-01T00:00:00Z'}};
        } else if (r.url.path.endsWith('/chat_conversations')) {
          data = {'buyer_id': buyer ? user : 'other'};
        } else if (r.url.path.endsWith('/rpc/chat_market_action')) {
          final body = Map<String, dynamic>.from(jsonDecode(r.body));
          if (body['p_action'] != 'list') { writes.add(body); data = {'status': 'pending'}; }
        }
        return http.Response(jsonEncode(data), 200, request: r, headers: {'content-type':'application/json'});
      }));
    await Supabase.instance.client.auth.setSession('fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() { buyer = true; writes.clear(); });
  Widget page() => const MaterialApp(locale: Locale('es'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: ChatMarketPage(conversationId: 'conversation', openOffer: true));

  testWidgets('buyer opens the amount directly and sends only after confirmation', (tester) async {
    await tester.pumpWidget(page()); await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    expect(find.byType(MarketProposalDialog), findsOneWidget);
    expect(writes, isEmpty);
    await tester.enterText(find.byType(TextFormField), '12000');
    await tester.tap(find.text('Enviar propuesta')); await tester.pumpAndSettle();
    expect(writes.single['p_kind'], 'offer'); expect(writes.single['p_amount'], 12000);
    expect(find.byType(MarketProposalDialog), findsNothing);
    await tester.pump(const Duration(seconds: 31)); await tester.pumpAndSettle();
    expect(find.byType(MarketProposalDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('seller cannot open a buyer offer form', (tester) async {
    buyer = false;
    await tester.pumpWidget(page()); await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    expect(find.byType(MarketProposalDialog), findsNothing);
    expect(find.text('Hacer una oferta'), findsNothing);
    expect(writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
