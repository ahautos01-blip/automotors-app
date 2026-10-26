-- AUTOMOTORS: endurecer permisos de favoritos de vehículos.
-- La tabla saved_vehicles y sus políticas RLS por propietario ya existen.
-- Esta migración limita privilegios de tabla y mantiene el acceso mínimo necesario.

alter table public.saved_vehicles enable row level security;

revoke all privileges on table public.saved_vehicles from anon;
revoke all privileges on table public.saved_vehicles from authenticated;

grant select, insert, delete on table public.saved_vehicles to authenticated;

-- El cliente no debe modificar filas ni alterar propietarios/identificadores.
revoke update, truncate, references, trigger
  on table public.saved_vehicles from authenticated;

create index if not exists saved_vehicles_user_created_idx
  on public.saved_vehicles(user_id, created_at desc);
