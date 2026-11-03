import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'market_theme.dart';
import 'market_details.dart';
import '../l10n/ui_text.dart';

/// The same photo-first listing presentation on home and catalog screens.
class MarketVehicleCard extends StatelessWidget {
  final String title;
  final String price;
  final String details;
  final String? version;
  final int photoCount;
  final Uint8List? photo;
  final Widget favorite;
  final Widget? comparison;
  final Widget? status;
  final VoidCallback onTap;

  const MarketVehicleCard({
    super.key,
    required this.title,
    required this.price,
    required this.details,
    this.version,
    this.photoCount = 0,
    this.photo,
    required this.favorite,
    this.comparison,
    this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => MarketReveal(
    child: Card(
      color: marketSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const Key('listing-card-photo'),
                height:
                    (constraints.maxHeight -
                            185 * MediaQuery.textScalerOf(context).scale(1))
                        .clamp(80, constraints.maxWidth * .75),
                child: ColoredBox(
                  color: marketTint,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photo != null)
                        Image.memory(
                          photo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) => const Center(
                            child: Icon(
                              Icons.directions_car_outlined,
                              color: marketMuted,
                              size: 48,
                            ),
                          ),
                        )
                      else
                        const Center(
                          child: Icon(
                            Icons.directions_car_outlined,
                            color: marketMuted,
                            size: 48,
                          ),
                        ),
                      Positioned(right: 10, top: 10, child: favorite),
                      if (comparison != null)
                        Positioned(left: 10, top: 10, child: comparison!),
                      if (photoCount > 0)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: marketSurface.withValues(alpha: .95),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.photo_library_outlined,
                                    size: 13,
                                    color: marketInk,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    uiText(context, '{0} fotos', [photoCount]),
                                    style: const TextStyle(
                                      color: marketInk,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (status != null)
                        Positioned(left: 10, bottom: 10, child: status!),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxWidth < 285 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.2;
                    final heading = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: marketInk,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        if (version?.trim().isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              version!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: marketMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );
                    final priceLabel = Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: marketInk,
                        fontSize: compact ? 25 : 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.7,
                      ),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (compact) ...[
                          heading,
                          const SizedBox(height: 10),
                          priceLabel,
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: heading),
                              const SizedBox(width: 12),
                              priceLabel,
                            ],
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        Text(
                          details,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: marketMuted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Compact editorial row used for secondary cars without losing listing actions.
class MarketEditorialCarRow extends StatelessWidget {
  final String title, price, details;
  final String? version;
  final Uint8List? photo;
  final Widget favorite;
  final Widget? status;
  final VoidCallback onTap;
  const MarketEditorialCarRow({
    super.key,
    required this.title,
    required this.price,
    required this.details,
    this.version,
    this.photo,
    required this.favorite,
    this.status,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 88,
                    height: 112,
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
                Positioned(top: 0, right: 0, child: favorite),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (version?.trim().isNotEmpty == true)
                    Text(
                      version!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: marketMuted),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.7,
                    ),
                  ),
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: status!,
                    ),
                  const SizedBox(height: 5),
                  Text(
                    details,
                    style: const TextStyle(fontSize: 12, color: marketMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
