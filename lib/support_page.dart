import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/ui_text.dart';

const automotorsSupportEmail = 'info@automotors.info';
const automotorsLegalOwner = 'Abdelmounim Taghi';
const automotorsLegalAddress = 'Carrer Pablo Iglesias 56, 08302 Mataró, España';
const automotorsContactPhone = '937212845';
final appleSubscriptionsUri = Uri.parse(
  'https://apps.apple.com/account/subscriptions',
);
final appleTermsUri = Uri.parse(
  'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
);

Future<void> openSupportUri(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // The address stays available to copy when the device has no mail app.
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        uiText(
          context,
          'No se pudo abrir el enlace. Puedes contactar con {0}.',
          [automotorsSupportEmail],
        ),
      ),
    ),
  );
}

void openAutomotorsSupport(BuildContext context, {String? section}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => AutomotorsSupportPage(initialSection: section),
    ),
  );
}

class SupportLinks extends StatelessWidget {
  const SupportLinks({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: () => openAutomotorsSupport(context),
        child: Text(uiText(context, 'Ayuda y privacidad')),
      ),
      TextButton(
        onPressed: () => openAutomotorsSupport(context, section: 'privacy'),
        child: Text(uiText(context, 'Política de privacidad')),
      ),
      TextButton(
        onPressed: () => openAutomotorsSupport(context, section: 'terms'),
        child: Text(uiText(context, 'Condiciones de uso')),
      ),
    ],
  );
}

class SubscriptionDisclosure extends StatelessWidget {
  const SubscriptionDisclosure({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        uiText(
          context,
          "El precio y el período de cada suscripción se obtienen de Apple. El pago se carga a tu cuenta de Apple al confirmar. La suscripción se renueva automáticamente salvo que la canceles al menos 24 horas antes de terminar el período actual. Apple puede cobrar la renovación durante las 24 horas anteriores a su finalización. Puedes gestionar o cancelar la renovación en las suscripciones de tu cuenta de Apple.",
        ),
        style: const TextStyle(fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => openSupportUri(context, appleSubscriptionsUri),
        child: Text(uiText(context, 'Gestionar suscripciones de Apple')),
      ),
      const SupportLinks(),
    ],
  );
}

