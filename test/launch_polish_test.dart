import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/design/photo_guide_checklist.dart';
import 'package:automotors_base/design/offer_agreement_card.dart';
import 'package:automotors_base/services/listing_share_card.dart';
import 'package:automotors_base/l10n/app_localizations.dart';

void main() {
  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'agreement actions and photo checklist fit large text in $language',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var checked = <String>{};
        var visits = 0;
        var messages = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      OfferAgreementCard(
                        amount: '12000',
                        onVisit: () => visits++,
                        onMessage: () => messages++,
                      ),
                      PhotoGuideChecklist(
                        completed: checked,
                        onChanged: (value) => setState(() => checked = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final visit = find.byType(FilledButton).first;
        await tester.ensureVisible(visit);
        await tester.tap(visit);
        final message = find.byType(TextButton).first;
        await tester.ensureVisible(message);
        await tester.tap(message);
        expect(visits, 1);
        expect(messages, 1);
        await tester.ensureVisible(find.byType(ExpansionTile));
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        final first = find.byType(CheckboxListTile).first;
        await tester.ensureVisible(first);
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(checked, {'front'});
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'share card exports a square PNG with the supplied public photo',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 32, 32),
          Paint()..color = const Color(0xFFFF0000),
        );
        final image = await recorder.endRecording().toImage(32, 32);
        final photo = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        image.dispose();
        final png = await listingShareCard(
          title: 'Vehículo de prueba',
          price: '12.000 €',
          details: '2020 · 50.000 km',
          link: 'https://automotors.info/?listing=test',
          photo: photo,
        );
        expect(png.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
        final codec = await ui.instantiateImageCodec(png);
        final result = (await codec.getNextFrame()).image;
        expect(result.width, 1080);
        expect(result.height, 1080);
        final pixels = (await result.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final pixel = (400 * 1080 + 540) * 4;
        expect(pixels[pixel], 255);
        expect(pixels[pixel + 1], 0);
        result.dispose();
        codec.dispose();
        final fallback = await listingShareCard(
          title: 'Sin foto',
          price: '12.000 €',
          details: 'Datos',
          link: 'https://automotors.info',
          photo: Uint8List.fromList([1, 2, 3]),
        );
        expect(fallback, isNotEmpty);
      });
    },
  );
}
