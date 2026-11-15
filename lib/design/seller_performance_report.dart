import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

List<Map<String, dynamic>> mostViewedListings(List<Map<String, dynamic>> rows) {
  final ranked = rows.where((r) => r['metrics'] is Map).toList();
  ranked.sort(
    (a, b) => ((b['metrics']['views'] as num?) ?? 0).compareTo(
      (a['metrics']['views'] as num?) ?? 0,
    ),
  );
  return ranked.take(5).toList();
}

class SellerPerformanceReport extends StatelessWidget {
  const SellerPerformanceReport({super.key, required this.listings});
  final List<Map<String, dynamic>> listings;
  @override
  Widget build(BuildContext context) {
    final ranked = mostViewedListings(listings);
    final maxViews = ranked.isEmpty
        ? 0
        : ((ranked.first['metrics']['views'] as num?) ?? 0);
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(uiText(context, 'Informe de resultados')),
        leading: const Icon(Icons.bar_chart_outlined, color: marketAccent),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final status in [
                  ('published', 'Publicados'),
                  ('reserved', 'Reservados'),
                  ('sold', 'Vendidos'),
                  ('draft', 'Borradores'),
                ])
                  Chip(
                    label: Text(
                      '${uiText(context, status.$2)}: ${listings.where((r) => r['status'] == status.$1).length}',
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              uiText(
                context,
                'Totales acumulados de tus anuncios, no ventas ni ingresos. Las visitas se cuentan por cuenta y día. No se muestra quién los visita o guarda.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (ranked.isEmpty)
            Text(uiText(context, 'Todavía no hay estadísticas disponibles.')),
          for (final row in ranked)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    [
                          if (row['vehicle_brands'] is Map)
                            row['vehicle_brands']['name'],
                          if (row['vehicle_models'] is Map)
                            row['vehicle_models']['name'],
                        ].whereType<String>().join(' ').trim().isEmpty
                        ? uiText(context, 'Vehículo anunciado')
                        : [
                            if (row['vehicle_brands'] is Map)
                              row['vehicle_brands']['name'],
                            if (row['vehicle_models'] is Map)
                              row['vehicle_models']['name'],
                          ].whereType<String>().join(' '),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: maxViews <= 0
                          ? 0
                          : (((row['metrics']['views'] as num?) ?? 0) /
                                    maxViews)
                                .clamp(0, 1)
                                .toDouble(),
                      minHeight: 6,
                      color: marketAccent,
                      backgroundColor: marketLine,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    uiText(
                      context,
                      '{0} visitas · {1} favoritos · {2} conversaciones',
                      [
                        row['metrics']['views'] ?? 0,
                        row['metrics']['favorites'] ?? 0,
                        row['metrics']['conversations'] ?? 0,
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
