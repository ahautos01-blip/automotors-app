-- AUTOMOTORS: suscripciones nativas de Apple y Google.
-- Esta migración define el esquema base; aplicar primero en un proyecto de pruebas.
-- Los planes son suscripciones mensuales, no compras únicas ni créditos consumibles.

create table if not exists public.user_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('apple', 'google_play')),
  product_id text not null check (product_id in (
    'automotors_pack_10',
    'automotors_pack_15',
    'automotors_pack_20',
    'automotors_pro_monthly_199'
  )),
  -- ID de transacción verificada por la tienda; debe ser idempotente.
  provider_transaction_id text not null,
  -- Apple originalTransactionId o hash del token/identificador de compra de Google.
  -- No guardar el token de compra de Google en texto plano.
  provider_original_id text not null,
  status text not null check (status in (
    'pending', 'active', 'grace_period', 'expired', 'canceled', 'revoked'
  )),
  started_at timestamptz,
  expires_at timestamptz,
  auto_renewing boolean not null default false,
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_transaction_id),
  unique (provider, provider_original_id)
);

create index if not exists user_subscriptions_user_status_idx
  on public.user_subscriptions(user_id, status, expires_at desc);

alter table public.user_subscriptions enable row level security;
drop policy if exists "read own subscription" on public.user_subscriptions;
create policy "read own subscription"
  on public.user_subscriptions
  for select to authenticated
  using (auth.uid() = user_id);

-- El cliente autenticado solo puede leer su estado. Solo backend confiable
-- con service_role debe insertar o actualizar después de validar en la tienda.
revoke insert, update, delete on public.user_subscriptions from anon, authenticated;

-- Registro idempotente de notificaciones de App Store Server Notifications V2
-- y Google Play Real-time developer notifications. No almacenar payloads con
-- tokens/recibos completos en esta tabla.
create table if not exists public.store_notification_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('apple', 'google_play')),
  provider_event_id text not null,
  event_type text not null,
  processing_status text not null default 'pending'
    check (processing_status in ('pending', 'processed', 'failed', 'ignored')),
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  error_code text,
  unique (provider, provider_event_id)
);

alter table public.store_notification_events enable row level security;
revoke all on public.store_notification_events from anon, authenticated;

-- No se conceden privilegios de escritura a clientes. La función de backend
-- debe verificar la firma/token con Apple/Google antes de actualizar el estado.

-- Upsert transaccional e idempotente de un derecho de suscripción que ya fue
-- verificado con la tienda por una Edge Function. El cliente nunca puede
-- llamar esta función directamente.
create or replace function public.apply_verified_store_subscription(
  p_user_id uuid,
  p_provider text,
  p_product_id text,
  p_transaction_id text,
  p_original_transaction_id text,
  p_status text,
  p_started_at timestamptz,
  p_expires_at timestamptz,
  p_auto_renewing boolean,
  p_verified_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing_user_id uuid;
  v_applied boolean;
begin
  if p_user_id is null
     or p_provider is null
     or p_provider not in ('apple', 'google_play')
     or p_product_id is null
     or p_product_id not in (
       'automotors_pack_10',
       'automotors_pack_15',
       'automotors_pack_20',
       'automotors_pro_monthly_199'
     )
     or p_status is null
     or p_status not in ('pending', 'active', 'grace_period', 'expired', 'canceled', 'revoked')
     or nullif(btrim(p_transaction_id), '') is null
     or nullif(btrim(p_original_transaction_id), '') is null
     or p_expires_at is null
     or p_verified_at is null then
    raise exception 'Invalid verified store subscription.' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_provider || ':' || p_original_transaction_id, 0)
  );

  select subscription.user_id
    into v_existing_user_id
  from public.user_subscriptions as subscription
  where subscription.provider = p_provider
    and subscription.provider_original_id = p_original_transaction_id
  for update;

  if v_existing_user_id is not null and v_existing_user_id <> p_user_id then
    raise exception 'This store subscription is already linked to another AUTOMOTORS account.'
      using errcode = '23505';
  end if;

  insert into public.user_subscriptions (
    user_id,
    provider,
    product_id,
    provider_transaction_id,
    provider_original_id,
    status,
    started_at,
    expires_at,
    auto_renewing,
    last_verified_at,
    updated_at
  ) values (
    p_user_id,
    p_provider,
    p_product_id,
    p_transaction_id,
    p_original_transaction_id,
    p_status,
    p_started_at,
    p_expires_at,
    coalesce(p_auto_renewing, false),
    p_verified_at,
    p_verified_at
  )
  on conflict (provider, provider_original_id) do update
    set product_id = excluded.product_id,
        provider_transaction_id = excluded.provider_transaction_id,
        status = excluded.status,
        started_at = coalesce(excluded.started_at, public.user_subscriptions.started_at),
        expires_at = excluded.expires_at,
        auto_renewing = excluded.auto_renewing,
        last_verified_at = excluded.last_verified_at,
        updated_at = excluded.updated_at
    where public.user_subscriptions.user_id = excluded.user_id
      and excluded.last_verified_at >= public.user_subscriptions.last_verified_at
  returning true into v_applied;

  if v_applied is null then
    -- An older notification/replay must not overwrite newer subscription state.
    return false;
  end if;

  return true;
end;
$$;

revoke all on function public.apply_verified_store_subscription(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean, timestamptz
) from public, anon, authenticated;
grant execute on function public.apply_verified_store_subscription(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean, timestamptz
) to service_role;
