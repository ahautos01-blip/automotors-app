import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:automotors_base/main.dart';
import 'package:automotors_base/design/publication_design.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    for (final method in [
      'startListeningToTransactions',
      'stopListeningToTransactions',
    ]) {
      messenger.setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.in_app_purchase_storekit.InAppPurchase2API.$method',
          const StandardMessageCodec(),
        ),
        (_) async => [null],
      );
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (r) async => http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        ),
      ),
    );
  });
  testWidgets(
    'plans show all prices and publication starts with a clear first step',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final path = Platform.environment['CATALOGUE_PREVIEW_PATH'];
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      if (path != null) {
        await tester.runAsync(() async {
          for (final name in [
            'CataloguePreview',
            'Ahem',
            'Roboto',
            '.SF UI Text',
            '.SF UI Display',
            'CupertinoSystemText',
            'CupertinoSystemDisplay',
          ]) {
            final f = FontLoader(name)
              ..addFont(
                File('C:/Windows/Fonts/segoeui.ttf')
                    .readAsBytes()
                    .then(ByteData.sublistView),
              );
            await f.load();
          }
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              File(
                'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes().then(ByteData.sublistView),
            );
          await icons.load();
        });
      }
      final key = GlobalKey(), theme = automotorsMarketTheme();
      for (final screen in ['plans', 'form']) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('es'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: path == null
                  ? theme
                  : theme.copyWith(
                      textTheme: theme.textTheme.apply(
                        fontFamily: 'CataloguePreview',
                      ),
                      filledButtonTheme: FilledButtonThemeData(
                        style: theme.filledButtonTheme.style?.copyWith(
                          textStyle: const WidgetStatePropertyAll(
                            TextStyle(
                              fontFamily: 'CataloguePreview',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      outlinedButtonTheme: OutlinedButtonThemeData(
                        style: theme.outlinedButtonTheme.style?.copyWith(
                          textStyle: const WidgetStatePropertyAll(
                            TextStyle(
                              fontFamily: 'CataloguePreview',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style:
                            theme.textButtonTheme.style?.copyWith(
                              textStyle: const WidgetStatePropertyAll(
                                TextStyle(
                                  fontFamily: 'CataloguePreview',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ) ??
                            TextButton.styleFrom(
                              textStyle: const TextStyle(
                                fontFamily: 'CataloguePreview',
                              ),
                            ),
                      ),
                      primaryTextTheme: theme.primaryTextTheme.apply(
                        fontFamily: 'CataloguePreview',
                      ),
                    ),
              home: screen == 'plans'
                  ? const PublishOptionsPage()
                  : const AddCarPage(),
            ),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        if (screen == 'plans') {
          expect(find.byType(PublicationPlanChoice), findsNWidgets(4));
          for (var i = 0; i < 4; i++)
            expect(
              find.byKey(ValueKey('publish-plan-$i')).hitTestable(),
              findsOneWidget,
            );
        } else {
          expect(find.text('Empecemos por tu vehículo'), findsOneWidget);
          expect(find.byKey(const Key('publication-autofill')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        final ctx = tester.element(find.byType(Scaffold).first);
        ScaffoldMessenger.of(ctx).clearSnackBars();
        await tester.pumpAndSettle();
        if (path != null) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File('$path-$screen.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() => Supabase.instance.dispose());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
