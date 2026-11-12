# AUTOMOTORS: estado de la versión de iPhone

## Base que se debe conservar

La versión distribuida más reciente es **AUTOMOTORS 1.0.1 (31)** en el grupo interno AUTOMOTORS Sandbox. La build 26 queda sin asignar y sustituida por 27.

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
- Filtro automático del contenido: el titular eligió integrar un proveedor automático, no revisión previa manual. Cuenta API y secreto de servidor preparados; integración implementada y probada localmente. Quedan la autorización de despliegue, la conexión real y el cierre del acceso público a fotos antes de activar la exigencia global.
- Revisar los textos legales, las condiciones de los proveedores, la conservación efectiva y las transferencias; publicar las URL estables e introducirlas en la ficha de Apple.
- Completar ficha, privacidad de App Store, clasificación por edades, capturas y cuenta/instrucciones de revisión.
- Pruebas físicas de registro, publicación, compras/restauración, mensajes y eliminación con una cuenta de prueba creada para ello.
- Compilar, firmar y distribuir una nueva build; comprobar su aceptación y disponibilidad real en TestFlight. La última build disponible sigue siendo 13.

No se ha enviado esta preparación a revisión pública ni se ha reemplazado el verificador de compras desplegado.

Se confirmó que faltaba seller_about_profiles en el servidor, lo que impedía completar el guardado de perfiles profesionales. Se creó únicamente esa tabla con permisos de escritura para el propio profesional, lectura pública y protección durante la eliminación. La prueba aislada verifica escritura propia, rechazo a otras cuentas y particulares, lectura pública y borrado en cascada. Esta política eleva a trece los controles restrictivos de cuenta activa.

La compilación web de producción JavaScript terminó correctamente con --no-wasm-dry-run. Los archivos nuevos de Dart pasan el analizador sin avisos. El análisis global conserva 69 avisos anteriores de estilo/API obsoletas, sin errores. Las páginas legales siguen preparadas para revisión y no están publicadas.


## Seguridad del chat y moderación — preparación posterior a la build 13

El titular autorizó expresamente que abdelmounimtg94@gmail.com tenga permisos de moderación. La cuenta se incorporó a private.community_moderators, sin cambiar is_admin ni conceder acceso directo a tablas privadas. Las lecturas y acciones de moderación requieren una cuenta activa y una sesión existente y vigente en auth.sessions, además de ese rol.

La migración chat_safety_and_moderation está aplicada en el servidor. Los bloqueos se comprueban en ambas direcciones, afectan a todas las conversaciones de la pareja e impiden crear otra conversación para evitarlos. La creación de chats también comprueba que el vendedor sea el propietario real de un anuncio publicado o reservado. El envío y los bloqueos usan el mismo bloqueo transaccional por pareja. Se conserva la lectura del historial y los recibos; el cliente ya no puede insertar fechas ni recibos falsos.

Las denuncias de chat solo las pueden crear participantes reales. Su motivo y tamaño se validan en el servidor; una denuncia abierta no se duplica y se puede denunciar una incidencia nueva después de cerrar la anterior. Los datos de seguridad son privados y se eliminan en cascada cuando se elimina la cuenta o conversación relacionada.

El panel preparado reúne denuncias de anuncios y conversaciones, con paginación. El moderador solo puede acceder a los mensajes mediante una denuncia existente; puede cargar páginas anteriores del caso, consultar las fotos del anuncio denunciado, registrar notas, cerrar o descartar casos, ocultar/restaurar anuncios y restringir/restablecer el chat del usuario denunciado. Cada acción requiere confirmación y queda auditada. El propietario conserva la lectura de su anuncio oculto, pero no puede editarlo para saltarse la medida; conserva la posibilidad de eliminar sus datos. Las restricciones de moderación y los bloqueos personales son independientes.

Cliente: controles y explicaciones en español, inglés y catalán; avisos claros cuando el chat está bloqueado o no se ha podido comprobar el acceso; envío desactivado hasta recibir una comprobación válida. El estado se consulta de nuevo al volver a la app o si falla un envío.

Validación: 61 pruebas Flutter correctas, incluidas catorce nuevas de controladores, confirmaciones, denuncias y acciones de moderación en tres idiomas. PostgreSQL en memoria cubre permisos reales, tipos bigint, bloqueos mutuos, ausencia de saltos por otro anuncio, propiedad del vendedor, conservación de evidencia, fechas no falsificables, denuncias privadas, auditoría, reversión de medidas, paginación de denuncias y mensajes, sesión revocada y borrado en cascada. Los archivos nuevos pasan el analizador sin avisos. La verificación remota confirma el rol autorizado, la ausencia de permisos de lectura directa de denuncias, de autoasignación del rol y de moderación anónima. No se han enviado mensajes, creado denuncias ni aplicado medidas a usuarios reales durante las pruebas.

Estas pantallas aún no están distribuidas: la última build en TestFlight sigue siendo 1.0.1 (13). No afirmar que el filtro automático está activo. La API de moderación de OpenAI admite texto e imágenes y su endpoint figura como gratuito en la documentación oficial consultada; sigue sujeta a límites: https://developers.openai.com/api/docs/guides/moderation y https://developers.openai.com/api/docs/models/omni-moderation-latest.

La revisión automática bloqueó abrir el formulario de creación de la credencial API porque requiere autorización explícita para generar una clave con acceso al proyecto. No se ha creado ni copiado ninguna clave. Las páginas de API keys y secretos de Supabase están abiertas para preparar una credencial limitada y guardarla como OPENAI_API_KEY; la clave privada debe introducirse directamente en el servidor, no en el chat.

La compilación web JavaScript de este lote terminó correctamente. La cuenta API de OpenAI del titular ya está creada, pero no existe todavía una credencial configurada para moderación. El filtro automático sigue sin implementar/activar; no desplegar un control solo en el cliente que pueda saltarse con llamadas directas a la API. Las aprobaciones futuras deben vincularse al contenido exacto del anuncio/fotos y a su propietario; contemplar cambios de texto o sustitución de fotos después de aprobarlas, fallos del proveedor y reintentos.

Capacidad verificada en el panel de Supabase: 10,452 GB de Cached Egress sobre 5 GB incluidos (209 %), ciclo 23/10/2026–23/11/2026. El aviso indica posibles respuestas 402 a partir del 30/11/2026 si sigue excedido el límite. Almacenamiento de 0,062/1 GB, tamaño de base de datos 0,032/0,5 GB y Egress sin caché 0,206/5 GB. Antes del lanzamiento, reducir descargas repetidas de fotos y revisar la capacidad/plan con el titular. No se ha contratado un plan ni cambiado la facturación.


## Moderación automática preparada — pendiente de despliegue

El titular autorizó preparar una credencial restringida de moderación. Creó la clave personalmente y guardó OPENAI_API_KEY en el panel de secretos de Supabase; se verificó la presencia del nombre, sin incorporar el valor al código ni a los artefactos. No se ha verificado aún la conexión real con OpenAI.

La migración 20261101213447_automatic_content_moderation.sql y moderate-listing están implementadas, sin desplegar. El servidor vincula cada aprobación al propietario, a una sesión vigente, al texto exacto y a las versiones de los archivos. Comprueba límites de intentos y del plan, invalida comprobaciones si cambia el contenido y conserva borradores ante rechazo o fallos. La revisión humana confirma la huella que se mostró al moderador y registra la acción. El proveedor recibe el texto público y fotos del anuncio, sin teléfono privado, documentos de verificación ni datos de pago. Modelo fijado: omni-moderation-2024-09-26.

El nuevo cliente solicita la comprobación al publicar y al modificar anuncios publicados o reservados. Incluye avisos del proveedor, estados del borrador y textos en español, inglés y catalán. Las nuevas fotos se reducen a 1920 píxeles y calidad 75; esto no resuelve por sí solo el exceso de tráfico existente.

Validación local: 68 pruebas Flutter correctas; compilación web de producción correcta; analizador sin avisos en los archivos Dart nuevos de moderación. Las pruebas PostgreSQL/HTTP simulado comprueban permisos, aprobación vinculada al contenido, sustitución de fotos, sesiones revocadas, límites, revisión humana, errores del proveedor y aislamiento de claves. La sonda sintética está probada con HTTP simulado, no contra OpenAI real.

La revisión automática rechazó aplicar la migración en producción por añadir triggers, políticas RLS y reglas de publicación/visibilidad sin autorización explícita de ese despliegue. No se intentó eludir el bloqueo ni se desplegó la función. Se solicita aprobación del conjunto después de preparar el código y las pruebas.

El despliegue previsto deja la exigencia global desactivada para conservar la compatibilidad con la build 13. Antes de activarla hay que distribuir y probar el cliente compatible, preparar los anuncios existentes y convertir el bucket de fotos público a privado mediante Storage, verificando las descargas autorizadas. Mientras el bucket sea público, las URL directas pueden seguir mostrando archivos sin las reglas de visibilidad del anuncio. No afirmar que el filtro está activo o que las fotos están protegidas globalmente.

La última versión disponible en TestFlight sigue siendo 1.0.1 (13). No se ha enviado una nueva build ni publicado en App Store. Las páginas legales y el código permanecen en la propuesta de cambios para revisión.


## Despliegue y conexión real verificados — 1 de noviembre de 2026

