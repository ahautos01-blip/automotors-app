import 'dart:typed_data';

import 'package:automotors_base/main.dart';
import 'package:automotors_base/services/listing_photo_loader.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Map<String, dynamic> listing(bool plate, bool vin) => {
    'vehicle_brands': {'name': 'BMW'},
    'vehicle_models': {'name': '320'},
    'year': 2020,
    'km': 50000,
    'price': 20000,
    'fuel': 'Diésel',
    'matricula': '1234XYZ',
    'vin': 'WBA12345678901234',
    'show_matricula_publicly': plate,
    'show_vin_publicly': vin,
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      httpClient: MockClient(
        (_) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  test('absent visibility flags never expose stored identifiers', () {
    final row = listing(true, true)
      ..remove('show_matricula_publicly')
      ..remove('show_vin_publicly');
    final car = Car.fromListing(row);
    expect(car.vin, isNull);
    expect(car.matricula, isNull);
  });
  for (final locale in ['es', 'en', 'ca']) {
    for (final flags in [
      (false, false),
      (true, false),
      (false, true),
      (true, true),
    ]) {
      testWidgets(
        'seller visibility plate=${flags.$1} VIN=${flags.$2} in $locale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final car = Car.fromListing(listing(flags.$1, flags.$2));
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: CarDetailsPage(
                car: car,
                priceText: '20.000 €',
                onContact: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          final technical = find.byKey(const Key('listing-technical-details'));
          await tester.scrollUntilVisible(
            technical,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(technical),
            alignment: 0.2,
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .descendant(of: technical, matching: find.byType(ListTile))
                .first,
          );
          await tester.pumpAndSettle();
          if (flags.$1) {
            await tester.scrollUntilVisible(
              find.text('1234XYZ'),
              300,
              scrollable: find.byType(Scrollable).first,
            );
          }
          if (flags.$2) {
            await tester.scrollUntilVisible(
              find.text('WBA12345678901234'),
              300,
              scrollable: find.byType(Scrollable).first,
            );
          }
          expect(
            find.text('1234XYZ'),
            flags.$1 ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('WBA12345678901234'),
            flags.$2 ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  test('catalog downloads one cover; opening details fetches the remaining photos in order', () async {
    final calls = <String>[];
    final paths = ['cover', 'second', 'third'];
    Future<Uint8List> download(String path) async {
      calls.add(path);
      return Uint8List.fromList([paths.indexOf(path)]);
    }

    final cover = await loadListingCover(paths, download);
    expect(calls, ['cover']);
    final car = Car.fromListing(
      listing(true, true),
      photos: cover,
      photoPaths: paths,
    );
    expect(car.photoCount, 3);
    expect(car.photos.length, 1);
    final gallery = await loadListingGallery(paths, cover, download);
    expect(calls, paths);
    expect(gallery.map((b) => b.first), [0, 1, 2]);
  });
  test(
    'failed cover retries at detail and a broken image does not hide the rest',
    () async {
      final paths = ['cover', 'broken', 'last'];
      final cover = await loadListingCover(
        paths,
        (_) async => throw StateError('offline'),
      );
      final calls = <String>[];
      final gallery = await loadListingGallery(paths, cover, (path) async {
        calls.add(path);
        if (path == 'broken') throw StateError('missing');
        return Uint8List.fromList([path == 'cover' ? 1 : 3]);
      });
      expect(calls, paths);
      expect(gallery.map((p) => p.first), [1, 3]);
    },
  );
}
