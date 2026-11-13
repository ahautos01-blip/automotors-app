import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

class SellerListingMetrics extends StatelessWidget {
  final Map<String, dynamic>? metrics;
  const SellerListingMetrics({super.key, this.metrics});
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
