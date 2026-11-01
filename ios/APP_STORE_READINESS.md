# AUTOMOTORS: estado de la versión de iPhone

## Base que se debe conservar

La versión distribuida más reciente es **AUTOMOTORS 1.0.1 (13)** en el grupo interno AUTOMOTORS Sandbox. Los cambios de preparación de App Store posteriores a la build 13 todavía no se han distribuido en una nueva build.

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

La build 12 se ha compilado y firmado desde el commit ec0387e4cd69d6b9ca55fa1d280114926c17550b. Codemagic confirma Version 1.0.1, Version code 12 y UPLOAD SUCCEEDED with no errors:
https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae6650aefa74786046f944a

La validacion de GitHub Actions tambien ha terminado correctamente, incluidas pruebas y compilacion web: https://github.com/ahautos01-blip/automotors-app/actions/runs/41246184721. El procesamiento y la asignacion de TestFlight se comprueban por separado.

Apple termino de procesar la build 12, id f0deb530-3236-4cc2-a305-76b30f23338c. Tras la autorizacion expresa del titular para esta build, se guardo la respuesta "Ninguno de los algoritmos mencionados anteriormente" en la informacion de exportacion. La build 1.0.1 (12) esta asignada a AUTOMOTORS Sandbox y App Store Connect confirma "En pruebas". Esta disponible para actualizar desde TestFlight. La publicacion publica sigue pendiente.

## Build 13: icono original y acceso sin recorte

La version preparada es 1.0.1 (13). Recupera el PNG original AutoMotors_icono_iPhone_1024.png del chat Generar icono app coche, con Audi, BMW, Mercedes, Volkswagen y Porsche. Se conserva el original RGB de 1024 x 1024 y se regeneran 33 exportaciones iOS y web, sin canal alfa.

El inicio de sesion mantiene el icono cuadrado a 112 x 112, con BoxFit.contain y sin un recorte adicional. Se comprueba a anchos de 320, 390 y 430 puntos. Las traducciones y las funciones de la build 12 se conservan. La distribucion de la build 13 se verifica por separado.

Las 39 pruebas de Flutter pasan con el icono original, incluidas las tres comprobaciones del acceso a 320/390/430 puntos. La validacion de GitHub tambien termino correctamente (pruebas y compilacion web): https://github.com/ahautos01-blip/automotors-app/actions/runs/41248731664.

Codemagic compilo, firmo y subio 1.0.1 (13) desde el commit a206ba46e43cf6e2d7cf7b76e67cb0e857cd823b. Confirmo Version code 13 y UPLOAD SUCCEEDED with no errors:
https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae66cddefa74786046f95fb

Apple termino de procesar la build 13 (1ccb1715-4e89-46ee-b940-b4971c029158). El titular autorizo expresamente guardar para esta build la respuesta "Ninguno de los algoritmos mencionados anteriormente" sobre cifrado. Se guardo y se asigno la build a AUTOMOTORS Sandbox. App Store Connect confirma 1.0.1 (13) "En pruebas", disponible para actualizar en TestFlight con el icono correcto. La publicacion publica sigue pendiente.


## Preparación posterior a la build 13 — 1 de noviembre de 2026

Datos confirmados por el titular: Abdelmounim Taghi; abdelmounimtg94@gmail.com;
Carrer Pablo Iglesias 56, 08302 Mataró, España; 937212845.

Cambios del cliente preparados:
- Ayuda sin iniciar sesión, contacto copiable y apertura del correo con alternativa si falla.
- Enlaces directos a privacidad y condiciones en el acceso y en los planes.
- Precio y período obtenidos de StoreKit, conservando moneda y duración reales. No se deducen del identificador del producto. Si no llega el período, el botón de contratación permanece desactivado.
- Información de renovación automática, restauración y gestión de suscripciones de Apple.
- Eliminación desde Mi espacio: reconocimiento del aviso de suscripciones y segunda confirmación; errores visibles y reintentos. Borrar la cuenta no cancela la suscripción de Apple.
- Textos en español, inglés y catalán. Páginas web estáticas equivalentes en web/support.html, web/privacy.html y web/terms.html, preparadas pero no publicadas. Se regeneran con tool/export_support_pages.py.

