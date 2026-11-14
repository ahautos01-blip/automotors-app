import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_market_page.dart';
import 'l10n/ui_text.dart';
import 'services/app_diagnostics.dart';

/// Reads authoritative proposals; ordinary message text never controls an offer.
class ChatOfferPanel extends StatefulWidget {
  const ChatOfferPanel({
    super.key,
    required this.conversationId,
    required this.enabled,
  });
  final String conversationId;
  final bool enabled;
  @override
  State<ChatOfferPanel> createState() => _ChatOfferPanelState();
}

class _ChatOfferPanelState extends State<ChatOfferPanel>
    with WidgetsBindingObserver {
  final db = Supabase.instance.client;
  Map<String, dynamic>? offer;
  Timer? timer;
  bool busy = false, loading = false, failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
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

  @override
  void didUpdateWidget(covariant ChatOfferPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      offer = null;
      load();
    }
  }

  Future<dynamic> request(String action, {String? id}) => db.rpc(
    'chat_market_action',
    params: {
      'p_conversation': widget.conversationId,
      'p_action': action,
      'p_id': id,
    },
  );
  Future<void> load() async {
    if (!widget.enabled || loading) return;
    loading = true;
    final user = db.auth.currentUser?.id;
    try {
      final rows = List<Map<String, dynamic>>.from(
        await request('list') as List,
      ).where((r) => r['kind'] == 'offer').toList();
      final pending = rows.where(
        (r) => (r['display_status'] ?? r['status']) == 'pending',
      );
      if (mounted && user == db.auth.currentUser?.id)
        setState(() {
          offer = pending.isNotEmpty ? pending.first : rows.firstOrNull;
          failed = false;
        });
    } catch (error) {
      AppDiagnostics.record('chat', error);
      if (mounted)
        setState(() {
          offer = null;
          failed = true;
        });
    } finally {
      loading = false;
    }
  }

  Future<void> respond(String action) async {
    final proposal = offer;
    if (proposal == null || busy || !widget.enabled) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiText(context, 'Confirmar cambio')),
        content: Text(
          uiText(
            context,
            'La respuesta quedará visible para la otra persona. No se realizará ningún pago ni reserva.',
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
    if (confirmed != true || !mounted || !widget.enabled) return;
    setState(() => busy = true);
    try {
      await request(action, id: proposal['id'].toString());
      await load();
    } catch (error) {
      AppDiagnostics.record('chat', error);
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
      await load();
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
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.viewInsetsOf(context).bottom > 0)
      return const SizedBox.shrink();
    final item = offer;
    if (failed)
      return TextButton.icon(
        onPressed: loading ? null : load,
        icon: const Icon(Icons.refresh),
        label: Text(uiText(context, 'Ofertas y citas')),
      );
    if (item == null) return const SizedBox.shrink();
    final status = (item['display_status'] ?? item['status']).toString();
    final incoming = item['creator_id'] != db.auth.currentUser?.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: SingleChildScrollView(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${uiText(context, 'Oferta de compra')} · ${item['amount']} €',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(uiText(context, marketActivityStatus(status))),
                  if (incoming && status == 'pending')
                    Wrap(
                      spacing: 10,
                      children: [
                        FilledButton(
                          onPressed: busy ? null : () => respond('accept'),
                          child: Text(uiText(context, 'Aceptar')),
                        ),
                        OutlinedButton(
                          onPressed: busy ? null : () => respond('reject'),
                          child: Text(uiText(context, 'Rechazar')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
