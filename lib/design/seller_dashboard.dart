import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

class SellerDashboard extends StatelessWidget {
  final List<Map<String, dynamic>> listings;
  final Map<String, dynamic>? offers;
  final VoidCallback onInbox;
  const SellerDashboard({
    super.key,
    required this.listings,
    required this.offers,
    required this.onInbox,
  });
  @override
  Widget build(BuildContext context) {
    final available = listings.every((v) => v['metrics'] is Map);
    int total(String field) => listings.fold(
      0,
      (n, l) => n + ((l['metrics'] as Map?)?[field] as num? ?? 0).toInt(),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: marketSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: marketLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            uiText(context, 'Tu actividad de venta'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final item in [
                ('Visitas registradas', available ? '${total('views')}' : '—'),
                ('Favoritos', available ? '${total('favorites')}' : '—'),
                (
                  'Conversaciones',
                  available ? '${total('conversations')}' : '—',
                ),
                (
                  'Ofertas pendientes',
                  offers == null ? '—' : '${offers!['pending_offers'] ?? 0}',
                ),
              ])
                SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: marketInk,
                        ),
                      ),
                      Text(
                        uiText(context, item.$1),
                        style: const TextStyle(color: marketMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            uiText(
              context,
              'Totales de tus anuncios. Las ofertas caducadas o bloqueadas no cuentan como pendientes. «—» significa que el dato no está disponible.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton.icon(
            onPressed: onInbox,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(uiText(context, 'Revisar conversaciones y ofertas')),
          ),
        ],
      ),
    );
  }
}
