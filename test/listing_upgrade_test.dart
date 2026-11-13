import 'package:flutter/material.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/design/listing_preparation.dart';
import 'package:automotors_base/design/seller_listing_metrics.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/services/listing_links.dart';

void main() {
  const id = '12345678-1234-1234-1234-123456789abc';
  test('shared links are public HTTPS, never the process base URI', () {
    final u = listingShareUri(id);
    expect(u.scheme, 'https');
    expect(u.host, 'automotors.info');
    expect(listingIdFromUri(u), id);
    expect(
      listingIdFromUri(
        Uri.parse('com.automotors.automotorsbase://listing?listing=$id'),
      ),
      id,
    );
  });
  test('only exact listing routes on trusted hosts are accepted', () {
    for (final u in [
      'https://evil.example/anuncio/?listing=$id',
      'https://automotors.info.evil.example/anuncio/?listing=$id',
      'http://automotors.info/anuncio/?listing=$id',
      'https://automotors.info/auth/confirm?listing=$id',
      'com.automotors.automotorsbase://auth?listing=$id',
      'https://automotors.info/anuncio/?listing=bad',
    ])
      expect(listingIdFromUri(Uri.parse(u)), isNull, reason: u);
    expect(listingShareUri('not-an-id').queryParameters, isEmpty);
  });
  test('quality suggestions request unknown facts without certifying them', () {
    expect(
      listingSuggestions(photoCount: 1, description: '', hasEquipment: false),
      hasLength(5),
    );
    expect(
      listingSuggestions(
        photoCount: 5,
        description: 'ITV en vigor. Mantenimiento documentado. Estado: uso habitual con pequeños desperfectos en el paragolpes.',
        hasEquipment: true,
      ),
      isEmpty,
    );
  });
  for (final scale in [1.0, 2.0])
    testWidgets(
      'preparation and metrics wrap at narrow width and scale $scale',
      (t) async {
        await t.binding.setSurfaceSize(const Size(320, 800));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final description = TextEditingController();
        addTearDown(description.dispose);
        await t.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: automotorsMarketTheme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      ListingPreparation(
                        photoCount: 2,
                        description: description,
                        hasEquipment: false,
                      ),
                      const SellerListingMetrics(
                        metrics: {
                          'views': 12345,
                          'favorites': 18,
                          'conversations': 12,
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.ensureVisible(find.byType(ExpansionTile));
        await t.pumpAndSettle();
        await t.tap(find.byType(ExpansionTile));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  testWidgets('unavailable metrics are not invented as zeros', (t) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: SellerListingMetrics()),
      ),
    );
    expect(
      find.text('Estadísticas no disponibles. Actualiza para reintentar.'),
      findsOneWidget,
    );
    expect(find.text('0 Favoritos'), findsNothing);
  });
  test('small gold text has accessible contrast on white and paper', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
    }

    expect(contrast(marketAccent, marketSurface), greaterThanOrEqualTo(4.5));
    expect(contrast(marketAccent, marketPaper), greaterThanOrEqualTo(4.5));
  });
}
