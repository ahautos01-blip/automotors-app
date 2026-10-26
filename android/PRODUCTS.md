# Google Play Console — suscripciones AUTOMOTORS

Los cuatro productos deben crearse como **suscripciones auto-renovables mensuales** en Google Play Console. No crear los packs como compras únicas ni consumibles.

| Product ID | Tipo | Precio objetivo |
|---|---|---:|
| `automotors_pack_10` | Suscripción mensual | 59 €/mes |
| `automotors_pack_15` | Suscripción mensual | 75 €/mes |
| `automotors_pack_20` | Suscripción mensual | 99 €/mes |
| `automotors_pro_monthly_199` | Suscripción mensual | 199 €/mes |

## Reglas de acceso

- PACK 10, PACK 15 y PACK 20 habilitan el límite de anuncios activos correspondiente mientras la suscripción tenga acceso vigente.
- AUTOMOTORS PRO habilita anuncios ilimitados mientras la suscripción esté activa o en un periodo de gracia reconocido por Google.
- Cancelar la renovación no debe retirar el acceso antes de la fecha de expiración que confirme Google.
- Reembolsos, revocaciones, expiraciones y cambios de estado deben reflejarse desde el servidor.

## Integración obligatoria

1. Configurar los productos y sus ofertas/base plans en Play Console. Confirmar precio, periodo mensual y disponibilidad por país.
2. Flutter inicia la compra mediante Google Play Billing; el cliente no concede acceso por sí mismo.
3. Supabase valida el purchase token con Google Play Developer API antes de activar el plan.
4. Configurar Real-time developer notifications y procesarlas de forma idempotente.
5. Confirmar/acknowledge la compra cuando corresponda y manejar compras pendientes, restauración, renovación, cancelación, gracia, expiración y revocación.
6. No almacenar claves privadas ni credenciales de Google en Flutter. Guardarlas como secretos del backend.

Los identificadores de producto deben coincidir exactamente con Flutter, Supabase y App Store Connect. No habilitar compras reales hasta probar con cuentas de licencia y completar la configuración de la tienda.
