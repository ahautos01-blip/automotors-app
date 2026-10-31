import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty catalog and filters render in each language on iPhone size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final code in ['es', 'en', 'ca']) {
      final locale = Locale(code);
      final strings = lookupAppLocalizations(locale);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AllVehiclesPage(key: ValueKey(code), cars: const [], onOpenCar: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text(strings.vehiclesFound(0)), findsOneWidget);
      expect(find.text(strings.noVehiclesFound), findsOneWidget);
      await tester.tap(find.text(strings.filters));
      await tester.pumpAndSettle();
      expect(find.text(strings.hideFilters), findsOneWidget);
      expect(find.text(strings.brand), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
