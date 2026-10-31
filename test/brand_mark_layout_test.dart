import 'package:automotors_base/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('login preserves the full square brand image at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pumpAndSettle();

      final brand = find.byType(AutomotorsBrandMark);
      final image = find.descendant(of: brand, matching: find.byType(Image));
      final rendered = find.descendant(
        of: brand,
        matching: find.byType(RawImage),
      );
      expect(tester.getSize(rendered), const Size(112, 112));
      expect(tester.widget<Image>(image).fit, BoxFit.contain);
      expect(
        find.descendant(of: brand, matching: find.byType(ClipRRect)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
