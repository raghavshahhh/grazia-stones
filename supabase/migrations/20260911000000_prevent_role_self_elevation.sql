-- Fix: profiles.role was self-writable by any authenticated user.
--
-- "Users can update own profile" (schema.sql:28-29) is:
--   using (auth.uid() = id)
-- with no `with check` and no column restriction. RLS is row-level, not
-- column-level, so this only ever checked WHICH row was being touched, not
-- WHICH columns. Any authenticated user could call:
--   PATCH /rest/v1/profiles?id=eq.<own-id>  { "role": "admin" }
-- directly against the Supabase REST API (bypassing the Flutter app
-- entirely) and self-promote to admin. Every admin-gated RLS policy in this
-- schema (15+) and the app's own router guard trust this one column, so
-- this was a full admin bypass.
--
-- Fix is enforced at the trigger level rather than by rewriting the RLS
-- policy, so it holds regardless of how the row is reached (REST, RPC,
-- future policy changes) and composes cleanly with the existing "Admins can
-- update all profiles" policy from 20260908010000_admin_profiles_update.sql
-- (that policy still lets admins change any user's role; this trigger only
-- blocks a *non-admin* from changing *their own* role).

create or replace function public.enforce_profile_role_immutable()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    if not public.is_admin() then
      raise exception 'Only admins can change a profile role'
        using errcode = '42501'; -- insufficient_privilege
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_profile_role_immutable on public.profiles;

create trigger enforce_profile_role_immutable
  before update on public.profiles
  for each row execute function public.enforce_profile_role_immutable();
