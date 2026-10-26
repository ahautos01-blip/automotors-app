# Preparación de AUTOMOTORS para App Store

## Estado en el repositorio

- La experiencia de navegación web ya incluye el botón «Ver vehículos» en el bloque principal y la pantalla completa ordena primero los anuncios destacados.
- El acceso para publicar vehículos aparece una sola vez en la zona de acciones.
- Flutter consulta el precio localizado de cada producto, ofrece restaurar compras y nunca concede acceso por una respuesta local de StoreKit.
- Las compras permanecen desactivadas (`checkoutEnabled = false`) hasta desplegar y configurar el backend y probar Sandbox/TestFlight. El cliente muestra el precio localizado desde la tienda cuando el producto está disponible, y nunca concede acceso por una respuesta local de StoreKit.
- El repositorio contiene `verify-store-purchase`, `app-store-server-notifications` y la RPC `apply_verified_store_subscription`; todavía no se han desplegado en Supabase ni aplicado a la base de datos.
- Ya está generado el proyecto nativo `ios/Runner.xcodeproj`, el workspace, el `Info.plist`, el delegado Swift y los recursos iniciales de lanzamiento. El nombre visible está configurado como AUTOMOTORS y se declara el acceso a la fototeca.
- El identificador de paquete generado (`com.automotors.automotorsBase`) es provisional: hay que confirmar que está registrado y disponible en la cuenta Apple Developer. Los iconos incluidos son recursos de plantilla y deben reemplazarse por el icono final de AUTOMOTORS.

## Trabajo requerido antes de habilitar compras

1. Crear y registrar el identificador de paquete iOS definitivo en la cuenta Apple Developer y aplicarlo al proyecto Xcode.
2. Reemplazar los iconos de plantilla por el icono final, completar política de privacidad y URL de soporte, y configurar certificados/perfiles de firma.
3. Crear en App Store Connect el grupo y las cuatro suscripciones de `PRODUCTS.md`; validar precios, territorios, localizaciones y el valor recurrente que reciben los concesionarios.
4. Crear una clave de **In-App Purchase** en App Store Connect (`Users and Access > Integrations > In-App Purchase`). La API key App Store Connect usada por Codemagic no sustituye a esta clave.
5. Configurar en Supabase los secretos `APPLE_IAP_PRIVATE_KEY`, `APPLE_IAP_KEY_ID`, `APPLE_IAP_ISSUER_ID`, `APPLE_STORE_ENVIRONMENT`, `IOS_BUNDLE_ID`, `APPLE_APP_ID` (producción) y las raíces públicas Apple CA G2/G3 en Base64.
6. Aplicar `202610230001_ad_pack_payments.sql` en una rama de desarrollo, desplegar ambas funciones Edge y configurar App Store Server Notifications V2 con `verify_jwt=false` únicamente para el receptor firmado.
7. Probar compras, restauración desde la pantalla de planes, renovaciones, periodo de gracia, cancelaciones, expiración, reembolsos, reintentos y duplicados en Sandbox/TestFlight. Mantener `checkoutEnabled = false` hasta validar estos flujos.
8. La validación de Google Play aún no está implementada; Android permanece sin compras activas hasta añadir su validador y credenciales oficiales.
9. Preparar capturas, metadatos, cuenta de revisión y notas para Apple; probar flujos de alta, renovación, cambio de plan y cancelación en dispositivos reales.

Los planes venden capacidad de publicar anuncios y mayor visibilidad dentro de AUTOMOTORS. Apple exige In-App Purchase para compras digitales que desbloquean funciones de la app, incluidas compras de anuncios que se muestran en la misma app. Revisar las reglas vigentes antes de enviar y describir claramente el valor continuo de cada suscripción.

Referencias oficiales:

- [App Review Guidelines, secciones 2.1, 3.1.1 y 3.1.2](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- [Validar compras con el App Store](https://developer.apple.com/documentation/storekit/validating-receipts-with-the-app-store)
- [Recibir App Store Server Notifications](https://developer.apple.com/documentation/AppStoreServerNotifications/receiving-app-store-server-notifications)
