-- Fix: profiles SELECT was open to everyone.
--
-- The original policy was:
--   create policy "Public profiles are viewable by everyone"
--     on public.profiles for select using (true);
--
-- `using (true)` let any caller holding the anon key -- which ships inside the
-- mobile app and is therefore public -- read every customer's full_name, phone,
-- email and role. Verified against production on 2026-09-05: an unauthenticated
-- request returned all profile rows, and an authenticated customer could read a
-- different customer's profile.
--
-- Replaced with: owner-only read, plus real admins. Nothing else in the app
-- reads another user's profile -- the only queries are `.eq('id', <self>)` in
-- user_repository/supabase_service and the admin dashboard's count over all
-- profiles. INSERT/UPDATE policies are already owner-scoped and are untouched.

drop policy if exists "Public profiles are viewable by everyone" on public.profiles;

-- A policy ON profiles cannot inline `select ... from profiles` to look up the
-- caller's role -- that recurses. SECURITY DEFINER runs the lookup outside RLS,
-- which breaks the cycle. search_path is pinned so the body cannot be captured
-- by a caller-controlled schema.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

-- anon keeps EXECUTE on purpose: auth.uid() is null for anon, so the function
-- returns false and the policy yields zero rows. Revoking it instead would make
-- anonymous SELECTs fail with a permission error rather than an empty result.
grant execute on function public.is_admin() to anon, authenticated;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Admins can view all profiles"
  on public.profiles for select
  using (public.is_admin());
