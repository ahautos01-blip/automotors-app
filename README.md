# AUTOMOTORS — app Android + iPhone, suscripciones nativas (sin cobros reales)

## Modelo comercial acordado

Los cuatro productos son suscripciones auto-renovables mensuales que se compran exclusivamente dentro de la aplicación, mediante App Store en iOS y Google Play Billing en Android.

- Primeras 5 publicaciones gratuitas por usuario.
- PACK 10: 59 €/mes; hasta 10 anuncios activos mientras esté vigente.
- PACK 15: 75 €/mes; hasta 15 anuncios activos mientras esté vigente.
- PACK 20: 99 €/mes; hasta 20 anuncios activos mientras esté vigente.
- AUTOMOTORS PRO: 199 €/mes; anuncios ilimitados mientras esté vigente.
- Los precios son precios objetivo para España y deben confirmarse en las consolas de las tiendas. Las comisiones se descuentan de los ingresos; no se garantiza recibir el precio íntegro.
- Las tiendas liquidan las ventas según sus calendarios a la cuenta bancaria configurada por el titular en cada plataforma. No se guardan datos bancarios en AUTOMOTORS.

## Arquitectura prevista

- Flutter: dependencia `in_app_purchase` y servicio `lib/services/store_purchase_service.dart` añadidos; las tarjetas de planes están conectadas al servicio, pero las compras siguen bloqueadas deliberadamente (`checkoutEnabled = false`).
- iOS: StoreKit/App Store mediante el plugin Flutter de compras dentro de la aplicación.
- Android: Google Play Billing mediante el plugin Flutter de compras dentro de la aplicación.
- Supabase Edge Functions: verificación de transacciones contra las APIs oficiales de Apple y Google; recepción de notificaciones de servidor.
- PostgreSQL/Supabase: estado de suscripción por usuario, tienda y producto; registro idempotente de eventos de tienda; control de límites de publicación.
- El cliente nunca decide que una compra está pagada. Solo el servidor activa, renueva, suspende o revoca permisos tras validar la fuente oficial.

## Estado actual

Los botones de compra siguen bloqueados y no se procesan cobros reales. La migración `supabase/migrations/202610230001_ad_pack_payments.sql` define las tablas de suscripciones nativas y eventos de tienda. La migración `supabase/migrations/202610260003_enforce_listing_limits.sql` añade una propuesta de límite de publicaciones del lado del servidor y depende de la primera migración.

**Ninguna de estas dos migraciones nuevas se ha aplicado a la base de datos de producción.** Deben revisarse y probarse primero en un proyecto de pruebas. No ejecutar a ciegas en producción.

Pendiente: implementar y desplegar `verify-store-purchase` con credenciales oficiales de Apple/Google, procesar notificaciones de renovación/cancelación/reembolso, probar los límites en servidor y completar las pruebas en sandbox. No se deben habilitar compras reales hasta terminar esos pasos.

## Reglas de acceso que debe aplicar el servidor

1. Las primeras cinco publicaciones gratuitas se calculan por cuenta de usuario, no por dispositivo.
2. PACK 10/15/20 permiten hasta el número correspondiente de anuncios activos mientras la suscripción tenga acceso vigente.
3. AUTOMOTORS PRO permite anuncios ilimitados mientras la suscripción esté activa o en el periodo de gracia confirmado por la tienda.
4. Cancelar la renovación conserva el acceso hasta la fecha de expiración confirmada.
5. Compras pendientes no habilitan el plan. Reembolsos, revocaciones y expiraciones actualizan el acceso.
6. El límite debe comprobarse y aplicarse en el servidor al publicar, para evitar publicaciones simultáneas que excedan el plan.
7. Las transacciones y notificaciones se procesan idempotentemente para evitar conceder permisos dos veces.
8. Si una suscripción expira y el usuario tiene más anuncios activos que el nuevo límite, el sistema debe aplicar una política de transición explícita; no borrar anuncios automáticamente sin una decisión de producto.

## Configuración pendiente de las tiendas

1. Crear los cuatro productos como suscripciones mensuales auto-renovables en App Store Connect y Google Play Console.
2. Confirmar IDs, precios, periodos, grupos de suscripción y ofertas/base plans.
3. Configurar credenciales de Apple y Google como secretos de Supabase. Nunca colocarlas en el cliente Flutter ni compartirlas por chat.
4. Configurar App Store Server Notifications V2 y Google Play Real-time developer notifications.
5. Probar compras aprobadas, pendientes, fallidas, restauradas, renovaciones, cancelaciones, periodos de gracia, expiraciones, reembolsos y revocaciones.
6. Activar ventas reales únicamente después de completar pruebas y revisar las normas vigentes de ambas tiendas para España.

## Seguridad

No compartir claves privadas, archivos de firma, credenciales de tienda ni datos bancarios. No habilitar permisos por valores enviados por el cliente. El backend debe verificar con Apple o Google antes de actualizar los permisos del usuario.
