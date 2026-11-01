import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/ui_text.dart';
import 'support_page.dart';

Future<void> deleteCurrentAutomotorsAccount() async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) {
    throw StateError('Authentication required');
  }
  final response = await client.functions.invoke(
    'delete-account',
    body: {'confirmation': 'DELETE'},
  );
  if (response.status != 200 ||
      response.data is! Map ||
      response.data['deleted'] != true) {
    throw StateError('Deletion incomplete');
  }
  // Auth deletion revokes server sessions; remove this device's cached session too.
  try {
    await client.auth.signOut(scope: SignOutScope.local);
  } catch (_) {
    // The SDK clears local auth before contacting the now-deleted server session.
    // A logout network failure must not report that confirmed deletion failed.
    if (client.auth.currentSession != null) rethrow;
  }
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, this.deleteAccount});
  final Future<void> Function()? deleteAccount;
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool acknowledged = false;
  bool busy = false;
  bool failed = false;

  Future<void> confirmDeletion() async {
    if (busy || !acknowledged) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(uiText(context, 'Eliminar mi cuenta')),
        content: Text(
          uiText(
            context,
            '¿Quieres eliminar definitivamente tu cuenta y sus datos?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(uiText(context, 'Cancelar')),
          ),
          FilledButton(
            key: const Key('confirm-account-deletion'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(uiText(context, 'Eliminar definitivamente')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await (widget.deleteAccount ?? deleteCurrentAutomotorsAccount)();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final message = uiText(context, 'Tu cuenta se ha eliminado.');
      // Release PopScope before navigating after a confirmed deletion.
      setState(() => busy = false);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(uiText(context, 'Eliminar mi cuenta'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            uiText(
              context,
              'Se eliminarán tu cuenta, perfil, anuncios, fotografías, documentos, favoritos, búsquedas, conversaciones y reseñas asociadas. Esta acción es irreversible.',
            ),
          ),
          const SizedBox(height: 18),
          Text(
            uiText(
              context,
              'Eliminar la app o la cuenta de AUTOMOTORS no cancela una suscripción de Apple. Gestiona su renovación desde tu cuenta de Apple.',
            ),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => openSupportUri(context, appleSubscriptionsUri),
            child: Text(uiText(context, 'Gestionar suscripciones de Apple')),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: acknowledged,
            onChanged: busy
                ? null
                : (value) => setState(() => acknowledged = value ?? false),
            title: Text(
              uiText(
                context,
                'Entiendo que eliminar mi cuenta no cancela mis suscripciones de Apple.',
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('request-account-deletion'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: acknowledged && !busy ? confirmDeletion : null,
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever),
            label: Text(uiText(context, 'Eliminar definitivamente')),
          ),
          if (failed) ...[
            const SizedBox(height: 16),
            Text(
              uiText(
                context,
                'No se ha podido completar la eliminación. Reinténtalo. Si el proceso ya ha empezado, el acceso a tus datos queda suspendido hasta completarlo. Contacta con soporte si necesitas ayuda.',
              ),
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SelectableText(automotorsSupportEmail),
            const SupportLinks(),
          ],
        ],
      ),
    ),
  );
}
