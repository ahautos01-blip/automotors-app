import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:automotors_base/vehicle_feature_control.dart';

void main() {
  Map<String, dynamic> state({int limit = 3, int used = 0, bool selected = false}) => {
    'limit': limit, 'used': used, 'selected': selected,
    'featured': selected, 'can_feature': true,
  };

  testWidgets('full quota blocks another feature but permits removing this one', (tester) async {
    final actions = <bool?>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VehicleFeatureControl(
      manage: (enabled) async { actions.add(enabled); return state(used: 3); },
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Destacados utilizados: 3 de 3'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(actions, [null]);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VehicleFeatureControl(
      key: const ValueKey('selected'),
      manage: (enabled) async {
        actions.add(enabled);
        return enabled == false ? state(used: 2) : state(used: 3, selected: true);
      },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar destacado'));
    await tester.pumpAndSettle();
    expect(actions.last, false);
    expect(find.text('Destacados utilizados: 2 de 3'), findsOneWidget);
  });

  testWidgets('server rejection keeps the listing unfeatured and refreshes quota', (tester) async {
    var reads = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VehicleFeatureControl(
      manage: (enabled) async {
        if (enabled == true) throw const PostgrestException(message: 'Límite alcanzado');
        return state(used: reads++ == 0 ? 2 : 3);
      },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Destacar vehículo').last);
    await tester.pumpAndSettle();
    expect(find.text('Límite alcanzado'), findsOneWidget);
    expect(find.text('Destacados utilizados: 3 de 3'), findsOneWidget);
    expect(find.text('Quitar destacado'), findsNothing);
  });

  testWidgets('free account has no feature action', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VehicleFeatureControl(
      manage: (_) async => state(limit: 0),
    ))));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(find.text('Necesitas un pack o una suscripción activa.'), findsOneWidget);
  });
}
