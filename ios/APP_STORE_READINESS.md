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

La build 11 se compiló y subió correctamente desde el commit `be733792b26ee8a7f1df6fd95ceab1dc35d1d7ab`:
https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae637d8efa74786046f88df

Que una compilación arranque o genere un archivo no confirma la distribución. Comprobar por separado la compilación/firma, la aceptación de la subida por Apple, el procesamiento y la disponibilidad en el grupo de TestFlight. Apple confirmó la aceptación de la subida y terminó el procesamiento. El titular autorizó guardar la respuesta «Ninguno de los algoritmos mencionados anteriormente» para la declaración de cifrado de esta build. La versión 1.0.1 (11) está asignada a AUTOMOTORS Sandbox y App Store Connect confirma el estado «En pruebas». Está disponible para actualizar desde TestFlight.

La publicación pública en App Store sigue siendo un paso posterior. Queda revisar la ficha, soporte, privacidad, eliminación de cuenta, moderación y las pruebas físicas de los flujos de compra, chat y publicación antes del envío.

## Perfil de firma renovado

El 31 de octubre de 2026 se activó Push Notifications para el identificador existente y se regeneró su perfil App Store con autorización expresa del titular. La compilación fallaba porque el perfil anterior no incluía aps-environment. La segunda ejecución generó el IPA de 1.0.1 (11), de 27,3 MB, y Apple confirmó UPLOAD SUCCEEDED with no errors.

## Correccion completa de traducciones: build 12

La version preparada es 1.0.1 (12). La build 11 solo traducia parte del catalogo. La build 12 conecta el idioma de la app a la portada completa, filtros y opciones, acceso, perfil, formularios de anuncios, chat, resenas, planes y mensajes de compras. Mantiene las claves y valores almacenados, asi como las descripciones y mensajes escritos por los usuarios.

El cambio de idioma conserva la busqueda y los filtros de la portada. Los campos de formulario conservan sus etiquetas internas para no alterar las validaciones de precio y telefono. Se corrigen desbordamientos en desplegables, cabecera, contador de anuncios y presentacion de planes.

Validacion local: 36 pruebas de Flutter correctas, incluidas 15 nuevas pruebas de traducciones y pantallas a 390 x 844 en es/en/ca. Analisis sin errores; persisten avisos anteriores de estilo y API obsoletas. La distribucion de la build 12 debe verificarse por separado en Codemagic y App Store Connect.
