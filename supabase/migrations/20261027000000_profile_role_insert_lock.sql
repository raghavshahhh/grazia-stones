-- Close the INSERT side of the role self-elevation fix (20260911000000).
--
-- enforce_profile_role_immutable fires only BEFORE UPDATE, and the profiles INSERT policy (schema.sql:32) has
-- no role check, so a signed-in user without a profile row could
--   POST /rest/v1/profiles { "id": "<own-id>", "role": "admin" }
-- and become admin. handle_new_user() never sets role (the column default applies), so forcing 'customer' on
-- inserts made by an ordinary signed-in user changes nothing for normal sign-ups. Service-role / SQL-editor
-- inserts (auth.role() is not 'authenticated') and admins keep full control.

create or replace function public.enforce_profile_role_on_insert()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') = 'authenticated' and not public.is_admin() then
    new.role := 'customer';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_profile_role_on_insert on public.profiles;

create trigger enforce_profile_role_on_insert
  before insert on public.profiles
  for each row execute function public.enforce_profile_role_on_insert();
