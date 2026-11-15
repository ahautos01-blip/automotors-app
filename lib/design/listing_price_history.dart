import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

double? lastPriceDrop(List<Map<String, dynamic>> rows) {
  if (rows.length < 2) return null;
  final current = (rows[0]['price'] as num?)?.toDouble();
  final previous = (rows[1]['price'] as num?)?.toDouble();
  return current != null &&
          previous != null &&
          current > 0 &&
          previous > current
      ? previous - current
      : null;
}

class ListingPriceHistory extends StatefulWidget {
  const ListingPriceHistory({
    super.key,
    required this.listingId,
    this.currentPrice,
    this.load,
  });
  final String listingId;
  final num? currentPrice;
  final Future<List<Map<String, dynamic>>> Function()? load;
  @override
  State<ListingPriceHistory> createState() => _ListingPriceHistoryState();
}

class _ListingPriceHistoryState extends State<ListingPriceHistory> {
  late final future =
      widget.load?.call() ??
      Supabase.instance.client
          .from('listing_price_history')
          .select('price,recorded_at')
          .eq('listing_id', widget.listingId)
          .order('recorded_at', ascending: false)
          .order('id', ascending: false)
          .limit(20);
  String money(num value) =>
      '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} €';
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            uiText(context, 'Cargando historial de precios…'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      if (snapshot.hasError)
        return Text(
          uiText(context, 'Historial de precios no disponible'),
          style: Theme.of(context).textTheme.bodySmall,
        );
      final rows = snapshot.data ?? [];
      final drop =
          (rows.isEmpty ||
              widget.currentPrice == null ||
              rows.first['price'] == widget.currentPrice)
          ? lastPriceDrop(rows)
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (drop != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  const Icon(Icons.trending_down, color: marketInk),
                  Text(
                    uiText(context, 'Ha bajado {0}', [money(drop)]),
                    style: const TextStyle(
                      color: marketInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(uiText(context, 'Historial de precios')),
            leading: const Icon(Icons.history),
            children: [
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    uiText(
                      context,
                      'Aún no hay cambios de precio registrados.',
                    ),
                  ),
                ),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${MaterialLocalizations.of(context).formatShortDate(DateTime.parse(row['recorded_at'].toString()).toLocal())} · ${money(row['price'] as num)}',
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  uiText(
                    context,
                    'Solo mostramos precios registrados desde la activación del historial, con el anuncio publicado o reservado. No es una tasación ni acredita el estado del vehículo.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
