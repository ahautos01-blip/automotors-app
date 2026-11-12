import 'package:flutter/material.dart';

import 'market_theme.dart';

/// Public business identity shared by the profile and account preview.
class MarketProfessionalHeader extends StatelessWidget {
  const MarketProfessionalHeader({
    super.key,
    required this.name,
    required this.accountLabel,
    this.coverUrl,
    this.avatarUrl,
    this.location = '',
  });
  final String name, accountLabel, location;
  final String? coverUrl, avatarUrl;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 232,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 178,
              child: Container(
                key: const Key('professional-cover'),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF1EEE6), Color(0xFFDCD6C7)],
                  ),
                ),
                child: coverUrl == null
                    ? const Icon(
                        Icons.directions_car_outlined,
                        color: marketMuted,
                        size: 64,
                      )
                    : Image.network(
                        coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.directions_car_outlined,
                          color: marketMuted,
                          size: 64,
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 124,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  key: const Key('professional-avatar'),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: marketPaper,
                    boxShadow: [
                      BoxShadow(
                        color: marketInk.withValues(alpha: .12),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: marketSurface,
                    backgroundImage: avatarUrl == null
                        ? null
                        : NetworkImage(avatarUrl!),
                    onBackgroundImageError: avatarUrl == null
                        ? null
                        : (_, __) {},
                    child: avatarUrl == null
                        ? const Icon(
                            Icons.business_outlined,
                            color: marketAccent,
                            size: 38,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          children: [
            Text(
              name,
              key: const Key('professional-display-name'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: marketInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              accountLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(color: marketMuted, fontSize: 14),
            ),
            if (location.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                location,
                textAlign: TextAlign.center,
                style: const TextStyle(color: marketMuted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
