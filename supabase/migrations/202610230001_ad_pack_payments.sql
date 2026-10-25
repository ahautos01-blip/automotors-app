create table if not exists public.ad_pack_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pack_size integer not null check (pack_size in (10, 15, 20)),
  amount_cents integer not null check (amount_cents in (5900, 7500, 9900)),
  currency text not null default 'eur' check (currency = 'eur'),
  provider text not null check (provider in ('stripe', 'apple', 'google_play')),
  status text not null default 'pending' check (status in ('pending', 'paid', 'failed', 'refunded')),
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text unique,
  provider_transaction_id text unique,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
create table if not exists public.user_ad_credits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  credits integer not null default 0 check (credits >= 0),
  updated_at timestamptz not null default now()
);
alter table public.ad_pack_orders enable row level security;
alter table public.user_ad_credits enable row level security;
drop policy if exists "read own pack orders" on public.ad_pack_orders;
create policy "read own pack orders" on public.ad_pack_orders for select to authenticated using (auth.uid() = user_id);
drop policy if exists "read own ad credits" on public.user_ad_credits;
create policy "read own ad credits" on public.user_ad_credits for select to authenticated using (auth.uid() = user_id);
create or replace function public.fulfill_stripe_ad_pack(p_order_id uuid, p_checkout_session_id text, p_payment_intent_id text)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user_id uuid; v_pack_size integer; v_updated integer;
begin
  update public.ad_pack_orders set status='paid', stripe_checkout_session_id=coalesce(p_checkout_session_id,stripe_checkout_session_id), stripe_payment_intent_id=coalesce(p_payment_intent_id,stripe_payment_intent_id), paid_at=now()
  where id=p_order_id and provider='stripe' and status='pending' returning user_id,pack_size into v_user_id,v_pack_size;
  get diagnostics v_updated = row_count;
  if v_updated=0 then return false; end if;
  insert into public.user_ad_credits(user_id,credits,updated_at) values(v_user_id,v_pack_size,now())
  on conflict(user_id) do update set credits=public.user_ad_credits.credits+excluded.credits,updated_at=now();
  return true;
end; $$;
revoke all on function public.fulfill_stripe_ad_pack(uuid,text,text) from public, anon, authenticated;
grant execute on function public.fulfill_stripe_ad_pack(uuid,text,text) to service_role;


-- Estado de suscripciones nativas de Apple y Google.
-- Solo el backend con service_role debe insertar/actualizar estas filas.
create table if not exists public.user_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('apple','google_play')),
  product_id text not null check (product_id = 'automotors_pro_monthly_199'),
  provider_transaction_id text not null unique,
  status text not null check (status in ('pending','active','grace_period','expired','canceled','revoked')),
  started_at timestamptz,
  expires_at timestamptz,
  auto_renewing boolean not null default false,
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
alter table public.user_subscriptions enable row level security;
drop policy if exists "read own subscription" on public.user_subscriptions;
create policy "read own subscription" on public.user_subscriptions for select to authenticated using (auth.uid() = user_id);
-- No se conceden permisos de escritura a usuarios autenticados: el servidor valida compras.
revoke insert, update, delete on public.user_subscriptions from anon, authenticated;
