import 'package:automotors_base/design/market_professional_header.dart';
import 'package:automotors_base/services/chat_participant_service.dart';

import 'dart:convert';

import 'package:automotors_base/main.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const uid = '11111111-1111-4111-8111-111111111111';
  var type = 'empresa';
  Map<String, dynamic>? conversation;
  final saved = <Map<String, dynamic>>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture';
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        dynamic body = [];
        if (r.url.path == '/rest/v1/chat_conversations')
          body = conversation == null ? [] : [conversation];
        if (r.url.path == '/auth/v1/token')
          body = {
            'access_token': token,
            'refresh_token': 'fixture',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': uid,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'professional@example.test',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          };
        if (r.url.path == '/rest/v1/user_profiles') {
          if (r.method == 'POST') {
            saved.add(Map<String, dynamic>.from(jsonDecode(r.body)));
          } else {
            body = [
              {
                'id': uid,
                'full_name': 'Seller',
                'account_type': type,
                'estado_verificacion': 'No solicitada',
                'fiscal_id': 'B12345678',
                'phone': '+34612345678',
                'city': 'Mataro',
                'province': 'Barcelona',
                'business_name': 'Business',
                'address': 'Example 1',
                'cover_photo_path': null,
              },
            ];
          }
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    await Supabase.instance.client.auth.setSession('fixture');
  });
  tearDownAll(() async => Supabase.instance.dispose());
  test(
    'chat profile resolves the actual other participant and rejects outsiders',
    () async {
      final client = Supabase.instance.client;
      const other = '22222222-2222-4222-8222-222222222222';
      conversation = {'buyer_id': other, 'seller_id': uid};
      expect(await loadChatParticipantId(client, 'fixture-chat'), other);
      conversation = {'buyer_id': uid, 'seller_id': other};
      expect(await loadChatParticipantId(client, 'fixture-chat'), other);
      conversation = {'buyer_id': other, 'seller_id': 'outsider'};
      await expectLater(
        loadChatParticipantId(client, 'fixture-chat'),
        throwsFormatException,
      );
      conversation = {'buyer_id': uid, 'seller_id': null};
      await expectLater(
        loadChatParticipantId(client, 'fixture-chat'),
        throwsFormatException,
      );
      conversation = null;
      await expectLater(
        loadChatParticipantId(client, 'fixture-chat'),
        throwsFormatException,
      );
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'professional avatar is centered across the cover edge at text scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: MarketProfessionalHeader(
                    name: 'Business legal name with several words',
                    accountLabel: 'Autónomo',
                  ),
                ),
              ),
            ),
          ),
        );
        final cover = tester.getRect(
          find.byKey(const Key('professional-cover')),
        );
        final avatar = tester.getRect(
          find.byKey(const Key('professional-avatar')),
        );
        expect(avatar.center.dx, cover.center.dx);
        expect(avatar.center.dy, cover.bottom);
        expect(
          tester
              .getTopLeft(find.byKey(const Key('professional-display-name')))
              .dy,
          greaterThanOrEqualTo(avatar.bottom),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final account in ['empresa', 'autonomo', 'particular']) {
    testWidgets('$account cover eligibility and document-free profile save', (
      tester,
    ) async {
      type = account;
      saved.clear();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ProfilePage(key: ValueKey(account)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar perfil'));
      await tester.pumpAndSettle();
      expect(
        find.text('Cambiar foto de portada'),
        account == 'particular' ? findsNothing : findsOneWidget,
      );
      expect(find.text('Adjuntar documentación'), findsNothing);
      expect(find.text('VERIFICACIÓN DE CUENTA'), findsNothing);
      final save = find.text('Guardar perfil');
      await tester.scrollUntilVisible(
        save,
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      expect(
        saved.single['business_name'],
        account == 'particular' ? isNull : 'Business',
      );
      expect(saved.single.containsKey('estado_verificacion'), isFalse);
      expect(saved.single.containsKey('verification_document_path'), isFalse);
      expect(saved.single['cover_photo_path'], isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
