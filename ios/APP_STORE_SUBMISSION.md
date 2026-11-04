# App Store: preparación del primer envío

Estado: no enviado. Versión pública preparada 1.0.1; build 30 seleccionada provisionalmente. El titular elige primer lanzamiento solo iPhone; build 31 debe sustituir a 30.

## Guardado en App Store Connect
- Nombre AUTOMOTORS; subtítulo Compra y vende coches; categoría Compras.
- Descripción, palabras clave, copyright y contacto de revisión guardados.
- Cuenta de revisión creada y guardada directamente por el titular. No registrar ni leer su contraseña; no hacer snapshots completos de la ficha con credenciales.
- Enlace de soporte: https://ahautos01-blip.github.io/automotors-app/support.html
- Privacidad: https://ahautos01-blip.github.io/automotors-app/privacy.html
- Precio de descarga 0 EUR, base España, disponibilidad inicial España.
- Clasificación calculada 9+: UGC, mensajería y promoción pagada; palabras groseras poco frecuentes. Sin acceso web libre ni funciones de red social. Guardado.
- Derechos de terceros confirmados expresamente por el titular y guardados.
- Privacidad publicada tras aceptación expresa del titular: 15 categorías vinculadas a la identidad, funcionalidad; búsquedas e interacción también personalización; sin seguimiento publicitario. Contacto, ubicación aproximada, mensajes, fotos, soporte, contenido, búsquedas, identificadores de cuenta/dispositivo, compras, interacción y otros datos fiscales/vehículo.

## Sitio público
Páginas exportadas desde el contenido de la app. El titular autorizó publicar nombre, correo, teléfono y dirección en ahautos01-blip/automotors-app y GitHub Pages. Publicación inicial main 6ecb795c934899b11293f417841058cb7c83f961; corrección posterior de codificación y ruta actual. Privacidad respondió 200 y contenido nuevo; verificar despliegue de la corrección.

## Pendientes antes del envío
- Build 31 iPhone-only: compilar, subir, procesar, cifrado específico y seleccionar en versión 1.0.1.
- Capturas reales del iPhone con Dynamic Island (pantalla mediana) requeridas por la validación de Apple. No hay capturas subidas. No presentar imágenes de pruebas como capturas nativas observadas.
- Captura de la pantalla de planes para revisión de las cuatro suscripciones (actualmente En preparación para el envío); revisar y adjuntar productos al primer envío. PRO, PACK20, PACK15, PACK10 observados, con descripción española existente y regiones limitadas a España. No se han cambiado precios.
- La validación de Añadir a revisión, tras metadatos/precio/derechos, devolvió solo capturas de iPad13 e iPhone. iPad se elimina del alcance por elección del titular con build31, no antes.
- Comprobar contratos, datos fiscales y bancarios si Apple los requiere; cualquier aceptación legal o credencial requiere intervención/autorización según la acción. No declarar App Store publicado hasta confirmar revisión y disponibilidad.
- Exigencia global de moderación sigue pendiente de auditoría de lanzamiento según registro histórico; no se ha activado al preparar metadatos.

## Privacidad de la cuenta de revisión
El titular introdujo la contraseña directamente en Apple y confirmó guardado. Para campos públicos de la ficha, usar locators concretos. No leer input password ni snapshots completos de AX. body.innerText no incluye valores de inputs y permitió leer errores de validación sin acceder a credenciales.

## Avance 4 de noviembre de 2026
- Build 31 solo iPhone compilada, subida y confirmada En pruebas en AUTOMOTORS Sandbox (2 testers). Apple c1029814-102a-4ea8-8b98-caf11fc7b5d0; Codemagic 6aeb02c1d6634fc362f17854; código d9289ff. Cifrado específico autorizado y guardado.
- Pendiente sustituir la selección provisional 30 por 31 en la ficha pública y repetir validación. No se ha enviado a revisión ni publicado en App Store.
- Notas de revisión de PRO/PACK20/PACK15/PACK10 guardadas; faltan capturas de revisión para los productos y adjuntarlos al envío.
- Política pública corregida y comprobada: HTTP200, títulos UTF-8, instrucciones actuales de eliminación. Commit main 73662db515b144b59dc93bc2fc978de4c8c622eb. No se ha integrado el resto de la rama en main.
- El titular dispone de iPhone 17 Pro Max. No existe control remoto de ese dispositivo en esta sesión; debe aportar capturas reales de TestFlight. Apple admite 1320x2868 entre los tamaños del grupo Dynamic Island grande. Ver https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications . Verificar dimensiones y aceptación del grupo mediano al subir; no inventar capturas de ejecución nativa.
- Auditoría de moderación: enabled=false, conexión de texto/imagen probada el 1 de noviembre; anuncios actuales 1 publicado y 1 vendido, ambos sin comprobación registrada. No activar a ciegas porque ocultaría el contenido legado. Resolver despliegue global antes de lanzamiento; cliente actual sí llama al filtro al publicar.