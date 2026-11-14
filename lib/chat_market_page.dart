import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design/market_safety.dart';
import 'l10n/ui_text.dart';
import 'services/app_diagnostics.dart';

double? parseMarketOffer(String input) {
  final text = input.trim();
  if (!RegExp(r'^[0-9]+([,.][0-9]{1,2})?$').hasMatch(text)) return null;
  final value = double.tryParse(text.replaceAll(',', '.'));
  return value != null && value > 0 && value <= 100000000 ? value : null;
}

String marketActivityStatus(String value) => switch (value) {
  'pending' => 'Pendiente',
  'accepted' => 'Aceptada',
  'rejected' => 'Rechazada',
  'cancelled' => 'Cancelada',
  _ => 'Caducada',
};

class ChatMarketPage extends StatefulWidget {
  const ChatMarketPage({super.key, required this.conversationId});
  final String conversationId;
  @override
  State<ChatMarketPage> createState() => _ChatMarketPageState();
}

class _ChatMarketPageState extends State<ChatMarketPage>
    with WidgetsBindingObserver {
  final db = Supabase.instance.client;
  List<Map<String, dynamic>> items = [];
  bool loading = true, busy = false, failed = false, buyer = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!busy && !loading) load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
      startTimer();
    } else {
      timer?.cancel();
    }
  }

  Future<dynamic> request(
    String action, {
    String? id,
    String? kind,
    double? amount,
    DateTime? date,
    String? place,
  }) => db.rpc(
    'chat_market_action',
    params: {
      'p_conversation': widget.conversationId,
      'p_action': action,
      'p_id': id,
      'p_kind': kind,
      'p_amount': amount,
      'p_scheduled': date?.toUtc().toIso8601String(),
      'p_place': place,
    },
  );
  Future<void> load() async {
    try {
      final c = await db
          .from('chat_conversations')
          .select('buyer_id')
          .eq('id', widget.conversationId)
          .single();
      final rows = await request('list');
      if (!mounted) return;
      setState(() {
        items = List<Map<String, dynamic>>.from(rows as List);
        buyer = c['buyer_id'] == db.auth.currentUser?.id;
        failed = false;
        loading = false;
      });
    } catch (e) {
      AppDiagnostics.record('chat', e);
      if (mounted)
        setState(() {
          items = [];
          failed = true;
          loading = false;
        });
    }
  }

  Future<void> change(String action, Map<String, dynamic> item) async {
    if (busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiText(context, 'Confirmar cambio')),
        content: Text(
          uiText(
            context,
            action == 'cancel' ? '¿Quieres cancelar esta propuesta?' : 'La respuesta quedará visible para la otra persona. No se realizará ningún pago ni reserva.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(uiText(context, 'Volver')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(uiText(context, 'Confirmar')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => busy = true);
    try {
      await request(action, id: item['id'].toString());
      await load();
    } catch (e) {
      AppDiagnostics.record('chat', e);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                'No se pudo cambiar la propuesta. Actualiza para comprobar su estado.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> create(String kind) async {
    if (busy) return;
    DateTime? date;
    if (kind == 'visit') {
      final now = DateTime.now();
      final day = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 1)),
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 90)),
      );
      if (day == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 11, minute: 0),
      );
      if (time == null || !mounted) return;
      date = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      if (date.isBefore(DateTime.now().add(const Duration(minutes: 15)))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(context, 'Elige una hora al menos 15 minutos posterior.'),
            ),
          ),
        );
        return;
      }
    }
    final text = await showDialog<String>(
      context: context,
      builder: (_) => MarketProposalDialog(kind: kind),
    );
    if (text == null || !mounted) return;
    setState(() => busy = true);
    try {
      await request(
        'create',
        kind: kind,
        amount: kind == 'offer' ? parseMarketOffer(text) : null,
        date: date,
        place: kind == 'visit' ? text : null,
      );
      await load();
    } catch (e) {
      AppDiagnostics.record('chat', e);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                'No se pudo enviar. Revisa si ya hay una propuesta pendiente y comprueba el anuncio.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(uiText(context, 'Ofertas y citas')),
      actions: [
        IconButton(
          tooltip: uiText(context, 'Actualizar'),
          onPressed: loading || busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const MarketSafetyAdvice(),
          Text(
            uiText(
              context,
              'Las propuestas son privadas entre los participantes. No se cobra ni se reserva el coche desde esta pantalla.',
            ),
          ),
          if (!loading && !failed)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (buyer)
                  FilledButton.icon(
                    onPressed: busy ? null : () => create('offer'),
                    icon: const Icon(Icons.local_offer_outlined),
                    label: Text(uiText(context, 'Hacer una oferta')),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => create('visit'),
                  icon: const Icon(Icons.calendar_month),
                  label: Text(uiText(context, 'Concertar una visita')),
                ),
              ],
            ),
          if (loading) const Center(child: CircularProgressIndicator()),
          if (failed)
            Text(
              uiText(
                context,
                'No se pudo cargar. Comprueba tu acceso y actualiza.',
              ),
            ),
          Text(
            uiText(
              context,
              'Se muestran las últimas 100 propuestas. Los recordatorios de visitas confirmadas requieren permitir las notificaciones.',
            ),
          ),
          for (final item in items)
            Builder(
              builder: (context) {
                final mine = item['creator_id'] == db.auth.currentUser?.id;
                final status = (item['display_status'] ?? item['status'])
                    .toString();
                final visit = item['kind'] == 'visit';
                final date = DateTime.tryParse(
                  item['scheduled_at']?.toString() ?? '',
                )?.toLocal();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uiText(
                            context,
                            visit ? 'Visita al vehículo' : 'Oferta de compra',
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          visit
                              ? (date == null
                                    ? ''
                                    : '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}')
                              : '${item['amount']} €',
                        ),
                        if (visit)
                          Text(item['meeting_place']?.toString() ?? ''),
                        Text(uiText(context, marketActivityStatus(status))),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (status == 'pending' && !mine) ...[
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => change('accept', item),
                                child: Text(uiText(context, 'Aceptar')),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => change('reject', item),
                                child: Text(uiText(context, 'Rechazar')),
                              ),
                            ],
                            if ((status == 'pending' || status == 'accepted') &&
                                (mine || visit))
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => change('cancel', item),
                                child: Text(
                                  uiText(context, 'Cancelar propuesta'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

class MarketProposalDialog extends StatefulWidget {
  const MarketProposalDialog({super.key, required this.kind});
  final String kind;
  @override
  State<MarketProposalDialog> createState() => _MarketProposalDialogState();
}

class _MarketProposalDialogState extends State<MarketProposalDialog> {
  final field = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.kind == 'offer';
    return AlertDialog(
      title: Text(
        uiText(context, offer ? 'Proponer un importe' : 'Proponer una visita'),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                uiText(
                  context,
                  offer
                      ? 'Importe en euros, sin separadores de miles. Ejemplo: 12000,00.'
                      : 'Indica un lugar público de encuentro. Evita incluir tu domicilio.',
                ),
              ),
              TextFormField(
                controller: field,
                maxLength: offer ? 12 : 120,
                keyboardType: offer
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: uiText(
                    context,
                    offer ? 'Importe (€)' : 'Lugar de encuentro',
                  ),
                ),
                validator: (value) => offer
                    ? (parseMarketOffer(value ?? '') == null
                          ? uiText(context, 'Introduce un importe válido.')
                          : null)
                    : ((value ?? '').trim().length < 3
                          ? uiText(context, 'Indica un lugar de encuentro.')
                          : null),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(uiText(context, 'Volver')),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate())
              Navigator.pop(context, field.text.trim());
          },
          child: Text(uiText(context, 'Enviar propuesta')),
        ),
      ],
    );
  }
}
