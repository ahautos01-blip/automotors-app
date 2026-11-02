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
