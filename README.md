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

- Flutter: dependencia oficial `in_app_purchase` añadida y servicio inicial `lib/services/store_purchase_service.dart` para consultar productos y escuchar resultados. El checkout está bloqueado deliberadamente (`checkoutEnabled = false`) hasta desplegar y probar el verificador real de servidor.
- iOS: StoreKit/App Store mediante el plugin Flutter de compras dentro de la aplicación.
- Android: Google Play Billing mediante el plugin Flutter de compras dentro de la aplicación.
- Supabase Edge Functions: verificación de transacciones contra las APIs oficiales de Apple y Google; recepción de notificaciones de servidor.
- PostgreSQL/Supabase: estado de suscripción por usuario, tienda y producto; registro idempotente de eventos; control de límites de publicación.
- El cliente nunca decide que una compra está pagada. Solo el servidor activa, renueva, suspende o revoca permisos tras validar la fuente oficial.

## Estado actual

Los botones de compra siguen desactivados y no se procesan cobros reales. La migración `supabase/migrations/202610230001_ad_pack_payments.sql` define la base para el estado de suscripciones nativas y el registro de eventos de tienda. Revisar y aplicar primero en un entorno de pruebas; no ejecutar a ciegas en producción.

La aplicación todavía necesita conectar el servicio de compras a la interfaz, implementar y desplegar `verify-store-purchase` con credenciales oficiales de Apple/Google, procesar notificaciones de renovación/cancelación/reembolso, aplicar el límite de anuncios activos en el servidor y completar las pruebas en sandbox. No se deben habilitar compras reales hasta terminar esos pasos.

## Reglas de acceso que debe aplicar el servidor

1. Las primeras cinco publicaciones gratuitas se calculan por cuenta de usuario, no por dispositivo.
2. PACK 10/15/20 permiten hasta el número correspondiente de anuncios activos mientras la suscripción tenga acceso vigente.
3. AUTOMOTORS PRO permite anuncios ilimitados mientras la suscripción esté activa o en el periodo de gracia confirmado por la tienda.
4. Cancelar la renovación conserva el acceso hasta la fecha de expiración confirmada.
5. Compras pendientes no habilitan el plan. Reembolsos, revocaciones y expiraciones actualizan el acceso.
6. El límite debe comprobarse y aplicarse en el servidor al publicar, para evitar publicaciones simultáneas que excedan el plan.
7. Las transacciones y notificaciones se procesan idempotentemente para evitar conceder permisos dos veces.

## Configuración pendiente de las tiendas

1. Crear los cuatro productos como suscripciones mensuales auto-renovables en App Store Connect y Google Play Console.
2. Confirmar IDs, precios, periodos, grupos de suscripción y ofertas/base plans.
3. Configurar credenciales de Apple y Google como secretos de Supabase. Nunca colocarlas en el cliente Flutter ni compartirlas por chat.
4. Configurar App Store Server Notifications V2 y Google Play Real-time developer notifications.
5. Probar compras aprobadas, pendientes, fallidas, restauradas, renovaciones, cancelaciones, periodos de gracia, expiraciones, reembolsos y revocaciones.
6. Activar ventas reales únicamente después de completar pruebas y revisar las normas vigentes de ambas tiendas para España.

## Seguridad

No compartir claves privadas, archivos de firma, credenciales de tienda ni datos bancarios. No habilitar permisos por valores enviados por el cliente. El backend debe verificar con Apple o Google antes de actualizar los permisos del usuario.
