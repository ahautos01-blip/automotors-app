# Preparación de AUTOMOTORS para App Store

## Estado en el repositorio

- La experiencia de navegación web ya incluye el botón «Ver vehículos» en el bloque principal y la pantalla completa ordena primero los anuncios destacados.
- El acceso para publicar vehículos aparece una sola vez en la zona de acciones.
- Flutter tiene el plugin `in_app_purchase` y los identificadores previstos en `PRODUCTS.md`.
- Las compras permanecen desactivadas (`checkoutEnabled = false`). No existe todavía la función Supabase `verify-store-purchase` ni el receptor de App Store Server Notifications V2. El cliente no concede suscripciones por una respuesta local de StoreKit.
- Ya está generado el proyecto nativo `ios/Runner.xcodeproj`, el workspace, el `Info.plist`, el delegado Swift y los recursos iniciales de lanzamiento. El nombre visible está configurado como AUTOMOTORS y se declara el acceso a la fototeca.
- El identificador de paquete generado (`com.automotors.automotorsBase`) es provisional: hay que confirmar que está registrado y disponible en la cuenta Apple Developer. Los iconos incluidos son recursos de plantilla y deben reemplazarse por el icono final de AUTOMOTORS.

## Trabajo requerido antes de habilitar compras

1. Crear y registrar el identificador de paquete iOS definitivo en la cuenta Apple Developer y aplicarlo al proyecto Xcode.
2. Reemplazar los iconos de plantilla por el icono final, completar política de privacidad y URL de soporte, y configurar certificados/perfiles de firma.
3. Crear en App Store Connect el grupo y las cuatro suscripciones de `PRODUCTS.md`; validar precios, territorios, localizaciones y el valor recurrente que reciben los concesionarios.
4. Implementar la verificación de transacciones firmadas de Apple en Supabase, asociar de forma segura el `appAccountToken` al usuario AUTOMOTORS y actualizar `user_subscriptions` de forma idempotente.
5. Añadir el endpoint público de notificaciones V2, validar la firma JWS y procesar renovaciones, periodo de gracia, expiración, reembolsos y revocaciones.
6. Implementar restauración y gestión de suscripciones en la app, y habilitar compras solo después de que el backend esté desplegado y probado en Sandbox/TestFlight.
7. Preparar capturas, metadatos, cuenta de revisión y notas para Apple; probar flujos de alta, renovación, cambio de plan y cancelación en dispositivos reales.

Los planes venden capacidad de publicar anuncios y mayor visibilidad dentro de AUTOMOTORS. Apple exige In-App Purchase para compras digitales que desbloquean funciones de la app, incluidas compras de anuncios que se muestran en la misma app. Revisar las reglas vigentes antes de enviar y describir claramente el valor continuo de cada suscripción.

Referencias oficiales:

- [App Review Guidelines, secciones 2.1, 3.1.1 y 3.1.2](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- [Validar compras con el App Store](https://developer.apple.com/documentation/storekit/validating-receipts-with-the-app-store)
- [Recibir App Store Server Notifications](https://developer.apple.com/documentation/AppStoreServerNotifications/receiving-app-store-server-notifications)
