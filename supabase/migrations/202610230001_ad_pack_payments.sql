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
