# Destacados y cupos de publicación

Implementación preparada en el worktree `vehicle-highlights`, desde la rama iOS.
La migración se instaló en el Supabase principal el 28 de octubre de 2026,
tras la autorización del usuario.

## Reglas

| Cuenta | Anuncios activos | Destacados simultáneos |
| --- | --- | --- |
| Bienvenida | 5 publicaciones totales, sin recuperar las consumidas al eliminar o vender | 0 |
| Gratuita después de bienvenida | 3 plazas reutilizables | 0 |
| PACK 10 | 10 | 3 |
| PACK 15 | 15 | 5 |
| PACK 20 | 20 | 8 |
| AUTOMOTORS PRO | Ilimitados | 15 |

Los reservados ocupan plaza. Los vendidos, borradores y eliminados no la ocupan.
Los anuncios que ya existan por encima de un límite reducido se conservan;
se impiden nuevas publicaciones hasta quedar por debajo del límite.
Si hay varios planes válidos, se aplica el mayor límite, sin sumar planes.
La compra debe estar verificada y vigente en `user_subscriptions`, o pagada y
vigente en el sistema anterior de `user_promotion_entitlements`.

El propietario encuentra **Destacar vehículo** y su contador en la ficha.
Puede quitar un destacado para seleccionar otro. Vender, eliminar o retirar un
anuncio libera su destacado. La selección se conserva durante renovaciones,
pero solo tiene efecto con un plan vigente. Al bajar de plan se muestran los
primeros seleccionados, hasta el límite nuevo. El servidor serializa por cuenta
las solicitudes para impedir que dos dispositivos consuman la última plaza.

## Cambios e instalación

- `supabase/migrations/20261028021959_vehicle_highlights_and_account_limits.sql`
  crea una tabla privada de selecciones, funciones de consulta y gestión y
  sustituye el trigger anterior de publicación. No elimina anuncios ni compras.
- `lib/vehicle_feature_control.dart` añade el botón, estado y contador del propietario.
- `lib/main.dart` integra el control y consulta destacados válidos desde el servidor.
- `pubspec.yaml` prepara la versión 1.0.1+10 para la siguiente build.
- Tras verificar o restaurar una compra vigente, aparece **Publicar vehículo**
  debajo del botón de ese plan. La pantalla vuelve a consultar el servidor al
  recibir la verificación, al volver a primer plano y al caducar un plan.
- `lookup-vehicle` versión 8 reconoce PACK 20 y PRO comprados en Apple, además
  de los derechos del sistema anterior. Valida de nuevo el plan en cada consulta.

Aplicar la migración antes de distribuir la build. La base de datos principal es
`ndicdhlpbyywqyjgxpnx`. La instalación autorizada quedó completada y se verificaron
las funciones públicas y sus permisos.

La migración presupone las tablas de productos, compras y derechos ya existentes
en el proyecto principal. Crea o reutiliza el registro privado de publicaciones,
que conserva las publicaciones aunque después se elimine su anuncio. No puede
reconstruir publicaciones eliminadas antes de que existiera dicho registro.

## Validación

`flutter test --no-pub`: 12 pruebas correctas.
`node test/lookup_access.integration.mjs`: acceso exclusivo de PACK 20/PRO,
incluidos estados pendientes, revocados, caducados, fechas futuras y planes inferiores.

Pruebas de PostgreSQL en memoria con Node y `@electric-sql/pglite@0.3.14`:

```powershell
# Instalar PGlite en una carpeta temporal, fuera de las dependencias de Flutter.
$env:PGLITE_MODULE_PATH = 'RUTA/node_modules/@electric-sql/pglite/dist/index.js'
node test/vehicle_limits.integration.mjs
```

Cubren los cuatro planes, el sexto/séptimo anuncio gratuito después de liberar
plazas, el historial tras eliminar, idempotencia, venta, retirada, caducidad,
revocación, renovación, reducción de plan, propiedad y permisos de los roles.
Las pruebas locales no simulan conexiones PostgreSQL concurrentes independientes
ni una compra real de Apple. El análisis de Flutter muestra avisos del archivo
principal existente; no hay errores de compilación en los cambios nuevos.

En TestFlight: comprar/restaurar un plan vigente, abrir una ficha propia,
destacar hasta el máximo, intentar uno adicional, quitar uno y destacar otro.
Comprobar la etiqueta y prioridad al volver al catálogo. Repetir con otro usuario
para confirmar que no aparece el botón sobre anuncios ajenos.
