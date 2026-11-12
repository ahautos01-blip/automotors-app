-- Client profiles are editable, but authority remains server-managed.
create or replace function private.protect_profile_authority()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if coalesce(new.is_admin, false) then
      raise exception 'Administrator status is server-managed' using errcode = '42501';
    end if;
    if new.motivo_rechazo is not null then
      raise exception 'Verification decisions are server-managed' using errcode = '42501';
    end if;
  else
    if new.is_admin is distinct from old.is_admin then
      raise exception 'Administrator status is server-managed' using errcode = '42501';
    end if;
    if new.motivo_rechazo is distinct from old.motivo_rechazo then
      raise exception 'Verification decisions are server-managed' using errcode = '42501';
    end if;
    if new.estado_verificacion is not distinct from old.estado_verificacion then
      return new;
    end if;
  end if;
  -- The shipped client can request review or withdraw it, never approve itself.
  if new.estado_verificacion is not null and new.estado_verificacion not in
      ('Pendiente', 'No solicitada', 'No aplicable', 'pendiente', 'no_solicitada', 'no_aplicable') then
    raise exception 'Verification decisions are server-managed' using errcode = '42501';
  end if;
  return new;
end;
$$;
