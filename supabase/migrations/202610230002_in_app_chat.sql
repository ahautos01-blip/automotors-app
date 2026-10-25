-- Chat comprador-vendedor dentro de AUTOMOTORS.
-- Ejecutar después de revisar y aplicar las migraciones anteriores.
create table if not exists public.chat_conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chat_different_participants check (buyer_id <> seller_id),
  constraint chat_unique_buyer_listing unique (listing_id, buyer_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_conversation_created_idx
  on public.chat_messages(conversation_id, created_at);
create index if not exists chat_conversations_buyer_idx
  on public.chat_conversations(buyer_id, updated_at desc);
create index if not exists chat_conversations_seller_idx
  on public.chat_conversations(seller_id, updated_at desc);

alter table public.chat_conversations enable row level security;
alter table public.chat_messages enable row level security;

grant select, insert on public.chat_conversations to authenticated;
grant select, insert on public.chat_messages to authenticated;

drop policy if exists "chat participants read conversations" on public.chat_conversations;
create policy "chat participants read conversations" on public.chat_conversations
for select to authenticated
using (auth.uid() = buyer_id or auth.uid() = seller_id);

drop policy if exists "buyer starts chat for published listing" on public.chat_conversations;
create policy "buyer starts chat for published listing" on public.chat_conversations
for insert to authenticated
with check (
  auth.uid() = buyer_id
  and buyer_id <> seller_id
  and exists (
    select 1 from public.vehicle_listings vl
    where vl.id = listing_id
      and vl.owner_id = seller_id
      and vl.status = 'published'
  )
);

drop policy if exists "participants read chat messages" on public.chat_messages;
create policy "participants read chat messages" on public.chat_messages
for select to authenticated
using (exists (
  select 1 from public.chat_conversations c
  where c.id = conversation_id
    and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
));

drop policy if exists "participants send own chat messages" on public.chat_messages;
create policy "participants send own chat messages" on public.chat_messages
for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.chat_conversations c
    where c.id = conversation_id
      and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
  )
);

-- Para recibir mensajes en tiempo real, activa chat_messages en Database > Publications > supabase_realtime
-- del panel de Supabase, si aún no está publicado.
