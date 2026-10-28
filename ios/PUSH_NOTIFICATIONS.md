# Notificaciones de mensajes y valoraciones

## Preparado en el código y Supabase

- Registro APNs nativo, permiso de alertas/sonidos y apertura desde segundo plano o app cerrada.
- Mensajes nuevos: aviso únicamente al otro participante; al tocarlo se abre su conversación.
- Compra confirmada: invitación al comprador verificado; al tocarla se abre su valoración.
- Cada dispositivo se vincula a la sesión de Supabase. Cerrar sesión o revocarla elimina el registro.
- Cola por dispositivo con leases, deduplicación, reintentos y descarte de mensajes ya leídos.
- Los avisos de mensajes no muestran texto privado en la pantalla bloqueada.
- El envío programado procesa hasta 25 avisos por minuto. APNs decide la entrega final según el estado y los permisos del dispositivo.

La función `send-ios-push` y la cola están desplegadas. Sin la clave APNs, la función devuelve `503 apns_not_configured` sin consumir reintentos. No se ha confirmado todavía la entrega en un iPhone real.

## Activación pendiente de Apple

1. En Apple Developer, abre **Certificates, Identifiers & Profiles → Identifiers**, selecciona el Bundle ID real de AUTOMOTORS y activa **Push Notifications**. El identificador del repositorio es `com.automotors.automotorsBase`; confirma que coincide con el de la app distribuida antes de compilar.
2. Crea una clave con permiso **Apple Push Notifications service (APNs)** en **Keys**. Una clave de App Store Connect o In-App Purchase no sustituye a una clave APNs. Anota su Key ID, el Team ID y descarga el archivo `.p8`. No lo subas a GitHub ni lo pegues en chats.
3. En [Supabase → Edge Function Secrets](https://supabase.com/dashboard/project/ndicdhlpbyywqyjgxpnx/functions/secrets), configura:

   | Secreto | Valor |
   | --- | --- |
   | `APNS_PRIVATE_KEY` | Contenido completo del `.p8`, incluidos encabezados y saltos de línea |
   | `APNS_KEY_ID` | Key ID de esa clave APNs |
   | `APNS_TEAM_ID` | Team ID de Apple Developer |
   | `IOS_BUNDLE_ID` | Bundle ID exacto de la app instalada |

4. Regenera los perfiles de firma después de activar Push Notifications. Xcode usa `Runner.entitlements`: Debug solicita `development`; Release/Profile, `production`. TestFlight utiliza producción. Si la configuración de firma de tu CI sobrescribe el Bundle ID, conserva también la capacidad APNs en su perfil.
5. Compila y distribuye la nueva versión mediante TestFlight. La app instalada anteriormente no registra tokens APNs. Inicia sesión y acepta el permiso de notificaciones.

## Validación en dos iPhones

- Con cuentas distintas, envía un mensaje real: el receptor debe recibir el aviso con la app en segundo plano y abrir el chat al tocarlo. El remitente no debe recibirlo.
- Confirma una venta al comprador del chat: este debe recibir la invitación y poder guardar una única valoración. Las ventas externas no generan invitaciones.
- Repite con la app terminada y comprueba que se abre el destino después de iniciar sesión si hace falta.
- Lee un mensaje antes del siguiente envío: su aviso pendiente se descarta.
- Cierra sesión y cambia de cuenta: no deben llegar avisos de la cuenta anterior.
- Comprueba permisos denegados, restauración de permisos en Ajustes y desconexión temporal.

## Comprobaciones del servidor

`supabase/tests/ios_push.sql` comprueba destinatarios, permisos, cola, leases y cierre de sesión dentro de una transacción que se revierte. Requiere una venta confirmada a un comprador de chat.

`node --experimental-strip-types supabase/functions/send-ios-push/core_test.ts` valida payloads, errores de APNs y firma ES256 con una clave efímera de prueba.

Los scripts `supabase/fixes/enable_ios_push.sql` y `schedule_ios_push.sql` documentan la instalación ya aplicada; no deben ejecutarse otra vez sin revisar los objetos existentes. `send-ios-push` desactiva la validación JWT de la pasarela porque autentica cada petición con la credencial privada del programador, verificada por una RPC accesible únicamente a `service_role`.

Referencias: [APNs y claves de autenticación](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns), [push desde Supabase](https://supabase.com/docs/guides/functions/examples/push-notifications).
