# AUTOMOTORS: estado de la versión de iPhone

## Base que se debe conservar

La aplicación de prueba existente es AUTOMOTORS 1.0.1 (10), distribuida mediante TestFlight en el grupo interno AUTOMOTORS Sandbox. La actualización preparada es **1.0.1 (11)**.

- Repositorio: https://github.com/ahautos01-blip/automotors-app
- Rama de preparación: `restore/ios-1.0.1-build10`.
- Solicitud de integración: https://github.com/ahautos01-blip/automotors-app/pull/3
- Identificador iOS existente: `com.automotors.automotorsBase`.
- App Store Connect: aplicación `6827315199`.
- Codemagic utiliza Default Workflow con la firma y publicación ya configuradas.

No reemplazar el proyecto nativo por una plantilla nueva ni cambiar el identificador para actualizar la app existente.

## Compras

La build nativa de pruebas utiliza `--dart-define=AUTOMOTORS_ENABLE_STORE_CHECKOUT=true`. Sin ese parámetro el cliente desactiva las compras de forma predeterminada. El workflow de Codemagic ya incluye el parámetro y apunta al Supabase principal `ndicdhlpbyywqyjgxpnx`.

El backend de compras está desplegado: `verify-store-purchase`, `app-store-server-notifications` y la RPC de suscripciones verificadas. El cliente no concede acceso por una respuesta local de Apple.

El código desplegado del verificador puede diferir del que contiene esta rama: obtener y comparar la versión remota antes de desplegar una modificación. No sobrescribirlo con una versión antigua durante la preparación de una build.

La última incidencia observada devolvía conflictos de cuenta y transacciones caducadas. Tras volver a iniciar sesión con la cuenta de la compra y restaurarla, el usuario confirmó que funcionaba. La build 11 incluye mensajes que distinguen esas situaciones.

## Cambios incluidos en la build 11

- Integración de las mejoras del catálogo de main sin perder compras, notificaciones, destacados o configuración nativa.
- Más textos del catálogo en español, inglés y catalán.
- Correcciones del selector de orden y del panel de resultados vacíos en pantallas estrechas.
- Explicaciones de errores de verificación de compras.

## Validación y distribución

Las 21 pruebas de Flutter pasan localmente, incluida la pantalla del catálogo a 390 × 844 con filtros abiertos en los tres idiomas. La compilación web de la integración anterior también pasó.

La build 11 se inició en Codemagic desde el commit `1fca17e9ad713eb2b2afbf782cc6efb2a76afccb`:
https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae63688efa74786046f887e

Que una compilación arranque o genere un archivo no confirma la distribución. Comprobar por separado la compilación/firma, la aceptación de la subida por Apple, el procesamiento y la disponibilidad en el grupo de TestFlight. Al redactar este registro, esa comprobación está en curso.

La publicación pública en App Store sigue siendo un paso posterior. Queda revisar la ficha, soporte, privacidad, eliminación de cuenta, moderación y las pruebas físicas de los flujos de compra, chat y publicación antes del envío.
