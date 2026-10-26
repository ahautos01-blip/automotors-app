# App Store Connect — suscripciones AUTOMOTORS

Los cuatro productos deben crearse como **suscripciones auto-renovables mensuales** dentro de un grupo de suscripciones en App Store Connect. No crear los packs como compras consumibles.

| Product ID | Tipo | Precio objetivo |
|---|---|---:|
| `automotors_pack_10` | Suscripción auto-renovable mensual | 59 €/mes |
| `automotors_pack_15` | Suscripción auto-renovable mensual | 75 €/mes |
| `automotors_pack_20` | Suscripción auto-renovable mensual | 99 €/mes |
| `automotors_pro_monthly_199` | Suscripción auto-renovable mensual | 199 €/mes |

## Reglas de acceso

- PACK 10, PACK 15 y PACK 20 habilitan el límite de anuncios activos correspondiente mientras la suscripción tenga acceso vigente.
- AUTOMOTORS PRO habilita anuncios ilimitados mientras la suscripción esté activa o en el periodo de gracia que confirme Apple.
- Una cancelación de renovación no debe retirar el acceso antes de la fecha de expiración confirmada.
- Reembolsos, revocaciones, expiraciones y cambios de plan deben reflejarse desde el servidor.

## Integración obligatoria

1. Crear el grupo de suscripciones, productos, localizaciones y niveles de precio en App Store Connect. Confirmar disponibilidad y precio final para España.
2. Flutter usa StoreKit mediante el plugin de compras dentro de la aplicación; no concede acceso solo por el resultado local del dispositivo.
3. Supabase valida transacciones/firmas con App Store Server API y procesa App Store Server Notifications V2.
4. Implementar restauración de compras, renovaciones, cancelaciones, gracia, expiración, reembolsos y revocaciones.
5. Guardar credenciales y claves privadas de Apple solo en secretos del backend, nunca en Flutter.

Los identificadores deben coincidir exactamente con Flutter, Supabase y Google Play Console. No habilitar compras reales hasta probar en Sandbox/TestFlight y completar la configuración de la tienda.
