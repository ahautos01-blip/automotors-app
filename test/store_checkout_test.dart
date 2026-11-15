import 'dart:async';
import 'dart:convert';

import 'package:automotors_base/main.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/services/store_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ProductDetails plan() => AppStoreProduct2Details.fromSK2Product(
  SK2Product(
    id: 'automotors_pack_10',
    displayName: 'PACK 10',
    displayPrice: '59,00 €',
    description: 'Fixture',
    price: 59,
    type: SK2ProductType.autoRenewable,
    priceLocale: SK2PriceLocale(currencyCode: 'EUR', currencySymbol: '€'),
    subscription: SK2SubscriptionInfo(
      subscriptionGroupID: 'fixture',
      promotionalOffers: [],
      subscriptionPeriod: SK2SubscriptionPeriod(
        value: 1,
        unit: SK2SubscriptionPeriodUnit.month,
      ),
    ),
  ),
);

class TestStore implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true, failQuery = false, accept = true;
  int queries = 0, buys = 0;
  List<ProductDetails> products = [];
  Completer<bool>? purchaseGate;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queries++;
    if (failQuery) throw StateError('fixture');
    return ProductDetailsResponse(
      productDetails: products,
      notFoundIDs: ids.difference(products.map((p) => p.id).toSet()).toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buys++;
    return purchaseGate?.future ?? Future.value(accept);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const uid = '11111111-1111-4111-8111-111111111111';
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture';
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient(
        (r) async => http.Response(
          jsonEncode(
            r.url.path == '/auth/v1/token'
                ? {
                    'access_token': token,
                    'refresh_token': 'fixture',
                    'token_type': 'bearer',
                    'expires_in': 3600,
                    'user': {
                      'id': uid,
                      'aud': 'authenticated',
                      'role': 'authenticated',
                      'email': 'fixture@example.test',
                      'created_at': '2026-01-01T00:00:00Z',
                      'app_metadata': {},
                      'user_metadata': {},
                    },
                  }
                : r.url.path.endsWith('can_publish_vehicle_listing')
                ? true
                : [],
          ),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'fixture',
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('failed catalogue loads report a message and can be retried', () async {
    final store = TestStore()..failQuery = true;
    final service = StorePurchaseService(store: store);
    final messages = <String>[];
    final sub = service.messages.listen(messages.add);
    await service.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(service.isLoading, false);
    expect(messages.any((v) => v.contains('No se pudo conectar')), true);
    store
      ..failQuery = false
      ..products = [plan()];
    await service.initialize();
    expect(service.products.single.id, 'automotors_pack_10');
    await service.dispose();
    await sub.cancel();
    await store.updates.close();
  });
  test(
    'leaving the page during loading cannot write to closed streams',
    () async {
      final store = TestStore()..products = [plan()];
      final service = StorePurchaseService(store: store);
      final loading = service.initialize();
      await service.dispose();
      await loading;
      await store.updates.close();
    },
  );
  if (StorePurchaseService.checkoutEnabled) {
    test(
      'tap reloads a missing product and starts only one native checkout',
      () async {
        final store = TestStore()
          ..products = [plan()]
          ..purchaseGate = Completer<bool>();
        final service = StorePurchaseService(store: store);
        final first = service.purchaseSubscription('automotors_pack_10');
        while (store.buys == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        await service.purchaseSubscription('automotors_pack_10');
        expect(store.queries, 1);
        expect(store.buys, 1);
        store.purchaseGate!.complete(true);
        await first;
        expect(service.isStartingPurchase, false);
        await service.dispose();
        await store.updates.close();
      },
    );
    test(
      'missing billing metadata and unknown products never start checkout',
      () async {
        final store = TestStore()
          ..products = [
            ProductDetails(
              id: 'automotors_pack_10',
              title: 'Fixture',
              description: 'Fixture',
              price: '59,00 €',
              rawPrice: 59,
              currencyCode: 'EUR',
            ),
          ];
        final service = StorePurchaseService(store: store);
        final messages = <String>[];
        final sub = service.messages.listen(messages.add);
        await service.purchaseSubscription('unknown');
        await service.purchaseSubscription('automotors_pack_10');
        await Future<void>.delayed(Duration.zero);
        expect(store.buys, 0);
        expect(messages.any((v) => v.contains('confirmar los datos')), true);
        await service.dispose();
        await sub.cancel();
        await store.updates.close();
      },
    );
    test('a rejected native start is explained and can be retried', () async {
      final store = TestStore()
        ..products = [plan()]
        ..accept = false;
      final service = StorePurchaseService(store: store);
      final messages = <String>[];
      final sub = service.messages.listen(messages.add);
      await service.purchaseSubscription('automotors_pack_10');
      await Future<void>.delayed(Duration.zero);
      expect(messages.any((v) => v.contains('Apple no ha iniciado')), true);
      expect(service.isStartingPurchase, false);
      store.accept = true;
      await service.purchaseSubscription('automotors_pack_10');
      expect(store.buys, 2);
      await service.dispose();
      await sub.cancel();
      await store.updates.close();
    });
  }
  testWidgets(
    'Packs opens the plan catalogue even when free publication is allowed',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await t.binding.setSurfaceSize(const Size(430, 950));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomePage(),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await t.pump();
      }
      await t.scrollUntilVisible(
        find.text('Packs y suscripción'),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('Packs y suscripción'));
      await t.pumpAndSettle();
      expect(find.byType(PublishOptionsPage), findsOneWidget);
      expect(find.byType(AddCarPage), findsNothing);
      expect(
        t
            .widget<PublishOptionsPage>(find.byType(PublishOptionsPage))
            .allowPublication,
        false,
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      // This route test does not exercise the real WebSocket transport.
      await t.runAsync(() => Supabase.instance.client.realtime.disconnect());
      await t.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
