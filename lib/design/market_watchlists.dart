import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

String watchPrice(num value) =>
    '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} €';

class MarketAlertPreferences extends StatelessWidget {
  final bool newListings, priceDrops, busy;
  final ValueChanged<bool> onNewListings, onPriceDrops;
  const MarketAlertPreferences({
    super.key,
    required this.newListings,
    required this.priceDrops,
    required this.onNewListings,
    required this.onPriceDrops,
    this.busy = false,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Column(
      children: [
        Text(uiText(context,'También recibirás estos avisos en el iPhone si permites las notificaciones de AUTOMOTORS.')),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(uiText(context, 'Anuncios nuevos')),
          value: newListings,
          onChanged: busy ? null : onNewListings,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(uiText(context, 'Bajadas de precio')),
          value: priceDrops,
          onChanged: busy ? null : onPriceDrops,
        ),
      ],
    ),
  );
}

class MarketFavoriteCard extends StatelessWidget {
  final String title, details;
  final num price;
  final num? referencePrice;
  final Uint8List? photo;
  final bool watching, busy, available, comparing;
  final VoidCallback? onCompare;
  final VoidCallback onOpen, onRemove;
  final ValueChanged<bool> onWatch;
  const MarketFavoriteCard({
    super.key,
    required this.title,
    required this.details,
    required this.price,
    this.referencePrice,
    this.photo,
    required this.watching,
    this.busy = false,
    this.available = true,
    this.comparing = false,
    this.onCompare,
    required this.onOpen,
    required this.onRemove,
    required this.onWatch,
  });
  @override
  Widget build(BuildContext context) {
    final lower =
        referencePrice != null && price > 0 && price < referencePrice!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: available ? onOpen : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: MediaQuery.textScalerOf(context).scale(1) > 1.2
                          ? 76
                          : 96,
                      height: 124,
                      child: photo == null
                          ? const ColoredBox(
                              color: marketTint,
                              child: Icon(
                                Icons.directions_car_outlined,
                                color: marketMuted,
                              ),
                            )
                          : Image.memory(
                              photo!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, e, s) =>
                                  const Icon(Icons.directions_car_outlined),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          details,
                          style: const TextStyle(
                            color: marketMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          available
                              ? watchPrice(price)
                              : uiText(context, 'Anuncio no disponible'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 23,
                          ),
                        ),
                        if (lower && available) ...[
                          Text(
                            uiText(context, 'Referencia: {0}', [
                              watchPrice(referencePrice!),
                            ]),
                            style: const TextStyle(
                              color: marketMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            uiText(context, 'Ha bajado {0}', [
                              watchPrice(referencePrice! - price),
                            ]),
                            style: const TextStyle(
                              color: marketAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: uiText(context, 'Quitar de favoritos'),
                    onPressed: busy ? null : onRemove,
                    icon: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onCompare != null)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              value: comparing,
              onChanged: (_) => onCompare!(),
              title: Text(
                uiText(context, 'Comparar'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (available)
            SwitchListTile.adaptive(
              title: Text(
                uiText(context, 'Avisarme si baja'),
                style: const TextStyle(fontSize: 12),
              ),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              value: watching,
              onChanged: busy ? null : onWatch,
            ),
        ],
      ),
    );
  }
}
