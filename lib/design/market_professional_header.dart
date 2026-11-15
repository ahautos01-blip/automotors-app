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
        height: 274,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 214,
              child: Container(
                key: const Key('professional-cover'),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF1EEE6), Color(0xFFDCD6C7)],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    coverUrl == null
                        ? const Icon(
                            Icons.directions_car_outlined,
                            color: marketMuted,
                            size: 84,
                          )
                        : Image.network(
                            coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.directions_car_outlined,
                              color: marketMuted,
                              size: 84,
                            ),
                          ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x4422342B)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 22,
                      child: Container(width: 38, height: 3, color: marketGold),
                    ),
                    Positioned(
                      right: 24,
                      bottom: 22,
                      child: Container(width: 38, height: 3, color: marketGold),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 154,
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
                    radius: 56,
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
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
        child: Column(
          children: [
            Text(
              name,
              key: const Key('professional-display-name'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 27,
                height: 1.12,
                letterSpacing: -.7,
                fontWeight: FontWeight.w800,
                color: marketInk,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: marketTint,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: marketGold.withValues(alpha: .3)),
              ),
              child: Text(
                accountLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: marketAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
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
