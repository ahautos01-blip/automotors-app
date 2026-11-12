import 'l10n/ui_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The server supplies both usage and the limit; the client never grants slots.
class VehicleFeatureControl extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(bool? enabled) manage;
  final bool english;
  final VoidCallback? onChanged;

  const VehicleFeatureControl({
    super.key, required this.manage, this.english = false, this.onChanged,
  });

  @override
  State<VehicleFeatureControl> createState() => _VehicleFeatureControlState();
}

class _VehicleFeatureControlState extends State<VehicleFeatureControl> {
  Map<String, dynamic>? status;
  bool busy = false;
  String? error;
  String tr(String es, String en) => widget.english ? en : uiText(context, es);

  @override
  void initState() {
    super.initState();
    load(null);
  }

  Future<void> load(bool? enabled) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final result = await widget.manage(enabled);
      if (!mounted) return;
      setState(() => status = result);
      if (enabled != null) widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e is PostgrestException ? e.message :
        'No se pudo consultar o actualizar el destacado. Inténtalo de nuevo.');
      // Refresh after a concurrent request may have consumed the last slot.
      if (enabled != null) {
        try {
          final result = await widget.manage(null);
          if (mounted) setState(() => status = result);
        } catch (_) { /* Keep the original action error. */ }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final selected = status?['selected'] == true;
    final featured = status?['featured'] == true;
    final limit = (status?['limit'] as num?)?.toInt() ?? 0;
    final used = (status?['used'] as num?)?.toInt() ?? 0;
    final canEnable = status?['can_feature'] == true && limit > 0 && used < limit;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr(featured ? 'Vehículo destacado' : 'Destacar vehículo',
            featured ? 'Featured vehicle' : 'Feature vehicle'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: gold)),
          if (status != null) ...[
            const SizedBox(height: 8),
            Text(widget.english ? 'Featured slots used: $used of $limit' : uiText(context, 'Destacados utilizados: {0} de {1}', [used, limit])),
            const SizedBox(height: 8),
            Text(limit == 0
              ? tr('Necesitas un pack o una suscripción activa.', 'An active pack or subscription is required.')
              : status?['can_feature'] != true
                ? tr('El anuncio debe estar publicado para destacarlo.', 'Publish the listing before featuring it.')
                : tr('Puedes quitar un destacado para destacar otro vehículo. Solo se muestra mientras tu plan esté activo.',
                  'Remove a featured vehicle to feature another. It is only featured while your plan is active.')),
            if (used >= limit && limit > 0 && !selected)
              Text(tr('Has alcanzado el máximo de tu plan.', 'You have reached your plan limit.')),
            if (selected && !featured)
              Text(tr('Este anuncio no se muestra destacado: revisa la vigencia o el límite de tu plan.',
                'This listing is not currently featured: check your plan validity or limit.')),
          ],
          if (error != null) ...[
            const SizedBox(height: 8), Text(uiText(context, error!), style: const TextStyle(color: Colors.redAccent)),
            TextButton(onPressed: busy ? null : () => load(null), child: Text(tr('Reintentar', 'Retry'))),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: busy || status == null || (!selected && !canEnable) ? null : () => load(!selected),
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(selected ? Icons.star_outline_rounded : Icons.star_rounded),
            label: Text(tr(selected ? 'Quitar destacado' : 'Destacar vehículo', selected ? 'Remove feature' : 'Feature vehicle')),
          ),
        ]),
      ),
    );
  }
}