class AutomotorsSupportPage extends StatelessWidget {
  const AutomotorsSupportPage({super.key, this.initialSection});
  final String? initialSection;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(uiText(context, 'Ayuda y privacidad'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          uiText(context, 'Responsable y contacto'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const SelectableText(
          '$automotorsLegalOwner\n$automotorsLegalAddress\n$automotorsContactPhone\n$automotorsSupportEmail',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => openSupportUri(
            context,
            Uri(
              scheme: 'mailto',
              path: automotorsSupportEmail,
              queryParameters: {'subject': 'AUTOMOTORS — soporte'},
            ),
          ),
          icon: const Icon(Icons.mail_outline),
          label: Text(uiText(context, 'Contactar con soporte')),
        ),
        TextButton(
          onPressed: () => openSupportUri(context, appleSubscriptionsUri),
          child: Text(uiText(context, 'Gestionar suscripciones de Apple')),
        ),
        ExpansionTile(
          initiallyExpanded: initialSection == 'privacy',
          title: Text(uiText(context, 'Política de privacidad')),
          children: [
            _section(
              context,
              'Base del tratamiento',
              "La base del tratamiento necesario para las funciones que solicitas es la prestación del servicio. La prevención de fraudes y abusos responde al interés legítimo en proteger a sus usuarios y sistemas. Los tratamientos exigidos por ley se basan en la obligación legal correspondiente. Cuando una función requiere consentimiento, puedes retirarlo sin afectar al uso anterior.",
            ),
            _section(
              context,
              "Datos que utilizamos",
              "Correo y credenciales de acceso; datos de perfil y contacto; anuncios, fotografías y datos del vehículo; mensajes, reseñas y denuncias; búsquedas y favoritos; identificadores y estado de compras; y el token del dispositivo si activas las notificaciones. En cuentas profesionales también tratamos los datos fiscales que indiques. No exigimos documentos para activar las funciones profesionales.",
            ),
            _section(
              context,
              "Visibilidad de tus datos",
              "Los anuncios y reseñas son visibles para otros usuarios. Los anuncios pueden mostrar tu teléfono y, según las opciones que elijas, la matrícula y el VIN. El perfil público del vendedor puede incluir nombre, empresa, localidad, teléfono y fotografías. Los mensajes se comparten con los participantes de la conversación. No incluyas información sensible en anuncios o mensajes.",
            ),
            _section(
              context,
              "Finalidades",
              "Utilizamos estos datos para prestar el servicio de cuenta, anuncios, mensajería y planes que solicitas; verificar compras y perfiles; atender consultas y denuncias; y proteger el servicio frente a abusos. Las notificaciones requieren tu permiso y puedes desactivarlas en los ajustes del dispositivo.",
            ),
            _section(
              context,
              'Estadísticas de anuncios',
              'Si visitas un anuncio con sesión iniciada, registramos una visita por cuenta y día. El vendedor solo recibe totales de visitas, favoritos y conversaciones, sin la identidad de quienes guardan o visitan el anuncio. No contamos las visitas del propio vendedor ni rastreamos visitantes sin sesión.',
            ),
            _section(
              context,
              'Seguridad y moderación',
              "Los bloqueos impiden nuevos mensajes entre las cuentas afectadas. Si denuncias una conversación, el equipo autorizado podrá revisar sus mensajes y el contenido denunciado. Las medidas de moderación quedan registradas. Puedes solicitar una revisión escribiendo a soporte.",
            ),
            _section(
              context,
              'Moderación automática',
              "Para la moderación automática se envían a OpenAI el texto público y las fotografías del anuncio. No se envían documentos de verificación ni datos de pago a este proveedor. Si se detecta contenido inapropiado, el anuncio queda en borrador y puede revisarlo el equipo de moderación.",
            ),
            _section(
              context,
              "Proveedores",
              "Supabase proporciona autenticación, base de datos y almacenamiento. Apple procesa las compras y la entrega de notificaciones en iOS. AUTOMOTORS recibe los identificadores y el estado de la compra para verificar el acceso; no recibe los datos de tu tarjeta bancaria. Si abres servicios externos como WhatsApp, se aplican también sus propias condiciones y políticas.",
            ),
            _section(
              context,
              'Conservación y derechos',
              "Los datos de tu cuenta se conservan mientras la utilizas. Puedes iniciar su eliminación en Perfil → Configuración de cuenta → Eliminar mi cuenta. La eliminación borra los datos activos asociados; las copias de seguridad se retiran conforme al ciclo del proveedor. Las obligaciones legales pueden exigir conservar determinados justificantes durante el plazo aplicable.",
            ),
            _section(
              context,
              "Conservación y derechos",
              "Para consultas sobre tus datos o para ejercer los derechos de acceso, rectificación, supresión, oposición, limitación o portabilidad, escribe al correo de soporte. Puedes presentar una reclamación ante la Agencia Española de Protección de Datos (aepd.es). No envíes tu contraseña ni datos bancarios por correo.",
            ),
          ],
        ),
        ExpansionTile(
          initiallyExpanded: initialSection == 'terms',
          title: Text(uiText(context, 'Condiciones de uso')),
          children: [
            _section(
              context,
              "Condiciones de uso",
              "AUTOMOTORS permite publicar anuncios y contactar con compradores y vendedores. La compraventa del vehículo se acuerda entre sus participantes. Comprueba la identidad, la documentación y el estado del vehículo antes de realizar un pago.",
            ),
            _section(
              context,
              "Normas de la comunidad",
              "AUTOMOTORS aplica tolerancia cero al contenido inapropiado y a los usuarios abusivos: se prohíben el fraude, el contenido ilegal, las amenazas, el acoso y la publicación de datos ajenos sin autorización. Publica información veraz y fotografías que tengas derecho a utilizar. Puedes denunciar desde la ficha del anuncio o el menú de seguridad del chat y bloquear usuarios abusivos. Revisamos las denuncias en un máximo de 24 horas, retiramos el contenido que infringe estas normas y suspendemos a los responsables cuando corresponde. Contacto: info@automotors.info.",
            ),
            _section(
              context,
              "Compras y renovaciones",
              "El precio y el período de cada suscripción se obtienen de Apple. El pago se carga a tu cuenta de Apple al confirmar. La suscripción se renueva automáticamente salvo que la canceles al menos 24 horas antes de terminar el período actual. Apple puede cobrar la renovación durante las 24 horas anteriores a su finalización. Puedes gestionar o cancelar la renovación en las suscripciones de tu cuenta de Apple.",
            ),
            _section(
              context,
              "Gestionar suscripciones de Apple",
              "Eliminar la app o la cuenta de AUTOMOTORS no cancela una suscripción de Apple. Gestiona su renovación desde tu cuenta de Apple.",
            ),
            TextButton(
              onPressed: () => openSupportUri(context, appleTermsUri),
              child: const Text('Apple EULA'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _section(BuildContext context, String title, String body) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          uiText(context, title),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        SelectableText(
          uiText(context, body),
          style: const TextStyle(height: 1.5),
        ),
      ],
    ),
  );
}
