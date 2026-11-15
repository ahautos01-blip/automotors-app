import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design/market_theme.dart';
import 'l10n/ui_text.dart';
import 'services/chat_inbox_service.dart';

Future<bool> confirmPersonalChatDeletion(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(uiText(context, 'Eliminar conversación')),
        content: Text(
          uiText(
            context,
            'Se quitará solo de tu lista. La otra persona conservará su conversación. Podrás recuperarla en «Eliminadas»; si llega un mensaje nuevo, volverá a aparecer. Esto no bloquea al usuario.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(uiText(context, 'Cancelar')),
          ),
          FilledButton(
            key: const Key('confirm-personal-chat-delete'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(uiText(context, 'Eliminar de mi lista')),
          ),
        ],
      ),
    ) ??
    false;

class ChatInboxPage extends StatefulWidget {
  final Future<Uint8List> Function(String) loadPhoto;
  final Future<void> Function(BuildContext, Map<String, dynamic>) openChat;
  final ChatInboxService? service;
  const ChatInboxPage({
    super.key,
    required this.loadPhoto,
    required this.openChat,
    this.service,
  });
  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage>
    with WidgetsBindingObserver {
  late final service =
      widget.service ?? ChatInboxService(Supabase.instance.client);
  late Future<List<Map<String, dynamic>>> future;
  final search = TextEditingController();
  StreamSubscription<AuthState>? auth;
  RealtimeChannel? channel;
  String? viewer;
  bool deleted = false, busy = false;
  Timer? refreshTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    viewer = service.client.auth.currentUser?.id;
    future = service.load(widget.loadPhoto);
    auth = service.client.auth.onAuthStateChange.listen((event) {
      if (event.session?.user.id != viewer && mounted) {
        viewer = event.session?.user.id;
        search.clear();
        setState(() {
          future = service.load(widget.loadPhoto);
        });
      }
    });
    channel = service.watch(() {
      refreshTimer?.cancel();
      refreshTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) unawaited(refresh().catchError((Object _) {}));
      });
    });
  }

  Future<void> refresh() async {
    if (!mounted) return;
    final next = service.load(widget.loadPhoto);
    setState(() {
      future = next;
    });
    await next;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      unawaited(refresh().catchError((Object _) {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    auth?.cancel();
    channel?.unsubscribe();
    search.dispose();
    super.dispose();
  }

  Future<void> act(Map<String, dynamic> row, String action) async {
    if (busy) return;
    if (action == 'hide' && !await confirmPersonalChatDeletion(context)) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await service.action(row['id'].toString(), action);
      if (!mounted) return;
      await refresh();
      if (!mounted) return;
      final text = switch (action) {
        'hide' => 'Conversación eliminada de tu lista.',
        'restore' => 'Conversación recuperada.',
        'pin' => 'Conversación fijada.',
        _ => 'Conversación desfijada.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, text)),
          action: action == 'hide'
              ? SnackBarAction(
                  label: uiText(context, 'Deshacer'),
                  onPressed: () => act(row, 'restore'),
                )
              : null,
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                'No se pudo actualizar la conversación. Vuelve a intentarlo.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String timeLabel(Map<String, dynamic> row) {
    final date = DateTime.tryParse(
      row['last_message_at']?.toString() ?? row['updated_at']?.toString() ?? '',
    )?.toLocal();
    if (date == null) return '';
    final l = MaterialLocalizations.of(context), now = DateTime.now();
    final time = l.formatTimeOfDay(TimeOfDay.fromDateTime(date));
    return DateUtils.isSameDay(date, now)
        ? time
        : '${l.formatShortDate(date)} · $time';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        uiText(context, deleted ? 'Conversaciones eliminadas' : 'Mis mensajes'),
      ),
      actions: [
        IconButton(
          tooltip: uiText(
            context,
            deleted ? 'Volver a mis mensajes' : 'Ver eliminadas',
          ),
          icon: Icon(deleted ? Icons.forum_outlined : Icons.delete_outline),
          onPressed: () => setState(() => deleted = !deleted),
        ),
        IconButton(
          tooltip: uiText(context, 'Actualizar mensajes'),
          icon: const Icon(Icons.refresh),
          onPressed: busy
              ? null
              : () => unawaited(refresh().catchError((Object _) {})),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: uiText(context, 'Buscar vehículo o persona'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: uiText(context, 'Borrar búsqueda'),
                      onPressed: () {
                        search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (deleted)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              uiText(
                context,
                'Solo están fuera de tu lista. Puedes recuperarlas; los mensajes nuevos vuelven a mostrarlas.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
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
                        Text(
                          uiText(
                            context,
                            'No se pudieron cargar tus conversaciones. Actualiza para reintentar.',
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              unawaited(refresh().catchError((Object _) {})),
                          child: Text(uiText(context, 'Reintentar')),
                        ),
                      ],
                    ),
                  ),
                );
              final rows = filterChatInbox(
                snapshot.data ?? [],
                deleted: deleted,
                query: search.text,
              );
              if (rows.isEmpty)
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      uiText(
                        context,
                        search.text.trim().isNotEmpty
                            ? 'No hay conversaciones que coincidan con tu búsqueda.'
                            : deleted
                            ? 'No tienes conversaciones eliminadas.'
                            : 'Todavía no tienes conversaciones',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              return RefreshIndicator(
                onRefresh: () => refresh().catchError((Object _) {}),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = rows[index], photo = row['vehicle_photo'];
                    final title =
                        row['vehicle_title']?.toString() ??
                        uiText(context, 'Vehículo anunciado');
                    final name =
                        row['participant_name']?.toString() ??
                        uiText(context, 'Usuario');
                    final unread = (row['unread_count'] as num?)?.toInt() ?? 0;
                    final preview =
                        row['last_message']
                            ?.toString()
                            .replaceAll(RegExp(r'\s+'), ' ')
                            .trim() ??
                        '';
                    return Card(
                      key: Key('chat-inbox-${row["id"]}'),
                      color: marketSurface,
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: marketLine),
                      ),
                      child: InkWell(
                        onTap: busy
                            ? null
                            : () async {
                                await widget.openChat(context, row);
                                if (mounted) await refresh();
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: SizedBox(
                                  width: 62,
                                  height: 68,
                                  child: photo is Uint8List
                                      ? Image.memory(
                                          photo,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.directions_car_outlined,
                                                color: marketAccent,
                                              ),
                                        )
                                      : const Icon(
                                          Icons.directions_car_outlined,
                                          color: marketAccent,
                                          size: 32,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (row['pinned'] == true) ...[
                                          Icon(
                                            Icons.push_pin,
                                            size: 15,
                                            color: marketAccent,
                                            semanticLabel: uiText(
                                              context,
                                              'Conversación fijada',
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: marketAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      preview.isEmpty
                                          ? uiText(
                                              context,
                                              'Sin mensajes todavía',
                                            )
                                          : row['last_message_by_me'] == true
                                          ? '${uiText(context, 'Tú')}: $preview'
                                          : preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: marketMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      timeLabel(row),
                                      style: const TextStyle(
                                        color: marketMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  PopupMenuButton<String>(
                                    key: Key('chat-inbox-menu-${row["id"]}'),
                                    tooltip: uiText(
                                      context,
                                      'Opciones de conversación',
                                    ),
                                    enabled: !busy,
                                    onSelected: (action) => act(row, action),
                                    itemBuilder: (_) => [
                                      if (!deleted)
                                        PopupMenuItem(
                                          value: row['pinned'] == true
                                              ? 'unpin'
                                              : 'pin',
                                          child: Text(
                                            uiText(
                                              context,
                                              row['pinned'] == true
                                                  ? 'Desfijar conversación'
                                                  : 'Fijar conversación',
                                            ),
                                          ),
                                        ),
                                      PopupMenuItem(
                                        value: deleted ? 'restore' : 'hide',
                                        child: Text(
                                          uiText(
                                            context,
                                            deleted
                                                ? 'Recuperar conversación'
                                                : 'Eliminar conversación',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!deleted && unread > 0)
                                    Badge(label: Text('$unread')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
