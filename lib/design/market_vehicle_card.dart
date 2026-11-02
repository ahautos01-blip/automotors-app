import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'market_theme.dart';

/// The same photo-first listing presentation on home and catalog screens.
class MarketVehicleCard extends StatelessWidget {
  final String title;
  final String price;
  final String details;
  final String? version;
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
    this.photo,
    required this.favorite,
    this.comparison,
    this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: marketSurface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
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
                  if (status != null)
                    Positioned(left: 10, bottom: 10, child: status!),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: marketInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (version?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    version!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: marketMuted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  price,
                  style: const TextStyle(
                    color: marketInk,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.7,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
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
            ),
          ),
        ],
      ),
    ),
  );
}
