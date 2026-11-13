import 'listing_preparation.dart';

import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

class SellerListingMetrics extends StatelessWidget {
  final Map<String, dynamic>? metrics;
  final Map<String, dynamic>? listing;
  final VoidCallback? onEdit;
  const SellerListingMetrics({
    super.key,
    this.metrics,
    this.listing,
    this.onEdit,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          uiText(context, 'Actividad del anuncio'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (metrics == null)
          Text(
            uiText(
              context,
              'Estadísticas no disponibles. Actualiza para reintentar.',
            ),
            style: const TextStyle(color: marketMuted),
          )
        else ...[
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              for (final item in const [
                ('views', 'Visitas registradas', Icons.visibility_outlined),
                ('favorites', 'Favoritos', Icons.favorite_border),
                ('conversations', 'Conversaciones', Icons.chat_bubble_outline),
              ])
                Semantics(
                  label:
                      '${uiText(context, item.$2)}: ${metrics![item.$1] ?? 0}',
                  excludeSemantics: true,
                  child: SizedBox(
                    width: 210,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.$3, size: 18, color: marketAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${metrics![item.$1] ?? 0} ${uiText(context, item.$2)}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (listing != null && listing!['status'] == 'published') ...[
            const SizedBox(height: 12),
            Text(uiText(context, sellerActivityAdvice(metrics!))),
            for (final tip in listingSuggestions(
              photoCount: (listing!['vehicle_photos'] as List?)?.length ?? 0,
              description: listing!['description']?.toString() ?? '',
              hasEquipment:
                  (listing!['equipment'] as List?)?.isNotEmpty ?? false,
            ).take(2))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(uiText(context, tip)),
              ),
            if (onEdit != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(uiText(context, 'Mejorar este anuncio')),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            uiText(
              context,
              'Visitas desde la activación: una por cuenta registrada y día, sin contar las tuyas. Favoritos actuales y conversaciones creadas.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}

String sellerActivityAdvice(Map<String, dynamic> metrics) {
  final views = (metrics['views'] as num?) ?? 0;
  final contacts = (metrics['conversations'] as num?) ?? 0;
  if (views >= 10 && contacts == 0)
    {return 'Recibes visitas pero aún no hay conversaciones. Revisa las fotos, la descripción y el precio frente a coches similares.';}
  if (contacts > 0)
    {return 'Ya hay personas interesadas. Responde a sus dudas y mantén actualizado el estado del anuncio.';}
  return 'Todavía hay poca actividad registrada. Completa el anuncio y comparte su enlace para darle a conocer.';
}
