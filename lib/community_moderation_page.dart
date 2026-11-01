import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_safety_controls.dart';
import 'l10n/ui_text.dart';
import 'services/community_moderation_service.dart';

const moderationActionLabels = <String, String>{
  'reviewing': 'Marcar en revisión',
  'resolve': 'Marcar como atendida',
  'dismiss': 'Descartar denuncia',
  'hide_listing': 'Ocultar anuncio',
  'restore_listing': 'Restaurar anuncio',
  'restrict_chat': 'Restringir chat del usuario',
  'restore_chat': 'Retirar restricción del chat',
};
String _reportReason(BuildContext context, String source) =>
    uiText(context, chatReportReasons[source] ?? source);
String _reportStatus(BuildContext context, String source) =>
    uiText(context, switch (source) {
      'pending' => 'Pendiente',
      'reviewing' => 'En revisión',
      'resolved' => 'Atendida',
      'dismissed' => 'Descartada',
      _ => source,
    });
String _date(String source) {
  final value = DateTime.tryParse(source)?.toLocal();
  return value == null
      ? ''
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class ModerationEntry extends StatefulWidget {
  const ModerationEntry({super.key, this.service});
  final CommunityModerationService? service;
  @override
  State<ModerationEntry> createState() => _ModerationEntryState();
}

class _ModerationEntryState extends State<ModerationEntry> {
  late final service = widget.service ?? CommunityModerationService();
  late final access = service.hasAccess();
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: access,
    builder: (context, snapshot) {
      if (snapshot.data != true) return const SizedBox.shrink();
      return ListTile(
        leading: const Icon(Icons.shield_outlined),
        title: Text(uiText(context, 'Moderación')),
        subtitle: Text(
          uiText(context, 'Revisar denuncias de anuncios y conversaciones'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityModerationPage(service: service),
          ),
        ),
      );
    },
  );
}

class CommunityModerationPage extends StatefulWidget {
  const CommunityModerationPage({super.key, this.service});
  final CommunityModerationService? service;
  @override
  State<CommunityModerationPage> createState() =>
      _CommunityModerationPageState();
}

