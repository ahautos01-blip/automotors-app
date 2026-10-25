# AUTOMOTORS — chat comprador/vendedor

## Cambios incluidos
- Sustituye el botón «Contactar por WhatsApp» por «Enviar mensaje al vendedor».
- Elimina el teléfono pre-rellenado `648191316`; el campo de teléfono queda vacío y opcional.
- Añade pantalla «Mis chats» y conversación dentro de la app.
- La creación de conversaciones y el envío de mensajes requieren sesión iniciada en Supabase.
- Añade políticas RLS para que solo comprador y vendedor participantes lean la conversación y sus mensajes.

## Configuración necesaria en Supabase
1. Revisa la migración `supabase/migrations/202610230002_in_app_chat.sql`.
2. Ejecútala en el proyecto correcto después de verificar las tablas `vehicle_listings` y la columna `owner_id`.
3. En Supabase Dashboard, activa `chat_messages` en Database > Publications > `supabase_realtime` para que los mensajes se actualicen en tiempo real.
4. Comprueba que la autenticación está habilitada y que los usuarios deben iniciar sesión.

## Limitaciones actuales
- El chat solo puede abrirse desde anuncios reales con `listingId` y `ownerId`. El Golf de demostración en la lista inicial no tiene una fila real asociada, por lo que mostrará un aviso en vez de crear una conversación falsa.
- La lista de chats identifica el anuncio por un fragmento de su ID; la siguiente mejora recomendada es cargar el nombre real del vehículo desde la relación con `vehicle_listings`, marcas y modelos.
- No se ha ejecutado ninguna migración ni se han hecho cambios en el proyecto remoto Supabase.
- No se han activado pagos reales.