Servidor activado:
- protect_profile_authority y preserve_profile_default_status impiden que el cliente se conceda is_admin o apruebe su verificación. Conservan los valores predeterminados reales y las solicitudes de revisión existentes.
- La revisión automática rechazó inicialmente el despliegue de eliminación por su alcance destructivo. Tras ver la función implementada y probada, el titular autorizó expresamente «Sí, activar la eliminación de cuentas». Entonces se aplicó account_deletion_and_session_guards y se desplegó delete-account versión 1 con verify_jwt=true.
- El endpoint valida la identidad con Auth y vincula session_id al usuario en auth.sessions. No acepta un identificador de cuenta enviado por el cliente. Las RPC de preparación y limpieza solo admiten service_role.
- Una marca privada suspende el acceso del usuario durante el borrado; doce políticas restrictivas complementan las reglas existentes. Las sesiones con JWT de una cuenta ya eliminada tampoco pueden volver a escribir.
- Primero se eliminan archivos mediante la API de Storage, después se limpian relaciones heredadas y anuncios propios (su FK actual es SET NULL), y por último se elimina Auth mediante su API administrativa. El resto de relaciones y sesiones se eliminan en cascada. Los fallos dejan una marca duradera para reintentar, sin anunciar éxito parcial.
- No se ha eliminado ninguna cuenta real durante las pruebas. Se comprobó que hay cero borrados pendientes y que el endpoint responde 401 sin autenticación.

Validación: 47 pruebas Flutter correctas; pruebas de permisos y eliminación en PostgreSQL en memoria, más pruebas del endpoint con HTTP simulado. Se cubren autoasignación de privilegios, guardado normal y upsert, solicitudes de verificación, autenticación, sesión de otra cuenta, orden Storage/Auth, errores parciales, reintentos, claves foráneas heredadas y JWT de una cuenta eliminada. El workflow account-security.yml repite estas comprobaciones en CI.

Avisos de Supabase: las tablas privadas de trabajo y los eventos de tienda tienen RLS sin políticas deliberadamente (ningún acceso de clientes). Sigue pendiente la protección contra contraseñas filtradas, que ya estaba desactivada: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.

Pendientes antes del envío público:
- Chat: bloqueo de usuarios, denuncias y circuito de moderación; filtrado y operación de las denuncias de contenido.
- Revisar los textos legales, las condiciones de los proveedores, la conservación efectiva y las transferencias; publicar las URL estables e introducirlas en la ficha de Apple.
- Completar ficha, privacidad de App Store, clasificación por edades, capturas y cuenta/instrucciones de revisión.
- Pruebas físicas de registro, publicación, compras/restauración, mensajes y eliminación con una cuenta de prueba creada para ello.
- Compilar, firmar y distribuir una nueva build; comprobar su aceptación y disponibilidad real en TestFlight. La última build disponible sigue siendo 13.

No se ha enviado esta preparación a revisión pública ni se ha reemplazado el verificador de compras desplegado.

Se confirmó que faltaba seller_about_profiles en el servidor, lo que impedía completar el guardado de perfiles profesionales. Se creó únicamente esa tabla con permisos de escritura para el propio profesional, lectura pública y protección durante la eliminación. La prueba aislada verifica escritura propia, rechazo a otras cuentas y particulares, lectura pública y borrado en cascada. Esta política eleva a trece los controles restrictivos de cuenta activa.

La compilación web de producción JavaScript terminó correctamente con --no-wasm-dry-run. Los archivos nuevos de Dart pasan el analizador sin avisos. El análisis global conserva 69 avisos anteriores de estilo/API obsoletas, sin errores. Las páginas legales siguen preparadas para revisión y no están publicadas.
