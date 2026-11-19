import 'dart:async';
import 'dart:typed_data';

import 'package:automotors_base/design/market_glass.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/services/listing_photo_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'covers keep order, limit concurrency and tolerate an unavailable photo',
    () async {
      var active = 0, peak = 0;
      final batches = <int>[];
      final result = await loadListingCovers(List.generate(7, (i) => ['$i']), (
        path,
      ) async {
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(Duration.zero);
        active--;
        if (path == '2') throw StateError('Unavailable');
        return Uint8List.fromList([int.parse(path)]);
      }, onBatch: (start, _) => batches.add(start));
      expect(peak, 3);
      expect(batches, [0, 3, 6]);
      expect(result.map((p) => p.isEmpty ? -1 : p.first.first), [
        0,
        1,
        -1,
        3,
        4,
        5,
        6,
      ]);
    },
  );

  test(
    'obsolete catalogue does not publish completed covers or start more',
    () async {
      final pending = Completer<Uint8List>();
      var current = true, requests = 0, batches = 0;
      final load = loadListingCovers(
        List.generate(6, (i) => ['$i']),
        (_) {
          requests++;
          return pending.future;
        },
        isCurrent: () => current,
        onBatch: (_, _) => batches++,
      );
      current = false;
      pending.complete(Uint8List(1));
      await load;
      expect(requests, 3);
      expect(batches, 0);
    },
  );

  testWidgets(
    'navigation remains opaque with increased contrast or reduced motion',
    (tester) async {
      for (final data in [
        const MediaQueryData(highContrast: true),
        const MediaQueryData(disableAnimations: true),
        const MediaQueryData(accessibleNavigation: true),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: automotorsMarketTheme(),
            home: MediaQuery(
              data: data,
              child: Scaffold(
                bottomNavigationBar: MarketGlassNavigation(
                  child: NavigationBar(
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home),
                        label: 'Inicio',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person),
                        label: 'Perfil',
                      ),
                    ],
                  ),
                ),
                body: const SizedBox(),
              ),
            ),
          ),
        );
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
