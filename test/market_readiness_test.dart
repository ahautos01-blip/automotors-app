import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/l10n/ui_text.dart';
import 'package:automotors_base/design/active_market_filters.dart';
import 'package:automotors_base/design/listing_price_history.dart';
import 'package:automotors_base/design/listing_preparation.dart';
import 'package:automotors_base/design/market_activity_page.dart';
import 'package:automotors_base/design/seller_performance_report.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/services/listing_photo_loader.dart';
import 'package:automotors_base/services/listing_links.dart';
import 'package:automotors_base/services/market_activity.dart';

Widget localized(String code, Widget child) => MaterialApp(
  theme: automotorsMarketTheme(),
  locale: Locale(code),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);

late SupabaseClient fixtureClient;

class FakeActivity extends MarketActivityService {
  FakeActivity() : super(fixtureClient);
  bool fail = false;
  @override
  Future<Map<String, dynamic>> load() async {
    if (fail) throw StateError('offline');
    return {
      'unread_conversations': 2,
      'offers': [
        {
          'conversation_id': '71',
          'role': 'buyer',
          'expires_at': '2026-11-20T14:00:00Z',
        },
      ],
      'visits': [
        {'conversation_id': '72', 'scheduled_at': '2026-11-21T12:00:00Z'},
      ],
    };
  }
}

void main() {
  setUpAll(() {
    fixtureClient = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDownAll(() async {
    await fixtureClient.dispose();
  });
  test('seller links use associated routes and reject foreign hosts or mixed targets', () {
    const id = '12345678-1234-1234-1234-123456789abc';
    expect(sellerIdFromUri(sellerShareUri(id)), id);
    expect(
      sellerIdFromUri(
        Uri.parse('com.automotors.automotorsbase://seller?seller=$id'),
      ),
      id,
    );
    for (final link in [
      'http://automotors.info/anuncio/?seller=$id',
      'https://evil.example/anuncio/?seller=$id',
      'https://automotors.info/anuncio/?seller=bad',
      'https://automotors.info/anuncio/?listing=$id&seller=$id',
    ])
      expect(sellerIdFromUri(Uri.parse(link)), isNull);
  });
  test(
    'price drop reflects only the last recorded change, not an earlier high',
    () {
      expect(lastPriceDrop([]), isNull);
      expect(
        lastPriceDrop([
          {'price': 100},
        ]),
        isNull,
      );
      expect(
        lastPriceDrop([
          {'price': 90},
          {'price': 100},
        ]),
        10,
      );
      expect(
        lastPriceDrop([
          {'price': 110},
          {'price': 100},
          {'price': 150},
        ]),
        isNull,
      );
    },
  );
  test('structured ITV and maintenance satisfy recommendations without fabricated description', () {
    expect(
      listingSuggestions(
        photoCount: 5,
        description: 'x' * 100,
        hasEquipment: true,
        marketFacts: {'itv': 'valid', 'maintenance': 'documented'},
      ),
      isEmpty,
    );
  });
  test('secondary text has readable contrast on paper and surface', () {
    for (final background in [marketPaper, marketSurface])
      expect(
        (background.computeLuminance() + .05) /
            (marketMuted.computeLuminance() + .05),
        greaterThanOrEqualTo(4.5),
      );
  });
  test('profile covers use at most three downloads and preserve positions on errors', () async {
    var active = 0, peak = 0;
    final result = await loadProfileListingCovers(
      ['1', '2', 'bad', null, '3', '4'],
      (path) async {
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 2));
        active--;
        if (path == 'bad') throw StateError('offline');
        return Uint8List.fromList([int.parse(path)]);
      },
    );
    expect(peak, 3);
    expect(result.map((v) => v?.first).toList(), [1, 2, null, null, 3, 4]);
  });
  test(
    'performance sorting retains input and excludes unavailable metrics',
    () {
      final rows = [
        {
          'id': 'a',
          'metrics': {'views': 1},
        },
        {
          'id': 'b',
          'metrics': {'views': 9},
        },
        {'id': 'c'},
      ];
      expect(mostViewedListings(rows).map((r) => r['id']), ['b', 'a']);
      expect(rows.first['id'], 'a');
    },
  );
  testWidgets(
    'activity opens the selected private conversation and retries errors',
    (tester) async {
      final service = FakeActivity();
      final opened = <String>[];
      await tester.pumpWidget(
        localized(
          'es',
          MarketActivityPage(
            service: service,
            openChat: (id) async {
              opened.add(id);
            },
            openInbox: () async {
              opened.add('inbox');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contraoferta del vendedor'));
      await tester.pumpAndSettle();
      expect(opened, ['71']);
      service.fail = true;
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo cargar tu actividad.'), findsOneWidget);
      service.fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Cita confirmada'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('filter removal is individual and clear-all stays accessible', (
    tester,
  ) async {
    final removed = <String>[];
    await tester.pumpWidget(
      localized(
        'es',
        Scaffold(
          body: ActiveMarketFilters(
            filters: [
              MapEntry('Mataró', () => removed.add('town')),
              MapEntry('BMW', () => removed.add('brand')),
            ],
            onClear: () => removed.add('all'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Quitar filtro').first);
    expect(removed, ['town']);
    await tester.tap(find.text('Quitar todos los filtros'));
    expect(removed, ['town', 'all']);
  });
  for (final code in ['es', 'en', 'ca']) {
    testWidgets(
      'readiness cards tolerate 200% text on small iPhones in $code',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final description = TextEditingController(
          text: 'Vehículo con ITV vigente y mantenimiento documentado. ' * 3,
        );
        await tester.pumpWidget(
          localized(
            code,
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                  body: ListView(
                    children: [
                      ListingPreparation(
                        photoCount: 5,
                        description: description,
                        hasEquipment: true,
                      ),
                      ListingPriceHistory(
                        listingId: 'fixture',
                        load: () async => [
                          {
                            'price': 9000,
                            'recorded_at': '2026-11-15T10:00:00Z',
                          },
                          {
                            'price': 10000,
                            'recorded_at': '2026-11-14T10:00:00Z',
                          },
                        ],
                      ),
                      SellerPerformanceReport(
                        listings: [
                          {
                            'status': 'published',
                            'vehicle_brands': {'name': 'Volkswagen'},
                            'vehicle_models': {'name': 'Golf'},
                            'metrics': {
                              'views': 10,
                              'favorites': 2,
                              'conversations': 1,
                            },
                          },
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final history = find.text(
          translateUiMessage('Historial de precios', code, []),
        );
        await tester.scrollUntilVisible(
          history,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(history), alignment: .3);
        await tester.pumpAndSettle();
        await tester.tap(history);
        await tester.pumpAndSettle();
        expect(find.textContaining('10.000'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        description.dispose();
      },
    );
  }
}