Tras autorización expresa del titular, se aplicó automatic_content_moderation y se desplegó moderate-listing con verify_jwt=true. La primera prueba respondió 403 service_required. La revisión automática exigió una autorización adicional para incorporar y desplegar la corrección de validación de credenciales de servidor alternativas; el titular la concedió expresamente. La función versión 2 está ACTIVE y valida esas credenciales mediante firma de PostgREST y permiso EXECUTE del RPC content_provider_probe_result, reservado a service_role. Las pruebas aisladas confirman que las cuentas normales son rechazadas antes de llamar al proveedor.

La prueba real devolvió HTTP 200: connected=true, text_checked=true, image_checked=true, modelo omni-moderation-2024-09-26. Se usaron exclusivamente una frase ficticia sobre un automóvil y una imagen gris generada. El registro privado last_probe confirma el resultado a las 22:06:45 UTC (23:06:45 en Madrid). No se procesaron anuncios ni fotos reales durante esta prueba. Se vaciaron las cabeceras del formulario y se cerró la pestaña de claves; no se guardaron credenciales en el repositorio.

La consulta posterior confirma enabled=false. La exigencia global sigue pendiente del despliegue y prueba del cliente compatible y del cierre del acceso público al bucket de fotos. La última versión distribuida continúa siendo 1.0.1 (13). La revisión de seguridad mantiene únicamente los avisos conocidos: tablas privadas sin políticas deliberadamente y protección contra contraseñas filtradas desactivada.


## Build 14 y acceso privado a fotos

Se preparó 1.0.1 (14), commit dbba18b, y se inició la compilación firmada en Codemagic: https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae7b8adefa74786046fe5f4. Incluye ayuda/privacidad, suscripciones, eliminación de cuenta, chat seguro, panel de moderación y publicación comprobada. La disponibilidad en TestFlight debe confirmarse después de la subida y procesamiento.

El bucket vehicle-photos se cambió a privado mediante el panel de Storage. La comprobación real detectó un fallo heredado: la política de lectura consultaba user_profiles, sin permiso para visitantes anónimos. La revisión automática bloqueó modificar esa política hasta recibir autorización explícita; el titular autorizó desplegar la corrección. Se aplicó 20261101221212_private_vehicle_photo_reads.sql: las lecturas dependen de la visibilidad RLS del anuncio, coinciden con su carpeta/propietario y permiten borradores propios sin consultar perfiles privados. La política independiente de acceso por denuncia para moderadores se conserva.

Verificación HTTP posterior: descarga por la ruta usada por el SDK con clave publicable y sin sesión de usuario devuelve 200 image/jpeg para una foto publicada; la ruta pública directa devuelve Bucket not found/404 (respuesta HTTP 400 de Storage). Las pruebas PostgreSQL aisladas cubren acceso anónimo a publicados, borradores propios, rechazo de borradores ajenos, carpeta incorrecta y visibilidad restringida. No se han borrado ni movido archivos. Las copias previamente cacheadas en CDN pueden persistir; no se ha afirmado una purga retroactiva.

La exigencia global de moderación sigue desactivada a la espera de pruebas de la build compatible y revisión de los anuncios existentes. Continúa pendiente reducir las descargas repetidas del catálogo y revisar capacidad. Esta preparación no constituye publicación pública.


Codemagic confirmó Version 1.0.1, Version code 14 y UPLOAD SUCCEEDED with no errors el 1/11/2026 a las 22:14:44 UTC. El procesamiento y la asignación en TestFlight todavía se deben confirmar. El titular autorizó expresamente guardar para esta build la respuesta «Ninguno de los algoritmos mencionados anteriormente» sobre cifrado. La sesión de App Store Connect caducó; se abrió una pestaña visible para que el titular vuelva a iniciar sesión. No afirmar disponibilidad hasta comprobarla en Apple.


Apple terminó de procesar 1.0.1 (14), id 21eec1c0-38d0-4e8e-9408-6b9fa4aaf9a9. Tras la autorización expresa para esta build, se guardó «Ninguno de los algoritmos mencionados anteriormente» en la declaración de cifrado y se añadió a AUTOMOTORS Sandbox. La página del grupo interno confirma 1.0.1 (14) «En pruebas», con dos testers y caducidad de 90 días. Ya está disponible para actualizar desde TestFlight. La publicación pública y la activación global del filtro siguen pendientes de las pruebas físicas y restantes preparativos.


## Build 15 preparada: visibilidad de identificación y carga de fotos

Se corrige que la portada y la ficha desde el chat no consultaban los campos show_matricula_publicly/show_vin_publicly y descartaban el VIN o sus permisos. Todas las fichas de anuncios persistidos usan Car.fromListing; los datos públicos de identificación solo entran en ese objeto si su opción está activada. El resultado de publicar un anuncio conserva también esas opciones. Esta corrección de presentación no debe confundirse con una nueva protección de columnas de la API.

La portada descarga únicamente la primera foto ordenada y conserva las rutas del resto. Al abrir una ficha se cargan las restantes sin volver a descargar una portada correcta; el contador conserva el total real, una foto fallida no oculta las demás y la galería completa espera la carga pendiente. No hay caché persistente ni se guardan credenciales. La mejora reduce solicitudes iniciales para anuncios con varias fotos; todavía no se ha medido el tráfico real y el exceso de cuota anterior no desaparece por este cambio.

Validación local: 83 pruebas Flutter correctas. Las quince nuevas verifican las cuatro combinaciones de visibilidad en español, inglés y catalán, opciones ausentes, una sola descarga inicial, orden, reintentos y fotos fallidas. Se corrige además el desbordamiento del título técnico en inglés a 390 puntos. Versión preparada 1.0.1 (15); no afirmar distribución hasta comprobar compilación y Apple.


La compilación web JavaScript y la validación de Flutter en GitHub terminaron correctamente para dd389fd1b42f11792a7697554ac257fdb6144029. Codemagic compiló, firmó y subió 1.0.1 (15), confirmando UPLOAD SUCCEEDED with no errors a las 22:34:28 UTC: https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae7bd29efa74786046fe71b.

Apple terminó el procesamiento de la build 15, id 6f415325-ec60-41d3-b4e5-2e04adc50571. El titular autorizó expresamente guardar para esta build «Ninguno de los algoritmos mencionados anteriormente». Se guardó y se añadió la build a AUTOMOTORS Sandbox. La página del grupo interno confirma 1.0.1 (15) «En pruebas», dos testers y caducidad de 90 días: disponible para actualizar desde TestFlight. Pendiente comprobar en el iPhone la visibilidad con otra cuenta y la galería. No se ha enviado a revisión pública ni activado la exigencia global del filtro.


## Incidencia pendiente: moneda del catálogo de suscripciones en TestFlight

El titular informa de 179 $ en la tarjeta de AUTOMOTORS PRO y 199 € en la ventana de compra de Apple. Se comprobó en App Store Connect el producto automotors_pro_monthly_199: duración 1 mes, disponibilidad en un único país (España), tarifa actual para España (EUR) 199,00 €. La cuenta Sandbox existente también está configurada en España. No se modificaron tarifas ni regiones.

_storePrice muestra product.price recibido de StoreKit sin convertir moneda. La diferencia apunta a metadatos de catálogo del entorno de pruebas; no se ha instrumentado todavía el dispositivo para confirmar la causa. No sustituir símbolos ni convertir cifras manualmente: 179 $ y 199 € son importes distintos. Queda pendiente recargar el catálogo desde una sesión de prueba correcta y comprobar coincidencia entre tarjeta y hoja de Apple antes del envío público. No afirmar que la incidencia está corregida ni garantizar que desaparezca por publicar.


## Build 16 preparada: acceso a denuncia y moneda incoherente

La función _reportListing existía sin un control que la invocase. Se añaden el icono de bandera en la cabecera y el botón Denunciar anuncio junto a las acciones de la ficha para anuncios persistidos. Muestra seis motivos traducidos, con desplazamiento en pantallas pequeñas. Se puede consultar el motivo antes del acceso; el envío exige sesión. Ambas etapas permiten cancelar sin insertar, los detalles son opcionales y se evita abrir envíos simultáneos. La edición de detalles conserva su controlador hasta completar la salida del diálogo.

La discrepancia de PRO persiste tras reabrir la app, según el titular. Se añade una protección de presentación para el mercado actualmente disponible en App Store Connect (solo España): si StoreKit entrega moneda distinta de EUR en iOS, la tarjeta muestra Consultar precio en Apple en lugar de un importe incoherente. No convierte importes ni sustituye símbolos. Los precios EUR válidos y los de otras plataformas conservan los valores de tienda. La hoja nativa sigue confirmando importe, moneda y contratación. Si se amplía la disponibilidad geográfica, debe revisarse esta restricción de mercado. El fallo del proveedor de metadatos no se considera resuelto; este es un comportamiento alternativo para no anunciar 179 $ como precio español.

Las pruebas de interfaz de denuncia usan únicamente cuentas, anuncios y respuestas HTTP ficticios; no crean denuncias reales. Se verifican motivos y envío en es/en/ca a 320x568 y cancelación en ambas etapas. Se añade una comprobación de monedas que rechaza presentar 179 USD como tarifa EUR y conserva 199 EUR. La versión preparada es 1.0.1 (16); la distribución se confirma por separado.

