# AUTOMOTORS — venta confirmada y reseñas

## Flujo definido

1. El vendedor abre la gestión de uno de sus anuncios publicados y pulsa **Marcar como vendido**.
2. El selector muestra los compradores que han iniciado una conversación con ese vendedor para ese anuncio.
3. El vendedor selecciona al comprador y confirma. La función SQL `mark_vehicle_sold` valida en servidor que la conversación exista y que el anuncio pertenezca al vendedor; después establece `status = 'sold'`, `sold_to_buyer_id` y `sold_at`.
4. El comprador seleccionado puede publicar una reseña de 1 a 5 estrellas y texto.
5. La reseña aparece en `SellerReviewsSection` dentro del perfil público del vendedor. Se muestra promedio y número de reseñas.
6. Solo se permite una reseña por comprador/anuncio. Las reseñas son públicas y no se pueden editar o borrar desde el cliente.

## Archivos añadidos

- `supabase/migrations/202610230003_sold_vehicle_reviews.sql`: columnas, tabla de reseñas, políticas RLS y función de confirmación de venta.
- `lib/sold_reviews_features.dart`: diálogo de marcar vendido, formulario de reseña, helper de datos y sección de reseñas para el perfil.

## Integración en las pantallas existentes

En la pantalla de gestión de anuncios del vendedor, importa `sold_reviews_features.dart` y, solo para anuncios con `status == 'published'`, añade un botón que abra `showDialog<bool>(context: context, builder: (_) => MarkVehicleSoldDialog(listingId: listingId))`. Si devuelve `true`, recarga el anuncio y ocúltalo de la lista pública de vehículos disponibles.

En el detalle del anuncio, muestra `VehicleReviewForm(listingId: listingId, sellerId: sellerId)` únicamente cuando el usuario autenticado coincida con `sold_to_buyer_id` y el estado sea `sold`. La base de datos ya aplica esa comprobación también en RLS; no dependas solo de la condición visual.

En el perfil del vendedor añade `SellerReviewsSection(sellerId: profileUserId)`.

## Pasos seguros

1. Haz una copia de seguridad de Supabase.
2. Revisa que `vehicle_listings.status` use `published` y admita el valor `sold`. Si tu proyecto usa otro estado para vendido, ajusta la migración y los filtros de app.
3. Ejecuta la migración de chat anterior antes que esta migración, porque la función usa `chat_conversations`.
4. Ejecuta `202610230003_sold_vehicle_reviews.sql` en el SQL Editor de Supabase.
5. Integra los widgets en las pantallas señaladas y prueba con dos usuarios distintos: vendedor y comprador.

## Limitaciones de esta entrega

Los componentes de Flutter se entregan en un archivo independiente para no sobrescribir automáticamente las pantallas existentes. Hay que conectarlos a la navegación real del perfil y de la gestión de anuncios. La etiqueta de comprador en el diálogo usa un identificador parcial porque el esquema de chat actual no incluye nombre público; si quieres mostrar nombres, enlaza `buyer_id` con el perfil público y añade únicamente un campo visible y autorizado. No ejecutar en producción sin revisar las políticas actuales y hacer pruebas de permisos.
