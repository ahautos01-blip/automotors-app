import 'package:flutter/material.dart';

import 'l10n/ui_text.dart';
import 'services/chat_safety_controller.dart';
import 'support_page.dart';

const chatReportReasons = <String, String>{
  'fraud': 'Posible fraude',
  'harassment': 'Acoso o amenazas',
  'inappropriate': 'Contenido inapropiado',
  'spam': 'Spam',
  'other': 'Otro',
};

class ChatReportDraft {
  const ChatReportDraft(this.reason, this.details);
  final String reason, details;
}

class ChatReportDialog extends StatefulWidget {
  const ChatReportDialog({super.key});
  @override
  State<ChatReportDialog> createState() => _ChatReportDialogState();
}

class _ChatReportDialogState extends State<ChatReportDialog> {
  final form = GlobalKey<FormState>();
  final details = TextEditingController();
  String? reason;
  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(uiText(context, 'Denunciar conversación')),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              uiText(
                context,
                'El equipo de moderación podrá revisar esta conversación para atender tu denuncia.',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(labelText: uiText(context, 'Motivo')),
              items: chatReportReasons.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(uiText(context, e.value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => reason = value,
              validator: (value) => value == null
                  ? uiText(context, 'Selecciona un motivo')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: details,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: uiText(context, 'Detalles (opcional)'),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(uiText(context, 'Cancelar')),
      ),
      FilledButton(
        key: const Key('send-chat-report'),
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              ChatReportDraft(reason!, details.text.trim()),
            );
          }
        },
        child: Text(uiText(context, 'Enviar denuncia')),
      ),
    ],
  );
}

class ChatSafetyControls extends StatelessWidget {
  const ChatSafetyControls({super.key, required this.controller});
  final ChatSafetyController controller;
  Future<void> _select(BuildContext context, String action) async {
    if (action == 'refresh') {
      await controller.load();
      return;
    }
    bool ok;
    String success;
    if (action == 'report') {
      final draft = await showDialog<ChatReportDraft>(
        context: context,
        builder: (_) => const ChatReportDialog(),
      );
      if (draft == null || !context.mounted) return;
      ok = await controller.report(draft.reason, draft.details);
      success = controller.lastReportCreated
          ? 'Gracias. Tu denuncia se ha enviado a moderación.'
          : 'Ya hay una denuncia tuya pendiente de revisión para esta conversación.';
    } else {
      final blocking = action == 'block';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(
            uiText(
              context,
              blocking ? 'Bloquear usuario' : 'Desbloquear usuario',
            ),
          ),
          content: Text(
            uiText(
              context,
              blocking
                  ? 'No podréis enviaros mensajes. Sus anuncios se ocultarán de tu catálogo y se registrará un aviso para moderación. Conservarás el historial y podrás desbloquearlo después.'
                  : 'Se retirará tu bloqueo. El chat solo se habilitará si no existe otro bloqueo o restricción de moderación.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(uiText(context, 'Cancelar')),
            ),
            FilledButton(
              key: const Key('confirm-chat-block'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(
                uiText(
                  context,
                  blocking ? 'Bloquear usuario' : 'Desbloquear usuario',
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      ok = await controller.setBlocked(blocking);
      success = blocking
          ? 'Has bloqueado a este usuario.'
          : 'Has retirado tu bloqueo.';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uiText(
            context,
            ok
                ? success
                : 'No se pudo actualizar la seguridad del chat. Reinténtalo.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopupMenuButton<String>(
      tooltip: uiText(context, 'Seguridad del chat'),
      onSelected: (action) => _select(context, action),
      itemBuilder: (_) => [
        if (controller.loaded && !controller.failed)
          PopupMenuItem(
            value: controller.blockedByMe ? 'unblock' : 'block',
            enabled: !controller.busy,
            child: Text(
              uiText(
                context,
                controller.blockedByMe
                    ? 'Desbloquear usuario'
                    : 'Bloquear usuario',
              ),
            ),
          ),
        PopupMenuItem(
          value: 'report',
          enabled: controller.loaded && !controller.busy,
          child: Text(uiText(context, 'Denunciar conversación')),
        ),
        PopupMenuItem(
          value: 'refresh',
          enabled: !controller.busy,
          child: Text(uiText(context, 'Actualizar acceso al chat')),
        ),
      ],
    ),
  );
}

class ChatSafetyBanner extends StatelessWidget {
  const ChatSafetyBanner({super.key, required this.controller});
  final ChatSafetyController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.canMessage) return const SizedBox.shrink();
      final message = controller.failed
          ? 'No se pudo comprobar el acceso al chat. Reinténtalo.'
          : controller.busy
          ? 'Comprobando acceso al chat…'
          : controller.blockedByMe
          ? 'Has bloqueado a este usuario. Puedes desbloquearlo desde el menú del chat.'
          : 'No se pueden enviar mensajes en esta conversación por un bloqueo o una restricción de moderación.';
      return Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(uiText(context, message)),
            if (controller.failed)
              TextButton(
                onPressed: controller.load,
                child: Text(uiText(context, 'Reintentar')),
              ),
            if (controller.loaded && !controller.busy && !controller.failed)
              TextButton(
                onPressed: () => openAutomotorsSupport(context),
                child: Text(uiText(context, 'Ayuda y privacidad')),
              ),
          ],
        ),
      );
    },
  );
}
