import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

class MarketReveal extends StatelessWidget {
  final Widget child;
  const MarketReveal({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class MarketLoadingCard extends StatelessWidget {
  const MarketLoadingCard({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: uiText(context, 'Cargando vehículos…'),
    liveRegion: true,
    child: ExcludeSemantics(
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: marketSurface,
          borderRadius: BorderRadius.circular(22),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: ColoredBox(color: marketTint)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 190, color: marketTint),
                  const SizedBox(height: 12),
                  Container(height: 23, width: 110, color: marketTint),
                  const SizedBox(height: 12),
                  Container(height: 10, width: 240, color: marketTint),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class MarketQuickLink extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const MarketQuickLink({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: marketSurface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: marketTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: marketAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiText(context, title),
                    style: const TextStyle(
                      color: marketInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    uiText(context, subtitle),
                    style: const TextStyle(
                      color: marketMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.north_east_rounded, color: marketInk, size: 19),
          ],
        ),
      ),
    ),
  );
}

class MarketSellerSummary extends StatelessWidget {
  final Future<Map<String, dynamic>?> profile;
  final VoidCallback onOpen;
  const MarketSellerSummary({
    super.key,
    required this.profile,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: profile,
    builder: (context, snapshot) {
      final row = snapshot.data;
      final business = row?['business_name']?.toString().trim() ?? '';
      final person = row?['full_name']?.toString().trim() ?? '';
      final name = business.isNotEmpty ? business : person;
      final city = row?['city']?.toString().trim() ?? '';
      return Material(
        color: marketSurface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: marketTint,
                  foregroundColor: marketAccent,
                  child: Icon(
                    business.isNotEmpty
                        ? Icons.storefront_outlined
                        : Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiText(context, 'VENDEDOR'),
                        style: const TextStyle(
                          color: marketMuted,
                          fontSize: 10,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name.isEmpty
                            ? uiText(context, 'Ver perfil del vendedor')
                            : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: marketInk,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (city.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: marketMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: marketInk),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<String?> promptMarketSavedSearchName(
  BuildContext context,
  String initialName,
) async {
  final controller = TextEditingController(text: initialName);
  final route = DialogRoute<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: Text(uiText(context, 'Guardar búsqueda')),
        content: TextField(
          key: const Key('market-search-name'),
          controller: controller,
          autofocus: true,
          maxLength: 80,
          onChanged: (_) => refresh(() {}),
          decoration: InputDecoration(
            labelText: uiText(context, 'Nombre de la búsqueda'),
            hintText: uiText(context, 'Ej. SUV diésel hasta 20.000 €'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(uiText(context, 'Cancelar')),
          ),
          FilledButton(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(uiText(context, 'Guardar')),
          ),
        ],
      ),
    ),
  );
  final result = await Navigator.of(context).push(route);
  await route.completed;
  controller.dispose();
  return result;
}
