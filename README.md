# AUTOMOTORS — app Android + iPhone, pagos preparados (sin cobros reales)

## Reglas comerciales acordadas
- Primeras 5 publicaciones gratuitas por usuario.
- Pack 10 anuncios: 59 €.
- Pack 15 anuncios: 75 €.
- Pack 20 anuncios: 99 €.
- AUTOMOTORS PRO: 199 €/mes, publicaciones ilimitadas mientras la suscripción esté activa. El precio al cliente es 199 € en ambas tiendas; las comisiones se descuentan de ese importe, por lo que no se garantiza recibir 199 € netos.
- Liquidaciones: Apple y Google pagan según sus propios calendarios a la cuenta bancaria de autónomo registrada en cada plataforma. No se guardan datos bancarios en la app.

## Contenido
- `lib/main.dart`: código Flutter actual con los planes y sus precios visibles. Las acciones de compra están intencionadamente desactivadas; no cobra ni activa créditos.
- `supabase/migrations/202610230001_ad_pack_payments.sql`: tablas base para pedidos/créditos y estado de suscripción. Revisar con el esquema real antes de ejecutar.
- `ios/PRODUCTS.md`: productos que se deben crear en App Store Connect.
- `android/PRODUCTS.md`: productos que se deben crear en Google Play Console.

## Lo que aún no está implementado
Este paquete NO es una integración de pago lista para producción. Falta añadir y probar `in_app_purchase`/StoreKit y Google Play Billing en Flutter; configurar productos en cada tienda; implementar funciones backend para validar transacciones Apple y purchase tokens Google; procesar notificaciones de renovaciones, cancelaciones y reembolsos; y aplicar el control de créditos de forma atómica al publicar. Hasta entonces, la app solo informa de los planes y no permite comprar.

## Pasos seguros
1. Crear Apple Developer y Google Play Console con los datos reales del autónomo.
2. Crear los 4 productos en cada tienda con los IDs de los archivos de producto. Revisar precios finales y fiscalidad antes de publicar.
3. Revisar la migración SQL en un proyecto de pruebas y con copia de seguridad. No ejecutarla directamente en producción.
4. Implementar validación en servidor con credenciales guardadas como secretos, nunca en `main.dart`.
5. Añadir verificación idempotente para que una transacción no conceda créditos dos veces.
6. Conectar publicación de anuncios con créditos: 5 gratis; después, un crédito por anuncio o PRO activo. Este control debe existir en base de datos, no solo en la interfaz.
7. Probar sandbox/TestFlight y licencia de pruebas de Google: compras aprobadas, pendientes, canceladas, repetidas, reembolsadas, expiración de PRO y restauración de compras.
8. Activar ventas reales únicamente tras completar las pruebas y confirmar las reglas vigentes de Apple/Google para España.

## Seguridad
No compartas claves secretas, archivos de firma, credenciales de tiendas ni datos bancarios. No introduzcas claves privadas en Flutter. El cliente nunca debe decidir por sí solo que una compra está pagada.
