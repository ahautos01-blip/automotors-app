import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/ui_text.dart';
import '../services/market_activity.dart';
import 'market_theme.dart';

class MarketActivityPage extends StatefulWidget {
  const MarketActivityPage({
    super.key,
    required this.openChat,
    required this.openInbox,
    this.service,
  });
  final Future<void> Function(String conversation) openChat;
  final Future<void> Function() openInbox;
  final MarketActivityService? service;
  @override
  State<MarketActivityPage> createState() => _MarketActivityPageState();
}

class _MarketActivityPageState extends State<MarketActivityPage>
    with WidgetsBindingObserver {
  late final service =
      widget.service ?? MarketActivityService(Supabase.instance.client);
  late Future<Map<String, dynamic>> data;
  StreamSubscription<AuthState>? auth;
  String? viewer;
  Timer? clock;
  Future<Map<String, dynamic>> loadForView() {
    final future = service.load();
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    return future;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clock = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
    data = loadForView();
    viewer = service.client.auth.currentUser?.id;
    auth = service.client.auth.onAuthStateChange.listen((event) {
      if (event.session?.user.id != viewer) {
        viewer = event.session?.user.id;
        refresh();
      }
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    auth?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  void refresh() {
    if (mounted)
      setState(() {
        data = loadForView();
      });
  }

  Future<void> open(String? id) async {
    if (service.client.auth.currentUser?.id != viewer) {
      refresh();
      return;
    }
    try {
      if (id == null) {
        await widget.openInbox();
      } else {
        await widget.openChat(id);
      }
      refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uiText(context, 'No se pudo cargar tu actividad.')),
          ),
        );
    }
  }

  String date(dynamic value) {
    final at = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (at == null) return '';
    final l = MaterialLocalizations.of(context);
    return '${l.formatShortDate(at)} · ${l.formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(uiText(context, 'Mi actividad')),
      actions: [
        IconButton(
          onPressed: refresh,
          tooltip: uiText(context, 'Actualizar'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(uiText(context, 'No se pudo cargar tu actividad.')),
                  TextButton(
                    onPressed: refresh,
                    child: Text(uiText(context, 'Reintentar')),
                  ),
                ],
              ),
            ),
          );
        final result = snapshot.data ?? {};
        final offers = List<Map<String, dynamic>>.from(result['offers'] ?? []);
        final visits = List<Map<String, dynamic>>.from(result['visits'] ?? []);
        return RefreshIndicator(
          onRefresh: () async {
            refresh();
            try {
              await data;
            } catch (_) {
              /* Error is rendered by FutureBuilder. */
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(
                    Icons.mark_chat_unread_outlined,
                    color: marketAccent,
                  ),
                  title: Text(uiText(context, 'Conversaciones sin leer')),
                  subtitle: Text(
                    '${result['unread_conversations'] ?? 0}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(null),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                uiText(context, 'Ofertas por responder'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (offers.isEmpty)
                Text(
                  uiText(context, 'No tienes ofertas pendientes de respuesta.'),
                ),
              for (final item in offers) activityCard(item, visit: false),
              const SizedBox(height: 24),
              Text(
                uiText(context, 'Próximas citas confirmadas'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (visits.isEmpty)
                Text(
                  uiText(
                    context,
                    'No tienes citas confirmadas para los próximos 30 días.',
                  ),
                ),
              for (final item in visits) activityCard(item, visit: true),
              const SizedBox(height: 18),
              Text(
                uiText(
                  context,
                  'Las ofertas caducadas y las conversaciones bloqueadas no aparecen aquí. Abre el chat para responder o gestionar la cita.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    ),
  );
  Widget activityCard(Map<String, dynamic> item, {required bool visit}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(
              visit ? Icons.event_outlined : Icons.local_offer_outlined,
              color: marketAccent,
            ),
            title: Text(
              uiText(
                context,
                visit
                    ? 'Cita confirmada'
                    : item['role'] == 'seller'
                    ? 'Oferta de un comprador'
                    : 'Contraoferta del vendedor',
              ),
            ),
            subtitle: Text(
              visit
                  ? date(item['scheduled_at'])
                  : uiText(context, 'Válida hasta {0}', [
                      date(item['expires_at']),
                    ]),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(item['conversation_id'].toString()),
          ),
        ),
      );
}
