-- Fix: enforce_profile_role_immutable() (previous migration) blocked ALL
-- role changes that weren't made by an already-admin session, including
-- the service_role key. Triggers fire regardless of RLS bypass, and
-- is_admin() reads auth.uid(), which is NULL for service_role/direct-SQL
-- access — so admin bootstrapping (seeding the very first admin, support
-- operations via the service key) was accidentally blocked too.
--
-- auth.uid() is NULL only in contexts that already bypass RLS entirely
-- (service_role, or a superuser/direct psql session) — never for a normal
-- anon/authenticated request, which always carries a JWT subject. So it's
-- safe to treat "no auth.uid()" as an already-trusted server context.

create or replace function public.enforce_profile_role_immutable()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    if auth.uid() is not null and not public.is_admin() then
      raise exception 'Only admins can change a profile role'
        using errcode = '42501'; -- insufficient_privilege
    end if;
  end if;
  return new;
end;
$$;
