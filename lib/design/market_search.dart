import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';
import '../services/vehicle_search.dart';

class MarketQuickFilters extends StatelessWidget {
  final bool automatic, suv, electric, budget;
  final VoidCallback onAutomatic, onSuv, onElectric, onBudget;
  const MarketQuickFilters({
    super.key,
    required this.automatic,
    required this.suv,
    required this.electric,
    required this.budget,
    required this.onAutomatic,
    required this.onSuv,
    required this.onElectric,
    required this.onBudget,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final item in [
          (
            label: 'Automático',
            icon: Icons.settings_outlined,
            selected: automatic,
            tap: onAutomatic,
          ),
          (
            label: 'SUV',
            icon: Icons.directions_car_outlined,
            selected: suv,
            tap: onSuv,
          ),
          (
            label: 'Eléctrico',
            icon: Icons.electric_car_outlined,
            selected: electric,
            tap: onElectric,
          ),
          (
            label: 'Hasta 20.000 €',
            icon: Icons.euro_outlined,
            selected: budget,
            tap: onBudget,
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(uiText(context, item.label)),
              selected: item.selected,
              avatar: Icon(
                item.icon,
                size: 16,
                color: item.selected ? marketSurface : marketMuted,
              ),
              onSelected: (_) => item.tap(),
              showCheckmark: false,
              selectedColor: marketInk,
              backgroundColor: marketSurface,
              labelStyle: TextStyle(
                color: item.selected ? marketSurface : marketInk,
                fontSize: 12,
              ),
              side: BorderSide(color: item.selected ? marketInk : marketLine),
              shape: const StadiumBorder(),
            ),
          ),
      ],
    ),
  );
}

Future<String?> showMarketRecentSearches(
  BuildContext context,
  List<String> history, {
  required Future<void> Function() onClear,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            uiText(context, 'Búsquedas recientes'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            uiText(context, 'Solo en este dispositivo'),
            style: const TextStyle(color: marketMuted),
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                uiText(context, 'Tus próximas búsquedas aparecerán aquí.'),
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final query in history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text(query),
                    onTap: () => Navigator.pop(sheetContext, query),
                  ),
              ],
            ),
          ),
          if (history.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(uiText(context, 'Borrar historial')),
              onPressed: () async {
                await onClear();
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    ),
  ),
);

mixin MarketRecentSearchState<T extends StatefulWidget> on State<T> {
  final recentSearchStore = RecentVehicleSearches();
  List<String> recentVehicleQueries = [];
  @override
  void initState() {
    super.initState();
    loadVehicleHistory();
  }

  Future<void> loadVehicleHistory() async {
    final queries = await recentSearchStore.load();
    if (mounted) setState(() => recentVehicleQueries = queries);
  }

  Future<void> rememberVehicleSearch(String query) async {
    await recentSearchStore.remember(query);
    await loadVehicleHistory();
  }

  Future<void> openVehicleSearchHistory(ValueChanged<String> onPick) async {
    final history = await recentSearchStore.load();
    if (!mounted) return;
    final chosen = await showMarketRecentSearches(
      context,
      history,
      onClear: () async {
        await recentSearchStore.clear();
        await loadVehicleHistory();
      },
    );
    if (!mounted || chosen == null) return;
    onPick(chosen);
    await rememberVehicleSearch(chosen);
  }
}