Validación local del lote 16: 88 pruebas Flutter correctas y compilación web JavaScript de producción correcta. No se han creado denuncias reales ni cambiado tarifas de Apple durante estas comprobaciones.


Codemagic compiló, firmó y subió 1.0.1 (16), commit 0e686d146655986ebdab57d11d76517af0794fca. El registro confirma Version code 16 y UPLOAD SUCCEEDED with no errors a las 23:02:09 UTC del 1/11/2026 (00:02:09 del 2/11 en Madrid), delivery/build UUID 5f6caf4a-97f7-4ab5-83cb-0c42e3058e99: https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae7c3ddefa74786046fe8b3.

El titular autorizó expresamente guardar para la build 16 «Ninguno de los algoritmos mencionados anteriormente». La revisión automática bloqueó el acceso al navegador por límite de uso. Al retomarlo el 2/11 exigió nueva autorización explícita para acceder a Apple, que el titular concedió. El acceso quedó permitido, pero la sesión de Apple había caducado; se abrió el formulario para que el titular inicie sesión. Aún no se ha guardado la declaración de la build 16 ni confirmado la asignación/estado En pruebas. No afirmar disponibilidad hasta verificarlo en Apple.


El 2/11/2026, tras el inicio de sesión del titular, se confirmó que Apple había procesado 1.0.1 (16). Se guardó la respuesta de cifrado ya autorizada y se añadió la build 5f6caf4a-97f7-4ab5-83cb-0c42e3058e99 a AUTOMOTORS Sandbox. La página del grupo interno confirma «En pruebas», dos testers y caducidad de 90 días. Build 16 disponible para actualizar desde TestFlight. Pendientes la prueba física de denuncia y verificar que los precios EUR válidos se mantienen o aparece Consultar precio en Apple si el catálogo devuelve otra moneda. No se ha convertido 179 USD en 199 EUR ni resuelto el origen del metadato incoherente. La publicación pública y la exigencia global del filtro siguen pendientes.


## Build 17: catálogo y publicación

Portada compacta con búsqueda y filtros antes del catálogo, tarjetas con fotografías mayores y hasta ocho resultados iniciales. Las tarjetas y Ver todos respetan ahora filteredCars: antes los controles cambiaban el estado, pero la portada seguía mostrando cars sin filtrar. Se retira la etiqueta de vehículos verificados, que no correspondía a una comprobación garantizada.

La ficha mantiene el contacto en una barra fija con área segura y conserva WhatsApp, consulta de disponibilidad y bloqueo de contacto para vendidos. Se corrige el desbordamiento de Descripción en pantallas estrechas. Denunciar sigue accesible en cabecera y cuerpo.

El catálogo muestra filtros activos eliminables; al abrir filtros, la ordenación y los resultados ceden espacio a una lista desplazable y un botón fijo con el número de resultados. La cabecera se adapta a textos largos. Se conserva la búsqueda al aplicar y retirar filtros.

La publicación conserva el formulario y sus validadores. La ficha técnica ampliada y equipamiento se agrupan en un desplegable que mantiene los controladores y valores. Combustible permanece en los datos básicos. El botón principal de publicación ocupa el pie, con packs accesibles en la cabecera. Se puede elegir otra fotografía principal moviéndola a la primera posición sin eliminar fotos ni volver a seleccionarlas. Las nuevas instrucciones se traducen a es/en/ca.

Esta actualización no modifica tarifas ni la validación de compras. Sigue pendiente diagnosticar en iPhone el metadato USD que difiere de la hoja nativa EUR. Se conserva la protección de presentación de build 16 y no se afirma que la discrepancia esté resuelta. Sin cambios de servidor, activación global de moderación ni envío a revisión pública. La disponibilidad en TestFlight se registrará tras la subida y verificación en Apple.

Validación del lote 17: 95 pruebas Flutter correctas, compilación web de producción correcta y revisión visual del inicio y ficha a 390x844 con catálogo real en modo de solo lectura. Las fotos y el contacto fijo se presentan correctamente. El análisis no detecta errores de compilación; conserva avisos de estilo y deprecación anteriores. Pendientes compilación firmada iOS y prueba física en TestFlight.

El 2/11/2026 Codemagic compiló, firmó y subió 1.0.1 (17) desde 95dc97a1c142b31f6bb3317f198a8bb333cea614: https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae8b857e83a9019991c5d6d. Apple terminó de procesar la build 5a117a98-b0a6-4eb8-becb-bf76da596280. Tras la autorización expresa del titular, se guardó Ninguno de los algoritmos mencionados anteriormente y se asignó únicamente al grupo interno AUTOMOTORS Sandbox. La página del grupo confirma 1.0.1 (17) En pruebas, dos testers y caducidad de 90 días. Disponible en TestFlight. El error de posprocesado de Codemagic correspondía a la asignación previa a la declaración y quedó resuelto mediante estos pasos en Apple; no se reenvió el binario. No se ha enviado a revisión pública.


## Build 18: diseño claro aprobado

Se aplica a la app la dirección visual aprobada por el titular tras revisar la muestra de inicio, catálogo y ficha. El tema compartido usa fondo crema, superficies blancas, texto oscuro y dorado en acciones. Se migra el contenido principal y secundario que fijaba fondos oscuros o texto blanco; la galería ampliada conserva su lienzo negro y sus controles blancos. El icono original y el identificador de la app se mantienen.

MarketVehicleCard unifica la presentación del inicio y catálogo: fotografía grande, modelo y versión reales, precio oscuro y metadatos separados. Conserva navegación, favoritos, comparación y estados de reserva/venta. La portada introduce la cabecera editorial traducida, filtros redondos y tarjetas mayores. La ficha elimina el recuadro dorado del precio, ordena el resumen en dos columnas adaptadas al tamaño de texto y mantiene galería, miniaturas, datos técnicos, matrícula/VIN según permisos, denuncias y contacto fijo.

Validación: 98 pruebas Flutter correctas. Las nuevas verifican contraste mínimo 4.5:1 en texto y acciones principales, y las tres acciones independientes de tarjeta a 320 px con texto normal y ampliado al 150%. Las pruebas de filtros, contacto y formulario usan ahora el tema real. Compilación web de producción correcta; revisión visual con catálogo real en modo de solo lectura de inicio, catálogo, ficha y galería ampliada a 390x844. Las compras, sus importes de Apple, validación del servidor, permisos y moderación no se modifican. Sigue pendiente comprobar físicamente la discrepancia de metadatos USD frente a EUR. La compilación firmada y disponibilidad de 1.0.1 (18) se registrarán tras verificarse en Apple.

El 2/11/2026 Codemagic compiló, firmó y subió 1.0.1 (18) desde 153ae0554d58669ec78b1a7bb5117346e96104f1: https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae8e307e83a9019991c6ce3. El log confirma Build Number 18, IPA 27.5 MB y UPLOAD SUCCEEDED with no errors a las 19:29:08 UTC (20:29:08 Madrid). Apple procesó 171a2249-0fd9-4d3d-a4ee-fcddfd3129d7. Tras la autorización expresa del titular para esta build, se guardó Ninguno de los algoritmos mencionados anteriormente. Se añadió solo al grupo interno AUTOMOTORS Sandbox, y la página del grupo confirma 1.0.1 (18) En pruebas, caducidad de 90 días. La build está disponible en TestFlight. La asignación automática anterior de Codemagic había fallado por información de exportación pendiente; la asignación en Apple quedó completada sin reenviar el binario. La revisión pública de App Store y las pruebas físicas siguen pendientes.


## Build 19: composición, vendedor y precios EUR

El titular pidió aplicar el acabado completo y sustituir Consultar precio en Apple por importes en euros. El inicio integra titular, buscador y combustible en una superficie editorial; las tarjetas compactan modelo y precio en una fila cuando hay espacio y conservan disposición vertical con texto ampliado. Añaden contador de fotografías, entrada suave y favorito animado. Las animaciones respetan Reducir movimiento. La carga muestra un esqueleto estático accesible, sin actividad inventada.

El inicio ofrece Tus búsquedas y Guardar esta búsqueda utilizando las funciones existentes. Se restauran todos los filtros del registro, sin cambiar preferencias de notificación. El diálogo valida nombre no vacío, permite cancelar y conserva su controlador hasta terminar la salida. La ficha amplía la galería y añade una transición al abrir fotografías; el vendedor queda junto al resumen de compra. Solo lee full_name, business_name y city de public_seller_profiles, la misma vista pública existente; un fallo conserva el acceso al perfil sin inventar identidad ni distintivos de verificación. Se confirmó con el catálogo real que el nombre y localidad públicos se muestran. Sin migraciones ni cambios de permisos.

### Tarifas de España verificadas el 2/11/2026

Se consultaron las cuatro páginas de producto de App Store Connect, grupo 22517049, app 6827315199. Cada producto tiene duración de un mes y disponibilidad de un único país, España; el filtro de países disponibles muestra España (EUR):

| Producto | ID Apple | Precio mensual España |
| --- | --- | --- |
| automotors_pack_10 | 6827338470 | 59,00 EUR |
| automotors_pack_15 | 6827338063 | 75,00 EUR |
| automotors_pack_20 | 6827337711 | 99,00 EUR |
| automotors_pro_monthly_199 | 6827335055 | 199,00 EUR |