class _CommunityModerationPageState extends State<CommunityModerationPage> {
  late final service = widget.service ?? CommunityModerationService();
  final items = <Map<String, dynamic>>[];
  bool loading = false, failed = false, hasMore = true, includeClosed = false;
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      failed = false;
      if (reset) {
        items.clear();
        hasMore = true;
      }
    });
    try {
      final page = await service.reports(
        before: items.isEmpty ? null : items.last,
        includeClosed: includeClosed,
      );
      if (!mounted) return;
      setState(() {
        final known = items.map((row) => '${row['kind']}/${row['id']}').toSet();
        items.addAll(
          page.where((row) => known.add('${row['kind']}/${row['id']}')),
        );
        hasMore = page.length == 50;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openReport(Map<String, dynamic> item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityReportPage(
          kind: item['kind'] as String,
          reportId: item['id'] as String,
          service: service,
        ),
      ),
    );
    if (mounted) await load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(uiText(context, 'Moderación')),
      actions: [
        IconButton(
          tooltip: uiText(context, 'Actualizar denuncias'),
          onPressed: loading ? null : () => load(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          uiText(
            context,
            'Revisa las denuncias con frecuencia y atiende los casos de abuso con rapidez. Las acciones quedan registradas.',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(uiText(context, 'Mostrar también denuncias cerradas')),
          value: includeClosed,
          onChanged: loading
              ? null
              : (value) {
                  setState(() => includeClosed = value);
                  load(reset: true);
                },
        ),
        for (final item in items)
          Card(
            child: ListTile(
              leading: Icon(
                item['kind'] == 'chat'
                    ? Icons.chat_outlined
                    : Icons.directions_car_outlined,
              ),
              title: Text(_reportReason(context, item['reason'] as String)),
              subtitle: Text(
                '${uiText(context, item['kind'] == 'chat' ? 'Conversación' : 'Anuncio')} · ${_reportStatus(context, item['status'] as String)}\n${_date(item['created_at'] as String)}',
                maxLines: 3,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openReport(item),
            ),
          ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!loading && !failed && items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(uiText(context, 'No hay denuncias para mostrar.')),
          ),
        if (failed) ...[
          Text(
            uiText(
              context,
              'No se pudieron cargar las denuncias. Comprueba tu acceso y reinténtalo.',
            ),
          ),
          TextButton(
            onPressed: () => load(reset: items.isEmpty),
            child: Text(uiText(context, 'Reintentar')),
          ),
        ],
        if (!loading && !failed && items.isNotEmpty && hasMore)
          TextButton(
            onPressed: load,
            child: Text(uiText(context, 'Cargar más denuncias')),
          ),
      ],
    ),
  );
}

class CommunityReportPage extends StatefulWidget {
  const CommunityReportPage({
    super.key,
    required this.kind,
    required this.reportId,
    required this.service,
  });
  final String kind, reportId;
  final CommunityModerationService service;
  @override
  State<CommunityReportPage> createState() => _CommunityReportPageState();
}

class _CommunityReportPageState extends State<CommunityReportPage> {
  Map<String, dynamic>? detail;
  bool busy = false,
      loading = false,
      failed = false,
      loadingMessages = false,
      hasOlderMessages = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final result = await widget.service.detail(widget.kind, widget.reportId);
      if (mounted) {
        setState(() {
          detail = result;
          hasOlderMessages = (result['messages'] as List? ?? []).length == 50;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadOlderMessages() async {
    if (loadingMessages || detail == null) return;
    final current = List<Map<String, dynamic>>.from(
      detail!['messages'] as List,
    );
    if (current.isEmpty) return;
    setState(() => loadingMessages = true);
    try {
      final earlier = await widget.service.messages(
        widget.reportId,
        current.first['id'].toString(),
      );
      if (!mounted) return;
      setState(() {
        detail!['messages'] = [...earlier, ...current];
        hasOlderMessages = earlier.length == 50;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                'No se pudieron cargar más mensajes. Reinténtalo.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loadingMessages = false);
    }
  }

  Future<void> review(String action) async {
    if (busy) return;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => ModerationActionDialog(action: action),
    );
    if (note == null || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await widget.service.review(
        widget.kind,
        widget.reportId,
        action,
        note,
      );
      if (!mounted) return;
      setState(() {
        detail = result;
        hasOlderMessages = (result['messages'] as List? ?? []).length == 50;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, 'Acción de moderación guardada.')),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(context, 'No se pudo guardar la acción. Reinténtalo.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget photo(String path) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Image.network(
      Supabase.instance.client.storage
          .from('vehicle-photos')
          .getPublicUrl(path),
      height: 220,
      width: double.infinity,
      fit: BoxFit.contain,
      cacheWidth: 900,
      errorBuilder: (context, error, stack) =>
          Text(uiText(context, 'No se pudo cargar esta fotografía.')),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final data = detail;
    return Scaffold(
      appBar: AppBar(title: Text(uiText(context, 'Revisar denuncia'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : failed || data == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(uiText(context, 'No se pudo abrir la denuncia.')),
                  TextButton(
                    onPressed: load,
                    child: Text(uiText(context, 'Reintentar')),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _reportReason(context, data['reason'] as String),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(_reportStatus(context, data['status'] as String)),
                if ((data['details'] as String? ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SelectableText(data['details'] as String),
                  ),
                if (data['listing'] is Map) ...[
                  const Divider(),
                  Text(
                    uiText(context, 'Anuncio'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SelectableText(
                    '${data['listing']['year']} · ${data['listing']['version'] ?? ''} · ${data['listing']['price']} €',
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    data['listing']['description'] as String? ?? '',
                  ),
                  const SizedBox(height: 12),
                  for (final path in data['photos'] as List? ?? [])
                    photo(path as String),
                ],
                if (data['messages'] is List) ...[
                  const Divider(),
                  Text(
                    uiText(context, 'Mensajes de la conversación denunciada'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (hasOlderMessages)
                    TextButton(
                      onPressed: loadingMessages ? null : loadOlderMessages,
                      child: Text(
                        uiText(context, 'Cargar mensajes anteriores'),
                      ),
                    ),
                  if (loadingMessages)
                    const Center(child: CircularProgressIndicator()),
                  for (final message in data['messages'] as List)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${uiText(context, message['sender_role'] == 'reporter' ? 'Denunciante' : 'Usuario denunciado')} · ${_date(message['created_at'] as String)}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 6),
                            SelectableText(message['body'] as String),
                          ],
                        ),
                      ),
                    ),
                ],
                const Divider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.kind == 'listing')
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => review(
                                data['listing_held'] == true
                                    ? 'restore_listing'
                                    : 'hide_listing',
                              ),
                        child: Text(
                          uiText(
                            context,
                            moderationActionLabels[data['listing_held'] == true
                                ? 'restore_listing'
                                : 'hide_listing']!,
                          ),
                        ),
                      ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => review(
                              data['chat_restricted'] == true
                                  ? 'restore_chat'
                                  : 'restrict_chat',
                            ),
                      child: Text(
                        uiText(
                          context,
                          moderationActionLabels[data['chat_restricted'] == true
                              ? 'restore_chat'
                              : 'restrict_chat']!,
                        ),
                      ),
                    ),
                    for (final action in ['reviewing', 'resolve', 'dismiss'])
                      OutlinedButton(
                        onPressed: busy ? null : () => review(action),
                        child: Text(
                          uiText(context, moderationActionLabels[action]!),
                        ),
                      ),
                  ],
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if ((data['history'] as List? ?? []).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    uiText(context, 'Historial de moderación'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final entry in data['history'] as List)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        uiText(
                          context,
                          moderationActionLabels[entry['action']] ??
                              entry['action'] as String,
                        ),
                      ),
                      subtitle: Text(
                        '${_date(entry['created_at'] as String)}\n${entry['note'] ?? ''}',
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class ModerationActionDialog extends StatefulWidget {
  const ModerationActionDialog({super.key, required this.action});
  final String action;
  @override
  State<ModerationActionDialog> createState() => _ModerationActionDialogState();
}

class _ModerationActionDialogState extends State<ModerationActionDialog> {
  final note = TextEditingController();
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(uiText(context, moderationActionLabels[widget.action]!)),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            uiText(context, switch (widget.action) {
              'hide_listing' => 'El anuncio quedará oculto a otros usuarios. El vendedor podrá verlo, pero no editarlo mientras esté restringido.',
              'restore_listing' => 'El anuncio volverá a mostrarse según su estado de publicación.',
              'restrict_chat' => 'El usuario denunciado no podrá enviar ni recibir nuevos mensajes. Podrás retirar esta restricción después.',
              'restore_chat' => 'Se retirará la restricción de moderación. Los bloqueos personales seguirán aplicándose.',
              'reviewing' => 'La denuncia seguirá abierta para revisión.',
              'dismiss' => 'La denuncia se cerrará como descartada. Las restricciones existentes se mantienen hasta que las retires.',
              _ => 'La denuncia se marcará como atendida. Las restricciones existentes se mantienen hasta que las retires.',
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: note,
            maxLength: 1000,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: uiText(context, 'Nota de moderación (opcional)'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(uiText(context, 'Cancelar')),
      ),
      FilledButton(
        key: const Key('confirm-moderation-action'),
        onPressed: () => Navigator.pop(context, note.text.trim()),
        child: Text(uiText(context, 'Confirmar')),
      ),
    ],
  );
}
