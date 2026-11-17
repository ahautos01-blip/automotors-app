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
        height: 248,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 204,
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
                            cacheWidth: 1600,
                            semanticLabel: name,
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
                  ],
                ),
              ),
            ),
            Positioned(
              top: 160,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  key: const Key('professional-avatar'),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: marketPaper,
                    boxShadow: [
                      BoxShadow(
                        color: marketInk.withValues(alpha: .12),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: avatarUrl == null
                          ? ColoredBox(
                              color: marketInk,
                              child: Center(
                                child: Text(
                                  name
                                      .trim()
                                      .split(RegExp(r'\s+'))
                                      .where((v) => v.isNotEmpty)
                                      .take(2)
                                      .map((v) => v[0])
                                      .join()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFE2CC8B),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 28,
                                  ),
                                ),
                              ),
                            )
                          : Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: 336,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: marketTint,
                                child: Icon(
                                  Icons.business_outlined,
                                  color: marketAccent,
                                ),
                              ),
                            ),
                    ),
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
                fontSize: 31,
                height: 1.12,
                letterSpacing: -.7,
                fontWeight: FontWeight.w500,
                color: marketInk,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: Colors.transparent),
              child: Text(
                accountLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: marketAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