Las tarjetas iOS y web conservan el precio EUR coherente de StoreKit si está disponible. Para un SKU conocido cuyo período de StoreKit es un mes pero la moneda o formato es incoherente, muestran la tarifa española comprobada de forma independiente. Mientras carga el catálogo, pueden mostrar esa tarifa mensual pública, pero el botón de compra exige producto y período reales. Un producto desconocido o un período contradictorio no recibe un importe supuesto y queda sin contratación con ese comportamiento alternativo. No se cambian los objetos de compra, monedas recibidas, recibos ni verificación del servidor; no hay conversión de dólares ni sustitución de símbolos. Android conserva el catálogo de su tienda. Actualizar la instantánea de precios al cambiar tarifas de España o territorios. El origen de los metadatos USD de Sandbox sigue sin diagnosticarse; la corrección es de presentación de las tarifas españolas.

Validación del lote: 112 pruebas Flutter correctas, incluidas las cuatro tarifas, prioridad de EUR válido, SKU desconocido, período incompatible, formato dólar con código EUR, resumen del vendedor y fallos de lectura, movimiento reducido y cierre/cancelación del diálogo. Compilación web de producción correcta y revisión visual de inicio completo y planes a 390x844: se muestran 59,00, 75,00, 99,00 y 199,00 EUR por mes. Sin compras, denuncias ni búsquedas reales creadas en estas comprobaciones. Compilación/firma y disponibilidad de 1.0.1 (19) en TestFlight pendientes de verificar.

El 2/11/2026 se verificó que Codemagic había compilado, firmado y subido 1.0.1 (19) desde b4b3725a37daae872fa06605a02df5b7e7d9b085: https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae8ecd3e83a9019991c7068. Apple terminó de procesar 4f46f4f0-f42a-431c-8c65-261abfe87e86. El titular había autorizado expresamente el cifrado para esta build. Se guardó Ninguno de los algoritmos mencionados anteriormente y se asignó únicamente a AUTOMOTORS Sandbox. La página del grupo confirma 1.0.1 (19) En pruebas, dos testers y caducidad de 90 días. Build 19 disponible en TestFlight. La asignación automática de Codemagic había fallado antes del guardado de exportación; la activación se completó en Apple sin reenviar el binario. La compilación web del commit final también es correcta. Queda comprobar en el iPhone la presentación de importes y el nuevo diseño; no se ha realizado compra real, cambiado tarifas ni enviado a revisión pública.

## Build 20: búsqueda y comparación

Búsqueda por palabras en marca, modelo, versión, combustible, cambio y carrocería, normalizada sin tildes y con equivalencia VW/Volkswagen. Los atajos Automático (incluye DSG), SUV, Eléctrico y hasta 20.000 EUR se combinan con el resto de filtros. El catálogo permite filtrar también cambio y carrocería. Historial de ocho consultas enviadas, guardado solo en el dispositivo, recuperable y borrable; no se transmite al servidor.

Comparador con cabeceras persistentes durante el desplazamiento de características, acceso al anuncio, diferencias destacadas y opción Solo diferencias. Equipamiento comparado por elemento publicado: No indicado sigue siendo desconocido, nunca ausencia asumida. En pantallas pequeñas con texto ampliado, la cabecera tiene desplazamiento propio para dejar espacio a los datos. Traducciones ES/EN/CA de los nuevos controles.

Validación: 128 pruebas Flutter correctas; cubren filtros combinados, DSG, historial local, normalización, corrupción de preferencias, concurrencia, diferencias de equipamiento y diseño a 320x568 con texto al 100 y 150 por ciento. Compilación web de producción correcta; análisis sin errores, mantiene 64 avisos informativos/preexistentes. Revisión visual a 390x844 con catálogo real y Solo diferencias. Sin migraciones, permisos nuevos, compras ni escrituras de datos de usuarios. Build iOS y activación en TestFlight pendientes de verificar.

El 2/11/2026 Codemagic compiló, firmó y subió 1.0.1 (20) desde 9ed1fc00bc856d48b3f78b901e82f36ea55f34bd: https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae8fabce83a9019991c755b. Apple procesó UUID 1f04a24b-e90e-4d4e-963c-3f3917528d4c. Con autorización expresa del titular para la build 20 se guardó Ninguno de los algoritmos mencionados anteriormente y se añadió únicamente a AUTOMOTORS Sandbox, dos testers. La página del grupo confirma 1.0.1 (20) En pruebas y caducidad en 90 días: disponible en TestFlight. CI flutter-check y postgres-and-edge correctos; el job adicional de simulador iOS de GitHub sigue en cola, mientras la compilación nativa firmada de Codemagic ya terminó. Sin envío a revisión pública.

## Build 21 preparada: favoritos y avisos del comprador

Favoritos accesibles desde inicio, consulta de precios actuales al servidor y referencia capturada por el servidor (sin inventar un precio histórico para favoritos antiguos). Aviso por coche desactivado inicialmente y activable de forma individual; las referencias antiguas desconocidas se capturan cuando se activa el aviso. Las búsquedas guardadas permiten pausar anuncios nuevos y bajadas por separado. Contador de alertas sin leer, importes anterior/actual en el aviso y apertura del anuncio con precio actual; anuncios retirados fallan de forma controlada. Nuevos textos ES/EN/CA y prueba móvil con texto al 150 por ciento.

La migración local reemplaza los triggers antiguos, añade publicación de borrador a publicado, normalización de términos/VW/DSG, todos los límites numéricos, coincidencia exacta de equipamiento, prevención de avisos sobre anuncios retenidos y actualización de una alerta al producirse otra bajada. Los avisos permanecen en el buzón de la app: no se añade entrega por email ni APNs. Referencia de precio y contenido del buzón pertenecen al servidor; el cliente solo actualiza su preferencia del favorito y read_at del aviso bajo RLS existente.

Validación: 137 pruebas Flutter correctas y prueba Postgres aislada con datos ficticios (precio real del servidor, RLS entre cuentas, grants por columna, opt-in/pausa, bajadas repetidas, publicación, criterios inválidos y anuncios retenidos). Compilación web de producción correcta. Captura de la pantalla de favoritos a 390x844 con datos ficticios para revisión visual. Sin compras ni datos de prueba persistidos en producción.

El titular autorizó expresamente activar la migración. Se aplicó buyer_watchlists_and_price_alerts en Supabase y se verificaron columnas, trigger único, coincidencia DSG, rechazo de criterios inválidos y permisos: el cliente solo puede editar notify_price_drops del favorito y read_at del aviso. El trigger privado no es invocable por authenticated. La revisión de seguridad devuelve avisos preexistentes de tablas privadas sin políticas y protección de contraseñas filtradas, sin hallazgo nuevo atribuible a este lote.

Solicitud adicional: invitación al comprador para valorar la compra. La función invite_verified_buyer_review y queue_review_push ya estaban desplegadas y cron automotors-ios-push está activo cada minuto. Se añadió explicación al confirmar una venta y pruebas de regresión que verifican una invitación y un trabajo de push solo para el comprador, sin duplicación al repetir la actualización ni invitaciones para ventas externas. La alerta abre el formulario de valoración con comprobación del comprador.

APNs configurado con autorización expresa del titular para guardar la credencial en Supabase. La primera clave T988MS69S7 se registró, pero el archivo no se encontró tras la descarga del usuario; no se revocó ninguna clave. Se preparó un reemplazo Production, Topic Specific com.automotors.automotorsBase, equipo S7H5DAX4S4. El usuario completó Register; se descargó correctamente AuthKey_ZWDQPG7T66.p8, 257 bytes, EC prime256v1. Tras autorización específica, se guardaron APNS_PRIVATE_KEY, APNS_KEY_ID y APNS_TEAM_ID directamente como secretos, sin exponer el contenido en el chat ni incluirlo en el repositorio. Se confirmó la existencia de los tres secretos con el formulario vacío.

Cron automotors-ios-push sigue activo. La última ejecución posterior al guardado devuelve HTTP 200, processed=0 y accepted=0, sustituyendo el anterior 503 apns_not_configured. Una invitación antigua ya no pendiente se descartó; no se creó venta, valoración ni mensaje de prueba para usuarios reales. La prueba Postgres aislada confirma la invitación única y la cola solo del comprador. Cuatro pruebas de payload, rutas, firma ES256 y reintentos correctas. La entrega física al iPhone requiere una venta real confirmada y notificaciones activadas; no se ha afirmado una recepción que no se haya observado.

Codemagic compiló, firmó y subió 1.0.1 (21) desde 45b7e98dc3a18efd4212b853cd6c13485a527905: https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae9057ae83a9019991c78c2. Apple terminó de procesar UUID 1579983e-8835-4f34-980c-b019e9a5c4d0. Con autorización expresa del titular se guardó Ninguno de los algoritmos mencionados anteriormente y se añadió únicamente a AUTOMOTORS Sandbox. La página del grupo confirma 1.0.1 (21) En pruebas, dos testers y caducidad en 90 días: disponible en TestFlight. No se ha enviado a revisión pública.

## Build 22 preparada: foto del vendedor y recorrido de búsqueda

