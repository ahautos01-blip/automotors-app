import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/design/launch_experience.dart';
import 'package:automotors_base/design/moderation_overview.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';

Widget app(Widget home, {double scale = 1, String language = 'es'}) =>
    MaterialApp(
      theme: automotorsMarketTheme(),
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    );
void main() {
  test('preview identifiers follow explicit visibility without leaking hidden values', () {
    expect(
      publicationIdentifiers(
        showPlate: false,
        showVin: false,
        plate: '1234ABC',
        vin: 'secret',
      ),
      isEmpty,
    );
    expect(
      publicationIdentifiers(
        showPlate: true,
        showVin: false,
        plate: '1234abc',
        vin: 'secret',
      ),
      {'Matrícula': '1234ABC'},
    );
    expect(
      publicationIdentifiers(
        showPlate: false,
        showVin: true,
        plate: 'private',
        vin: 'vf1',
      ),
      {'VIN / bastidor': 'VF1'},
    );
  });
  for (final language in ['es', 'en', 'ca']) {
    testWidgets('empty catalogue and help fit at 200 percent in $language', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var publishes = 0, saves = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  LaunchEmptyCatalogue(
                    onPublish: () => publishes++,
                    onSaveSearch: () => saves++,
                  ),
                  const ListingContextHelp(),
                  const ListingContextHelp(plans: true),
                ],
              ),
            ),
          ),
          scale: 2,
          language: language,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final actions = find.byType(FilledButton);
      await tester.ensureVisible(actions.first);
      await tester.tap(actions.first);
      expect(publishes, 1);
      final save = find.byType(OutlinedButton);
      await tester.ensureVisible(save.first);
      await tester.tap(save.first);
      expect(saves, 1);
      await tester.ensureVisible(find.byType(ExpansionTile).first);
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'preview requires explicit confirmation and can return to editing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bool? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PublicationPreviewPage(
                        title: 'Volkswagen Golf',
                        price: '12000 €',
                        details: {'Año': '2020'},
                        description: 'Descripción real',
                        photos: [],
                        equipment: [],
                      ),
                    ),
                  );
                },
                child: const Text('Preview'),
              ),
            ),
          ),
          scale: 2,
        ),
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      final back = find.text('Volver a editar');
      await tester.scrollUntilVisible(back, 300);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(result, false);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('confirm-publication-preview'));
      await tester.scrollUntilVisible(confirm, 300);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('moderation overview labels actions and adapts to large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? opened;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: ModerationOverview(
              data: const {
                'open_reports': 2,
                'failed_checks': 1,
                'checks': [
                  {'title': 'Golf 2020', 'state': 'error', 'report_id': 'case'},
                ],
              },
              onReport: (id) => opened = id,
            ),
          ),
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Golf 2020'));
    await tester.tap(find.text('Golf 2020'));
    expect(opened, 'case');
    expect(tester.takeException(), isNull);
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
  testWidgets('launch buttons meet accessible touch target guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        Scaffold(
          body: LaunchEmptyCatalogue(onPublish: () {}, onSaveSearch: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