La ficha consultaba solo nombre, negocio y ciudad del vendedor, y el resumen dibujaba un icono fijo. Ahora solicita también profile_photo_path de la vista pública existente y muestra esa foto del bucket público profile-photos, con recorte circular, tamaño de caché acotado, descripción accesible y alternativa si falta o falla la imagen. Sin cambios de RLS, buckets ni permisos. La revisión de lectura en Supabase confirmó el campo de la vista y el carácter público del bucket. Se verificó con el catálogo real a 390x844 que la foto del vendedor aparece junto a su nombre y ciudad.

El catálogo permite guardar la búsqueda activa directamente desde su cabecera. Se guarda una instantánea de texto, filtros y límites reales; los límites de potencia/año desactivados se omiten para que no excluyan datos desconocidos. Conserva login, confirmación del nombre, cancelación y manejo de errores. Los favoritos permiten ordenar por guardado reciente, precio actual o año y comparar hasta tres coches disponibles; se retiran selecciones que dejan de existir o de estar disponibles tras actualizar. Acceso a la ficha desde el comparador conservado. Nuevos textos ES/EN/CA.

Validación: 141 pruebas Flutter correctas, incluidas foto ausente/fallida, guardado exacto de filtros, ordenación por precio actual y comparación de favoritos. Compilación web de producción correcta, revisión visual de ficha con foto real y controles móviles, sin compras ni escrituras de prueba en producción. Build nativa y activación de 1.0.1 (22) pendientes de verificar; no se ha enviado a revisión pública.

Codemagic compiló, firmó y subió 1.0.1 (22) desde 73bccf1d8fa866efc8299aaa7bc67a3b30b17db8: https://codemagic.io/app/6adfc9610f69aaef96f68807/build/6ae911a3e83a9019991c7c61. El titular autorizó expresamente Ninguno de los algoritmos mencionados anteriormente para esta build. Apple procesó UUID c35c01e5-2b70-4c6f-b0a8-287083bbccfa. Se guardó el cifrado autorizado y se añadió únicamente a AUTOMOTORS Sandbox. La página del grupo confirma 1.0.1 (22) En pruebas, dos testers y caducidad en 90 días: disponible en TestFlight. CI flutter-check y postgres-and-edge correctos; el job adicional de simulador iOS sigue en cola, mientras la build nativa firmada de Codemagic ya terminó. La sesión de App Store Connect se renovó por el titular. Sin envío a revisión pública.


## Build 23 preparada: diseño Editorial unificado

- Tema común claro con tinta verde oscuro y acentos dorados; jerarquía tipográfica, iconos, botones, formularios, diálogos y navegación coherentes.
- Inicio con titular Editorial, una tarjeta principal y filas secundarias compactas que conservan favoritos, apertura y estado reservado.
- Ficha móvil con fotos primero y título y precio debajo, según la última indicación; fotos a sangre, datos principales agrupados y vendedor con su foto. Se conserva la galería completa y el contacto fijo.
- Favoritos con cabecera Editorial, miniaturas mayores, comparación mediante casilla y avisos de precio accesibles. Se conservan ordenación y preferencias.
- Traducción de los nuevos textos a español, inglés y catalán. No cambia compras, precios verificados ni permisos del servidor.
- Verificación: 141 pruebas existentes aprobadas; 21 pruebas focalizadas aprobadas, incluidas 3 nuevas de tarjeta Editorial a 320 px con texto al 100 %, 150 % y 200 %.
- Compilación web release aprobada. Revisión visual real a 390 × 844 de inicio y ficha (fotos primero); favoritos revisados con datos ficticios y fuentes reales. Prueba adicional del orden fotos/título y del contacto fijo aprobada para publicado, reservado y vendido.
- Estado confirmado: **AUTOMOTORS 1.0.1 (23), En pruebas**, grupo interno **AUTOMOTORS Sandbox**, 2 testers, caduca en 90 días. Cifrado «Ninguno de los algoritmos mencionados anteriormente» guardado con autorización explícita del usuario.
- Binario: commit `01dc1a0ebc58dc8dde065d662133a0b0e38f1cbb`; Codemagic `6ae91d63e83a9019991c7f8f`; Apple build `ea2cf7ce-256d-4bd3-819b-804351283e7d`.
- GitHub: flutter-check, postgres-and-edge e iOS aprobados para ese commit. Codemagic compiló, firmó y subió correctamente; su asignación automática de grupo falló por faltar el cifrado y se completó manualmente tras guardarlo. No se envió a revisión pública.
- Este registro posterior a la activación solo cambia documentación; no requiere otro binario.


## Build 24 preparada: los seis puntos de acabado visual

- Fotos: tarjetas con área de imagen acotada a 4:3 cuando hay espacio, tamaño adaptado al ancho y texto, contador más discreto y favorito independiente sobre la foto. La galería de la ficha sigue primero y crece con el ancho.
- Inicio: una sola fila de filtros rápidos; combustible y demás opciones permanecen en el panel completo. Botón de filtros etiquetado para accesibilidad.
- Ficha: datos adicionales agrupados en Ficha técnica y Equipamiento desplegables, conservando cada valor y los controles de visibilidad de matrícula/VIN. Datos esenciales y contacto siguen accesibles.
- Vendedor: foto mayor en resumen y perfil, presentación existente resumida en cabecera y pestañas con el estilo común. Se conservan valoraciones reales y su lógica; sin indicadores inventados.
- Navegación: Publicar destacado con botón visual de alto contraste, conservando autenticación y destinos.
- Acabado: estados vacíos con icono, explicación y acción en inicio/favoritos; entrada suave de cargas y estados vacíos respetando movimiento reducido.
- Nuevos textos en ES/EN/CA. No cambia servidor, permisos ni precios/compras.
- Verificación: suite completa 145 pruebas aprobadas; tras el ajuste final de proporciones y agrupación, 25 pruebas focalizadas aprobadas, incluidos contacto fijo, privacidad de identificación y acciones separadas de tarjetas.
- Revisión visual real a 390 × 844: inicio con una fila de filtros, navegación destacada, fotos, vendedor con avatar mayor y ficha técnica desplegable. Compilación web release final aprobada.
- Estado confirmado: **AUTOMOTORS 1.0.1 (24), En pruebas**, grupo interno **AUTOMOTORS Sandbox**, 2 testers, caduca en 90 días. Declaración de cifrado guardada con la respuesta explícitamente autorizada «Ninguno de los algoritmos mencionados anteriormente».
- Binario: commit `3576a926210330ce1cd83a225fea72b03ed80775`; Codemagic `6aea356ea87b4d255fde3fd1`; Apple build `6a426204-6db6-485b-a0e9-86649df11cb9`.
- Codemagic compiló, firmó y subió la app correctamente. La asignación automática de grupo falló por faltar el cifrado; se completó manualmente tras guardarlo. GitHub flutter-check y postgres-and-edge aprobados; job iOS de GitHub cancelado, compilación nativa de Codemagic correcta. Sin envío a revisión pública.
- Este registro posterior solo cambia documentación y no requiere volver a generar el binario.


## Build 25 preparada: etiqueta en Emisiones

- Causa: la columna estirada de Ficha técnica imponía todo el ancho al SizedBox de la etiqueta y separaba los elementos del círculo.
- Corrección: alineación que libera el ancho del dibujo y conserva un disco cuadrado; tamaño de Emisiones aumentado a 72 px. Texto gráfico independiente del escalado de interfaz, letras acotadas sin salto de línea y zona ECO separada del QR/barra decorativos. Etiqueta accesible con nombre de categoría.
- Verificación: 15 pruebas focalizadas de etiqueta y ficha aprobadas; tras ajustar la posición de ECO, 8 pruebas de C/B/ECO/CERO con texto al 100/200 % aprobadas. Disco de 72 × 72 bajo columna de ancho completo, sin desbordamientos. Captura de componente con fuentes reales revisada.
- Estado confirmado: **AUTOMOTORS 1.0.1 (25), En pruebas**, grupo interno **AUTOMOTORS Sandbox**, 2 testers, caduca en 90 días. Cifrado guardado con la respuesta expresamente autorizada «Ninguno de los algoritmos mencionados anteriormente».
- Binario: commit `18d1973eb877024ff188568336b576c1838b3d43`; Codemagic `6aea516ba87b4d255fde493d`; Apple build `dc78bbb5-c762-4723-8af8-47c8f0ef9aee`.
- Flutter-check y postgres-and-edge de GitHub aprobados. iOS de GitHub cancelado; Codemagic compiló, firmó y subió correctamente. Asignación automática bloqueada pendiente de cifrado y completada manualmente tras guardarlo. Sin envío a revisión pública.
- Este registro solo cambia documentación y no requiere otro binario.


## Build 27 preparada: verificación, cuenta y favoritos (sustituye a 26)

- Registro/reenvío nativo iOS: retorno exacto `com.automotors.automotorsbase://auth/verify-email`, registrado en Info.plist. App Links recibe arranque en frío/en caliente; Flutter no procesa el enlace como una ruta normal.
- Se mantiene PKCE: el callback se canjea con el verificador local en un cliente efímero y solo confirma éxito si Supabase devuelve email confirmado. No persiste ni sustituye la sesión activa; revoca la sesión efímera y muestra Login con «Cuenta verificada. Ya puedes iniciar sesión.» y el correo validado. Errores y códigos caducados muestran recuperación/reenvío; no se acepta un parámetro `verified=true` ni tokens implícitos. Enlace repetido se procesa una sola vez.
- El SDK conserva su manejo habitual de otros callbacks de autenticación. No se ha desactivado la confirmación de email ni debilitado PKCE.
- Accesos a Eliminar mi cuenta y Administración añadidos al perfil propio y a Mis datos. El menú de ajustes permite abrir eliminación incluso si falla la carga del perfil. No se elimina nada al abrir: se conserva la confirmación ya implementada.
- `abdelmounimtg94@gmail.com`: identidad existente y correo confirmado comprobados. is_admin activado con petición explícita; ya tenía rol privado de moderación. El cliente no decide permisos por el correo; el acceso interno depende del RPC autorizado en servidor.
- Contador de favoritos en la ficha vía `listing_favorite_count`, solo un total agregado para anuncios visibles o propios. Respeta ocultaciones/moderación/cuenta activa; filas e identidades de quienes guardan permanecen bajo RLS. Reconsulta tras guardar/quitar, sin inventar cero ante un error.
- Verificación: 159 pruebas de suite completa, 41 focalizadas (incluidas las nuevas entradas y total para visitantes), 4 UI de confirmación ES/EN/CA y 6 de validación PKCE aprobadas. Prueba PGlite del agregado aprobada: anon, propietario, no propietario, borrador, oculto, moderación, inexistente y cuenta inactiva, sin acceso a usuarios que guardan.
- Agregado desplegado y verificado por API pública: total actual 2 y lectura de usuarios que guardan denegada. Entrada pública SECURITY INVOKER y función privada privilegiada con los mismos controles de visibilidad; advisors sin avisos nuevos de funciones expuestas. Se conservan avisos anteriores de tablas privadas sin políticas y protección de contraseñas filtradas desactivada (https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
- Callback exacto guardado en Redirect URLs de Supabase, sin comodines. Plantilla de confirmación estándar confirmada. Configuración nativa plist analizada correctamente.
- Pendientes: compilar y distribuir iOS 27. El enlace real correo→iPhone requiere comprobarlo físicamente tras instalar la nueva build.
- Bloqueo para registro público: Supabase usa SMTP de pruebas (solo destinatarios del equipo). El usuario no tiene dominio/proveedor; elección de dominio/correo profesional o Gmail provisional pendiente. No se han comprado servicios ni enviado correos de prueba reales.

- Revisión final: todo enlace con el esquema propio queda fuera del procesamiento automático del SDK, incluidos hosts/rutas/puertos/userinfo alterados. Solo el handler estricto valida la confirmación. Prueba adicional cubre estas variantes para evitar cambios inesperados de sesión.
- Build 26 (`6aea61c2a87b4d255fde4ec7`) compilada y subida, sin activar: sustituida por la corrección de enrutado de la build 27. La autorización recibida para 26 no se aplica a otro número de build.
- El usuario eligió Gmail provisional como SMTP; configuración y contraseña de aplicación pendientes de completar de forma privada.

## Activación de la build 27 y Gmail provisional

- Apple confirma 1.0.1 (27) «En pruebas» en AUTOMOTORS Sandbox, grupo interno de 2 testers; caduca en 90 días. Declaración de cifrado guardada tras autorización expresa para 27. No se ha enviado a revisión pública.
- Binario: commit `5b0ec25d88ccca151e0c6e576377bece496dfe36`; Codemagic `6aea6622a87b4d255fde5019`; Apple build `677e1271-1e89-4981-a34c-a0b46f4f98e1`.
- La build 26 sigue sin asignarse. Las 11 pruebas finales de callbacks y UI pasan, incluida la exclusión de todas las variantes del esquema propio del manejo automático del SDK.
- El usuario guardó privadamente la contraseña de aplicación de Gmail. Comprobación posterior en una página nueva: SMTP activado, host smtp.gmail.com y puerto 587 persistidos. No se leyó la contraseña ni se enviaron correos de prueba.
- Gmail es provisional. Pendiente comprobar físicamente recepción de correo y retorno a Login en el mismo iPhone con la build 27 instalada; no se considera validado el envío por haber guardado la configuración.
- Este registro cambia únicamente documentación y no requiere otro binario.
## Build 28 activa y build 29 preparada

- 1.0.1 (28) confirmada «En pruebas» en AUTOMOTORS Sandbox, 2 testers. Cifrado guardado con autorización específica del titular. Apple cd046e5d-50de-4b5b-9896-6bc65a8d36e4; Codemagic 6aeaeda7a87b4d255fde6f1e; binario a1b99e8955447ab7c170f50f6f1401c66a6fe144.
- Se retiran los accesos duplicados de datos/edición y eliminación del cuerpo del perfil; se conserva el menú superior y recarga tras editar.
- El usuario confirma en el iPhone la recepción del correo y retorno a la app con cuenta verificada.
- Build 29: portada y funciones profesionales para autónomos/empresas sin documentos ni aprobación. Se elimina el formulario y la insignia documental, sin autoconceder estado aprobado ni modificar roles, límites o compras. Políticas remotas revisadas: ya permiten escritura propia de portada y presentación profesional, sin depender de verificación. No requiere migración ni elimina documentos históricos.
- Chat: acceso al perfil público de la otra persona, obtenida desde buyer_id/seller_id de la conversación bajo RLS y comprobación de pertenencia. No abre datos privados ni modifica permisos.
- Ficha: fotos, título/precio, vendedor y datos principales, en ese orden; contacto fijo conservado.
- Validación: 34 pruebas de perfiles, chat y traducciones aprobadas; 7 pruebas de diseño aprobadas con orden y contacto en publicado/reservado/vendido. Análisis previo sin errores, con avisos heredados. Distribución 29 pendiente.
## Build 29 distribuida

- Apple confirma 1.0.1 (29) «En pruebas» en el grupo interno AUTOMOTORS Sandbox, 2 testers y 90 días. Respuesta de cifrado «Ninguno de los algoritmos mencionados anteriormente» guardada con autorización específica para 29. Sin envío a revisión pública.
- Binario: b64eebab54235d8f3a3183522fa3090bebf84982; Codemagic 6aeaf237a87b4d255fde7093; Apple f88b4469-59dc-407a-bacf-1926fad0c7a1. Codemagic compiló y subió; procesamiento y grupo comprobados por separado en Apple.
- Suite final completa: 171 pruebas aprobadas. Incluye perfiles profesionales sin documentos, resolución del otro participante y orden precio/vendedor/datos con contacto fijo. No se enviaron mensajes reales ni se crearon cuentas de producción para verificarlo.
- Pendiente revisión física del usuario en iPhone de los tres cambios nuevos. Registro documental posterior, sin nuevo binario.
## Build 30 distribuida: identidad profesional integrada en la portada

- Empresas y autónomos: avatar centrado, con su centro sobre el borde inferior de la portada. Razón social única debajo, seguida del tipo y ubicación. Se retira el nombre superpuesto en portada. Cabecera compartida entre perfil público y vista propia de datos.
- Razón social editable y guardada para ambos tipos profesionales; conserva nombre personal de contacto separado. Perfiles antiguos sin razón social conservan el nombre disponible hasta editarlo.
- Seis pruebas focalizadas aprobadas: centrado y nombres largos con texto 100/200 %, guardado profesional/particular y participante de chat. La suite completa anterior de 29 fue de 171 pruebas aprobadas.
- Estado confirmado: 1.0.1 (30) «En pruebas», AUTOMOTORS Sandbox, 2 testers, 90 días. Cifrado guardado tras autorización específica del usuario; sin revisión pública.
- Binario f37406ceb6c8ebf57cc00eee277baaf70069a139; Codemagic 6aeaf62ea87b4d255fde71cf; Apple ed49e61e-dcc5-4062-85a1-91ff9857019d. Compilación, subida, procesamiento y acceso interno comprobados.
- Este registro solo cambia documentación. Pendiente revisión física de la cabecera en iPhone.

## Build 31 solo iPhone
Confirmada En pruebas en AUTOMOTORS Sandbox, 2 testers, Apple c1029814-102a-4ea8-8b98-caf11fc7b5d0; Codemagic 6aeb02c1d6634fc362f17854; binario d9289ff. Cifrado autorizado guardado. Preparación pública detallada en APP_STORE_SUBMISSION.md, todavía sin envío a revisión. Diez pruebas de ayuda y eliminación aprobadas; textos públicos UTF-8 y enlace de eliminación actualizados.

## Build 32 disponible en TestFlight, 12 de noviembre de 2026

- Version 1.0.2 (32) confirmada En pruebas en AUTOMOTORS Sandbox, 2 testers y caducidad de 90 dias. Apple 096ff0df-3323-4d65-b4ab-d5899fef355d; Codemagic 6af4af979679c85ac0aebf48; binario 45956c860c209fac50c41f87fdae6c9642cea413.
- Declaracion de cifrado guardada tras autorizacion especifica del titular para 32. Instrucciones de prueba guardadas y grupo interno asignado. No se realizo un envio publico de esta build.
- Reutilizacion de descargas de fotos en la sesion mediante cache de 24 MiB, 128 entradas y 5 minutos, con aislamiento de sesion, deduplicacion de solicitudes simultaneas y reintento tras error.
- Perfil publico, garaje y chat abren fichas con portada primero y completan la galeria despues. Tarjetas y miniaturas limitan su resolucion de decodificacion. Nuevas fotos de avatar y portada se seleccionan a tamanos adecuados.
- Validacion local final de 35 pruebas y analisis estatico de los componentes modificados sin incidencias. Compilacion nativa y procesamiento de Apple completados. La comprobacion fisica en el iPhone queda para los testers.
- Prueba local de distribucion: testflight-build32-en-pruebas.png.


## Build 33: mejoras agrupadas de búsqueda, publicación, chat y seguimiento

- Versión preparada 1.0.2 (33). La versión pública 1.0.1 (31) sigue su revisión por separado.
- Catálogo: conserva texto, filtros combinados y orden en el dispositivo; añade orden por fecha real de publicación. Valida valores recuperados frente a los catálogos actuales.
- Publicación: guardado automático y botón Guardar borrador, separados por cuenta. Recupera datos del formulario al volver. Las fotografías se conservan en memoria durante la sesión; tras cerrar la app se solicita volver a seleccionarlas. No se guardan rutas arbitrarias ni fotos en preferencias. Se elimina el borrador local al conservar o publicar el anuncio en el servidor.
- Chat: respuestas rápidas y propuesta de visita con fecha y hora futuras. Preparan texto editable; el usuario decide enviarlo. Se respeta el bloqueo del chat y no se borra texto nuevo al finalizar un envío anterior.
- Perfil: muestra mes/año de alta junto a las valoraciones existentes y aclara que la información la facilita el vendedor.
- Favoritos: Solo bajadas de precio. Alertas: filtros Todas, Sin leer, Bajadas de precio, Anuncios nuevos y Valorar compra.
- Copias de interfaz en español, inglés y catalán. Pruebas de recuperación real del formulario, aislamiento por cuenta, orden del guardado/borrado, datos locales inválidos, filtros persistentes, respuestas y cancelación de visita.
- Validación: batería completa con 189 aprobadas y una prueba nueva de cancelación corregida; archivo focalizado posterior con sus 8 pruebas aprobado (190 casos cubiertos). SQL en PostgreSQL en memoria aprobado con roles anon/authenticated, vendedores ocultos/eliminados e inaccesibilidad del perfil privado. Consulta real: null seguro, cero formatos públicos inválidos.
- Migración 20261112122709_seller_public_membership_month desplegada y comprobada. RPC de lectura mínima, search_path vacío, EXECUTE revocado de PUBLIC y concedido solo a anon/authenticated. Su SECURITY DEFINER es intencional para leer exclusivamente el mes de alta de un vendedor que ya aparece en public_seller_profiles; no amplía SELECT sobre user_profiles. Los avisos 0028/0029 del asesor corresponden a esta API pública deliberada y probada: https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable y https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable . La advertencia de protección frente a contraseñas filtradas ya existía antes del cambio.
- Compilación nativa iPhone terminada y subida confirmada el 12 de noviembre. Codemagic 6af5b5149679c85ac0af121e (trabajo 36), duración nativa y subida 7m 53s, binario 42b982b. Apple ha procesado 1.0.2 (33), ID 28922aed-40c6-4277-8d50-4351e2f53599.
- Instrucciones de prueba guardadas en Apple. Declaración de cifrado «Ninguno de los algoritmos mencionados anteriormente» guardada tras autorización específica del titular para la build 33. Asignada al grupo interno AUTOMOTORS Sandbox: estado En pruebas confirmado, 2 testers y caducidad de 90 días. Disponible para instalar desde TestFlight. El titular confirma mediante «HECHO» haber completado la comprobación en iPhone de publicación, búsqueda, chat, perfil y favoritos/compras, sin comunicar incidencias.
- Captura de activación verificada: testflight-build33-en-pruebas.jpg. La versión pública 1.0.1 (31) no se ha sustituido con esta preparación.

- Comprobación posterior de distribución: Apple sigue mostrando 1.0.1 (31) Pendiente de revisión. La pantalla exige retirar esa versión del proceso de revisión para enviar otra compilación. El titular elige expresamente conservar la revisión actual. Se mantiene 1.0.1 (31) sin retirar ni sustituir; 1.0.2 (33) queda disponible en TestFlight para preparar como actualización tras el primer lanzamiento.


## Build 34: correo oficial de contacto

- Titular solicita cambiar el correo público a info@automotors.info y confirma Google Workspace como proveedor; dominio activado el 12 de noviembre de 2026.
- Fuente de contacto de la app y exportaciones ES/EN/CA de soporte, privacidad y condiciones actualizadas. Diez pruebas de soporte, compras y eliminación aprobadas; nueve enlaces mailto verificados.
- Páginas web de main actualizadas de forma aislada mediante los commits 4d290de, c2f9e4e y 09a7483. Despliegue de Pages completado y contacto oficial comprobado en soporte, privacidad y condiciones; los tres idiomas enlazan mailto:info@automotors.info.
- El titular indica que ha guardado privadamente la nueva contraseña de aplicación SMTP. Se observa visualmente info@automotors.info como remitente persistido al recargar Supabase; servidor smtp.gmail.com, puerto 587 y nombre AUTOMOTORS. No se leyó ni capturó la contraseña.
- Comprobaciones DNS iniciales de Google y Cloudflare devolvieron NXDOMAIN sin MX. El titular confirma que acaba de activar exactamente automotors.info. Una comprobación posterior de DNS de Google devuelve NOERROR y MX «1 smtp.google.com.». Se confirma también visualmente el usuario SMTP info@automotors.info persistido. La entrega real queda pendiente de la prueba solicitada al titular.
- La cuenta existente abdelmounimtg94@gmail.com conserva su identidad y sus permisos de administración/moderación. Este cambio afecta al contacto público y al remitente, no migra cuentas.
- Se prepara 1.0.2 (34) para TestFlight; la revisión pública 1.0.1 (31) se conserva por decisión del titular. Build 33 ya distribuida no se modifica.

- Build 34 lanzada en Codemagic, trabajo 37 / 6af5eafe9679c85ac0af2935, commit 9a410f7. En cola al registrar este punto. GitHub Actions 43260123186 aprobado: dependencias, localizaciones, batería completa de tests y compilación web. Kit de lanzamiento y creatividad de captación actualizados con el contacto oficial.

- Diagnóstico de entrega: dos solicitudes controladas a /auth/v1/recover para el Gmail del titular devolvieron HTTP 500. Los registros de auth identifican SMTP 535 / 5.7.8 Username and Password not accepted. No se cambió la contraseña de ninguna cuenta de AUTOMOTORS ni se crearon usuarios de prueba.
- La pestaña de Google controlada por el agente seguía con ah.autos01@gmail.com. El titular aclara que accede a info@automotors.info en otro navegador o en el móvil. Se le ha indicado generar allí una contraseña de aplicación de 16 caracteres de la cuenta oficial y guardarla privadamente en SMTP_PASSWORD, sin espacios. Pendiente confirmación «clave de aplicación guardada» y una nueva prueba tras esa corrección real. No repetir intentos con las mismas credenciales rechazadas.
- Build 34 sigue en cola de Codemagic al dejar el paso privado al titular. Pestañas de SMTP y trabajo de compilación conservadas para continuar. El correo público y el kit de lanzamiento sí están actualizados; la entrega SMTP todavía no está verificada.


## SMTP verificado y build 35: recuperación de contraseña

- Se completó la verificación en dos pasos de Google Workspace y el titular generó y guardó privadamente una contraseña de aplicación de info@automotors.info. La nueva prueba /auth/v1/recover devuelve HTTP 200. El titular confirma recepción desde info@automotors.info; los errores SMTP 535 anteriores están resueltos.
- Build 34 terminó compilación, subida y procesamiento (Apple 77bf6b4b-5ed5-4fa6-82d3-d9ae824e124f). Su postproceso de grupo falló por falta de declaración de cifrado. No se repite: queda sustituida por la preparación de 35, que agrupa también la recuperación solicitada.
- Login añade He olvidado mi contraseña. Flujo: correo, código recovery de un solo uso y nueva contraseña confirmada (mínimo 8 caracteres). Sesión efímera aislada, validación de email, PKCE con almacenamiento en memoria, limpieza al salir y reintento de actualización sin consumir el código otra vez. No modifica el login principal ni la confirmación de registro.
- Solo la plantilla Reset password de Supabase se cambia a código {{ .Token }}, con instrucciones ES/EN/CA y contacto oficial. Guardado confirmado en el editor. No se modifica la plantilla de alta.
- Pruebas usan exclusivamente HTTP simulado y cuentas example.test. Ninguna contraseña real de usuarios se ha cambiado. Pendiente comprobación física del recorrido completo por el titular cuando 35 esté disponible.
- La revisión pública de 1.0.1 (31) se conserva. Todavía no se guarda cifrado ni se distribuye 35.

- Validación de 35: 198 pruebas Flutter aprobadas (batería completa), incluidos ocho casos nuevos de recuperación y los once casos de confirmación/login. Análisis estático de los dos componentes nuevos sin incidencias.

- Build 35 lanzada en Codemagic, trabajo 38 / 6af5f9749679c85ac0af2f0d, fuente 422893d. Esperando Mac mini M2. Sesión de Apple recuperada por el titular y autorización específica de cifrado para 35 recibida; pendiente procesamiento y activación interna.


## Rechazo de Apple del 12 de noviembre y correcciones en preparación para 36

- Apple rechazó 1.0.1 (31) a las 18:07 CET por 1.2 (UGC) y 2.3.7 (capturas con precios de servicios). Ya no está pendiente de revisión. No se ha reenviado ni se ha respondido al revisor todavía.
- Revisor exige vídeo capturado en dispositivo físico mostrando aceptación de condiciones antes de login/registro, denuncia y bloqueo; debe incluirse también en las notas de siguientes envíos.
- Se retiró únicamente IMG_8696.PNG (packs con precios) del conjunto iPhone Dynamic Island grande; permanecen IMG_8694.PNG e IMG_8695.PNG. El gestor confirma dos capturas. La imagen retirada permanece en la biblioteca recuperable.
- Titular confirma asumir revisión en 24 horas. Condiciones de tolerancia cero y consentimiento deliberado preparados en ES/EN/CA, obligatorios antes de login y registro. Recuperación de contraseña accesible sin autenticar.
- Corrección de bloqueo: política SELECT restrictiva para ocultar al bloqueado solo al bloqueador, aviso privado idempotente en chat_reports y datos de identidad verificados por el RPC. Aprobada explícitamente y desplegada tras bloqueo inicial de revisión automática; trigger activado confirmado. Prueba en PostgreSQL aislado: ocultación persistente, aislamiento entre compradores, bloqueo repetido, moderador autorizado, no acceso privado y reversibilidad.
- Interfaz 36 retira inmediatamente tarjetas al bloquear y recarga desde el servidor con protección frente a cargas anteriores. Los avisos llegan a la cola Administración; no se ha añadido un nuevo canal de correo/push para moderación.
- Los asesores de seguridad conservan los avisos anteriores (tablas privadas con RLS sin acceso directo, RPC público mínimo de mes de alta y protección de contraseñas filtradas desactivada). No se presenta como ausencia total de avisos.
- Pendiente antes de reenvío: revisar cobertura de suspensión de usuarios (actual control restringe chat y permite ocultar anuncios por caso), verificar y activar exigencia global de moderación después de la prueba física; private.content_moderation_enabled() continúa false. No declarar implementados esos puntos hasta resolverlos.
- Build 35 mantiene fuente 422893d, ya empezó preparación de máquina a las 19:01 CET tras la cola. Su cifrado específico está autorizado; todavía sin procesar/activar. 36 aún no lanzada: primero se valida el paquete y se cierra la revisión de requisitos de Apple.

- Validación de las correcciones preparadas para 36: batería completa Flutter 203/203 aprobada, análisis estático de los componentes nuevos sin incidencias. Migración registrada en servidor como 20261112180010; archivo local y prueba alineados. No hay nuevos avisos relevantes del asesor de seguridad respecto a los ya documentados.


## Build 35 activada en TestFlight

- Confirmada 1.0.2 (35) En pruebas en AUTOMOTORS Sandbox, grupo interno con 2 testers y caducidad de 90 días. Apple ca5bcd00-f7c0-4cf1-94b6-2a29abd917ed; Codemagic 6af5f9749679c85ac0af2f0d, índice 38, fuente 422893d.
- Compilación y subida completadas en 7m 4s después de la espera de máquina. Apple procesó el binario; declaración de cifrado específica para 35 guardada con la autorización recibida. Instrucciones de recuperación y contacto oficial guardadas; grupo asignado y disponibilidad confirmada en su pestaña Compilaciones.
- Captura local: testflight-build35-en-pruebas.jpg. No se cambia la contraseña de ninguna cuenta real. El titular debe comprobar el recorrido completo en el iPhone.
- Las condiciones públicas de main se actualizaron de forma aislada mediante 315a1a10da918dc2529227f8a3e374ed530f7134; página de términos verificada con tolerancia cero y compromiso de 24 horas en ES/EN/CA.
- Correcciones preparadas para 36 guardadas en a9de8e7 (203 pruebas aprobadas), todavía no compiladas ni distribuidas. Mantener pendientes la suspensión completa, la exigencia global del filtro y la grabación física que Apple solicita. No se ha respondido ni reenviado la versión pública rechazada.


## Build 36: cierre de los requisitos de seguridad de Apple

- El titular confirma que la recuperación de contraseña funciona en el iPhone con 35. Tras una demora de disponibilidad y reasignación autorizada al grupo, la build apareció. Consulta a Apple enviada con autorización expresa, caso 30000013639219. No se atribuye su resolución a una causa técnica no confirmada.
- Preparada suspensión de cuenta por caso denunciado, separada de restringir chat. Exige confirmación y motivo; reversible, privada y auditada. Protege al titular, administradores y moderadores. No suspende automáticamente ninguna cuenta.
- Marca privada aplicada al guard de acceso existente y al chat; oculta anuncios, perfil público, descripción y reseñas. Los RPC de publicación y aprobación manual rechazan cuentas suspendidas, incluso con sesiones antiguas. Las pruebas PostgreSQL comprueban todos esos caminos con usuarios ficticios, sin tocar cuentas reales.
- La app consulta solo su propio estado en inicio/renovación de sesión y al volver a primer plano. Una suspensión confirmada cierra la sesión y renueva la navegación pública; un error de red al consultar el estado no se presenta como suspensión. Descarta respuestas que pertenecen a otra sesión.
- Prueba real del filtro el 12/11/2026 a las 18:54:43 UTC: HTTP 200, connected=true, text_checked=true, image_checked=true, modelo omni-moderation-2024-09-26. Texto ficticio e imagen gris de la función probe, sin anuncios ni fotos reales. Se utilizó la credencial existente solo en memoria/campo privado; no se imprimió ni guardó en archivos. Campos y portapapeles limpiados y pestañas de claves cerradas. Los fallos previos de la prueba eran de autenticación/copia del panel, no un resultado del proveedor.
- Los cuerpos de las siete funciones preexistentes que reemplaza la migración coinciden por hash con sus fuentes antes de aplicar el cambio. Aún pendiente autorización/despliegue y activación de exigencia global del filtro.
- La comprobación de inventario actual devuelve cero anuncios en todos los estados; activar la exigencia no ocultará anuncios existentes. No se ha creado inventario ficticio en producción.
- Pendientes para el envío público: instalar 36, prueba física de aceptación/denuncia/bloqueo, grabación en iPhone requerida por Apple e incorporar el vídeo a las notas y a la respuesta de revisión. No se ha respondido ni reenviado a Apple durante esta preparación.

- Validación final 36: 212 pruebas Flutter aprobadas, análisis de componentes nuevos sin incidencias y pruebas PostgreSQL de suspensión y moderación aprobadas. La solicitud de apply_migration caducó antes de ejecutarse; no se considera desplegada.

- Build 36 lanzada en Codemagic: índice 39, trabajo 6af60dff9679c85ac0af36da, commit 5f57df9. En cola al registrar este punto. Se solicitan autorización concreta para despliegue+filtro y declaración de cifrado 36; todavía no se consideran concedidas. Guion físico local preparado en Apple-video-build36.md, sin grabación ni respuesta a Apple enviada.


## Despliegue autorizado de 36 y filtro obligatorio

- El titular autoriza explícitamente la suspensión reversible, la exigencia del filtro y la declaración de cifrado 36. El conector apply_migration volvió a caducar sin ejecutar cambios. Se usó el editor SQL del proyecto con la misma migración probada, dentro de una transacción, y se registró su versión 20261112183747 en el historial de migraciones.
- El primer intento transaccional fue detenido por el control de antigüedad de la prueba del proveedor, sin cambios aplicados. Se repitió probe con frase e imagen ficticias: HTTP 200 y texto/imagen correctos a las 21:17:39 UTC del 12/11/2026. Campos de credencial limpiados y pestaña de claves cerrada.
- Despliegue final confirmado: moderation_required=true, suspended_accounts=0, migration_recorded=true. No se suspendió ninguna cuenta. Las cuatro políticas de visibilidad de suspensión están presentes. Las cuentas normales no pueden ejecutar el RPC reservado que prepara la comprobación y los anónimos no pueden consultar el estado de una cuenta.
- Los cuerpos de las diez funciones de la migración coinciden por hash con lo desplegado. El asesor conserva los avisos anteriores; se añade una tabla privada con RLS sin políticas de lectura directa de forma intencional. No hay nuevos WARN relativos a este cambio.
- Apple ha procesado 1.0.2 (36), UUID 0fe73dbb-27d3-40b6-981f-bbb13178825f. Pendiente guardar el cifrado autorizado y asignar el grupo interno. El fallo de postproceso automático de Codemagic es la falta de estado asignable por cifrado; el binario está subido y procesado.

## Activación final de TestFlight 36

- Guardada la declaración de cifrado autorizada: Ninguno de los algoritmos mencionados anteriormente.
- Guardadas las instrucciones de prueba de aceptación, denuncia, bloqueo, suspensión reversible y publicación moderada.
- Build 1.0.2 (36) asignada al grupo interno AUTOMOTORS Sandbox, dos testers. Verificada en la tabla del grupo como En pruebas, caduca en 90 días. Se conservan 35 y las compilaciones anteriores.
- Comprobante local: testflight-build36-en-pruebas.jpg. El despliegue de servidor está completo; las referencias anteriores a autorización o despliegue pendiente son hitos históricos superados por este cierre.
- Continúan pendientes la instalación y validación física en el iPhone, el vídeo requerido por Apple y el siguiente envío público. No se ha reenviado la app ni declarado realizada la prueba física.
