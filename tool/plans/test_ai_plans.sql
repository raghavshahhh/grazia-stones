-- Scratch-database test for supabase/migrations/20261030000000_ai_plans.sql.
-- NEVER run against Supabase. Run with tool/plans/run_sql_tests.sh, which boots
-- a throwaway local Postgres, or: psql -v ON_ERROR_STOP=1 -f tool/plans/test_ai_plans.sql
-- Any failed assert aborts with a non-zero exit.

\set ON_ERROR_STOP 1
set client_min_messages = warning;

-- ---------------------------------------------------------------------------
-- Minimal Supabase stand-ins: roles, auth schema, profiles, is_admin(), and
-- Supabase's default grants (so the migration's revokes are actually tested).
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end;
$$;

create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;

create table if not exists auth.users (
  id uuid primary key,
  email varchar(255),
  created_at timestamptz not null default now()
);

create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create or replace function auth.role() returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;

alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

create table if not exists public.profiles (id uuid primary key references auth.users(id), role text);
alter table public.profiles enable row level security;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;
grant execute on function public.is_admin() to anon, authenticated;

-- Real migrations under test (the plans migration twice = idempotency check).
\ir ../../supabase/migrations/20261009000000_ai_credits.sql
\ir ../../supabase/migrations/20261030000000_ai_plans.sql
\ir ../../supabase/migrations/20261030000000_ai_plans.sql

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, created_at) values
  ('00000000-0000-0000-0000-000000000001', 'trial@test.local', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000000002', 'free@test.local',  now() - interval '8 days'),
  ('00000000-0000-0000-0000-000000000003', 'plus@test.local',  now() - interval '30 days'),
  ('00000000-0000-0000-0000-000000000004', 'pro@test.local',   now() - interval '30 days'),
  ('00000000-0000-0000-0000-000000000005', 'Admin@Test.local', now() - interval '90 days'),
  ('00000000-0000-0000-0000-000000000006', 'plus2@test.local', now() - interval '30 days'),
  ('00000000-0000-0000-0000-000000000007', 'gone@test.local',  now() - interval '30 days');
insert into public.profiles (id, role) values
  ('00000000-0000-0000-0000-000000000001', 'customer'),
  ('00000000-0000-0000-0000-000000000005', 'admin');

insert into public.subscriptions (user_id, plan, source, status, period_end, purchase_token) values
  ('00000000-0000-0000-0000-000000000003', 'plus', 'google_play', 'active', now() + interval '20 days', 'tok-plus'),
  ('00000000-0000-0000-0000-000000000004', 'pro',  'app_store',   'active', now() + interval '20 days', 'tok-pro'),
  ('00000000-0000-0000-0000-000000000006', 'plus', 'admin',       'active', now() + interval '20 days', null),
  ('00000000-0000-0000-0000-000000000007', 'pro',  'google_play', 'active', now() - interval '1 hour', 'tok-old');

-- Helper: spend n renders, return how many succeeded and the last reason.
create or replace function pg_temp.spend(p_user uuid, n integer, out ok_count integer, out last_reason text)
language plpgsql as $$
declare r record;
begin
  ok_count := 0;
  for i in 1..n loop
    select * into r from public.consume_ai_render(p_user);
    if r.ok then ok_count := ok_count + 1; else last_reason := r.reason; end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tests (as superuser = acting like the service role path)
-- ---------------------------------------------------------------------------
do $$
declare
  u record; s record;
  t uuid := '00000000-0000-0000-0000-000000000001';
  f uuid := '00000000-0000-0000-0000-000000000002';
  pl uuid := '00000000-0000-0000-0000-000000000003';
  pr uuid := '00000000-0000-0000-0000-000000000004';
  pl2 uuid := '00000000-0000-0000-0000-000000000006';
  gone uuid := '00000000-0000-0000-0000-000000000007';
  next_month timestamptz := (date_trunc('month', (now() at time zone 'Asia/Kolkata')::date) + interval '1 month')::timestamp at time zone 'Asia/Kolkata';
  next_midnight timestamptz := (((now() at time zone 'Asia/Kolkata')::date) + 1)::timestamp at time zone 'Asia/Kolkata';
begin
  -- seed
  assert (select count(*) from public.ai_plan_limits) = 4, 'seed rows';
  assert (select monthly_limit is null and daily_limit = 10 from public.ai_plan_limits where plan = 'trial'), 'trial limits';

  -- trial: 10/day, no monthly cap
  select * into u from public.get_ai_usage(t);
  assert u.plan = 'trial' and u.monthly_limit is null and u.daily_limit = 10 and u.daily_used = 0, 'trial usage';
  assert u.trial_ends_at > now() + interval '5 days', 'trial_ends_at';
  select * into s from pg_temp.spend(t, 11);
  assert s.ok_count = 10 and s.last_reason = 'daily_limit', format('trial daily cap: %s', s);
  select * into u from public.get_ai_usage(t);
  assert u.daily_used = 10 and u.monthly_used = 10 and u.resets_at = next_midnight, 'trial after cap';
  perform public.refund_ai_render(t);
  select * into u from public.get_ai_usage(t);
  assert u.daily_used = 9 and u.monthly_used = 9, 'refund gives one back';
  select * into s from pg_temp.spend(t, 2);
  assert s.ok_count = 1 and s.last_reason = 'daily_limit', 'refunded render usable once';
  -- day rollover
  update public.ai_credits set daily_date = daily_date - 1 where user_id = t;
  select * into u from public.get_ai_usage(t);
  assert u.daily_used = 0 and u.monthly_used = 10, 'new IST day resets daily only';
  select * into s from pg_temp.spend(t, 1);
  assert s.ok_count = 1, 'spend after day rollover';

  -- free (trial over): 3 per month
  select * into u from public.get_ai_usage(f);
  assert u.plan = 'free' and u.monthly_limit = 3 and u.daily_limit = 3, 'free usage';
  select * into s from pg_temp.spend(f, 4);
  assert s.ok_count = 3 and s.last_reason = 'monthly_limit', format('free monthly cap: %s', s);
  select * into u from public.get_ai_usage(f);
  assert u.resets_at = next_month, 'free resets at next IST month';
  -- new day does not help on free; new month does
  update public.ai_credits set daily_date = daily_date - 1 where user_id = f;
  select * into s from pg_temp.spend(f, 1);
  assert s.ok_count = 0 and s.last_reason = 'monthly_limit', 'free still capped next day';
  update public.ai_credits set month_key = '2000-01' where user_id = f;
  select * into u from public.get_ai_usage(f);
  assert u.monthly_used = 0, 'new month resets monthly';
  select * into s from pg_temp.spend(f, 1);
  assert s.ok_count = 1, 'spend after month rollover';

  -- plus: 10/day, 60/month
  select * into u from public.get_ai_usage(pl);
  assert u.plan = 'plus' and u.source = 'google_play' and u.monthly_limit = 60 and u.daily_limit = 10, 'plus usage';
  select * into s from pg_temp.spend(pl, 11);
  assert s.ok_count = 10 and s.last_reason = 'daily_limit', format('plus daily cap: %s', s);
  -- plus monthly cap
  perform public.consume_ai_render(pl2);
  update public.ai_credits set month_count = 59, daily_count = 0 where user_id = pl2;
  select * into s from pg_temp.spend(pl2, 2);
  assert s.ok_count = 1 and s.last_reason = 'monthly_limit', format('plus 60th ok, 61st refused: %s', s);
  select * into u from public.get_ai_usage(pl2);
  assert u.monthly_used = 60 and u.resets_at = next_month, 'plus monthly exhausted';

  -- pro: 25/day, 200/month
  select * into s from pg_temp.spend(pr, 26);
  assert s.ok_count = 25 and s.last_reason = 'daily_limit', format('pro daily cap: %s', s);
  update public.ai_credits set daily_count = 0, month_count = 199 where user_id = pr;
  select * into s from pg_temp.spend(pr, 2);
  assert s.ok_count = 1 and s.last_reason = 'monthly_limit', format('pro monthly cap: %s', s);

  -- expired subscription falls back to free
  select * into u from public.get_ai_usage(gone);
  assert u.plan = 'free' and u.source is null, 'expired sub = free';

  -- old functions still work
  select * into u from public.consume_ai_credit(gone);
  assert u.ok and u.credits_remaining = 11, 'legacy consume_ai_credit';
end;
$$;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
-- A customer (authenticated, not admin)
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';

do $$
begin
  begin
    perform public.admin_set_plan('00000000-0000-0000-0000-000000000001', 'pro', 30, 'self grant');
    raise exception 'customer could call admin_set_plan';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.admin_find_user('free@test.local');
    raise exception 'customer could call admin_find_user';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.consume_ai_render('00000000-0000-0000-0000-000000000001');
    raise exception 'customer could call consume_ai_render';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.refund_ai_render('00000000-0000-0000-0000-000000000001');
    raise exception 'customer could call refund_ai_render';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.get_ai_usage('00000000-0000-0000-0000-000000000001');
    raise exception 'customer could call get_ai_usage';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.subscriptions (user_id, plan, source, period_end)
      values ('00000000-0000-0000-0000-000000000001', 'pro', 'admin', now() + interval '1 year');
    raise exception 'customer could insert a subscription';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.ai_plan_limits set daily_limit = 999;
    if (select daily_limit from public.ai_plan_limits where plan = 'trial') = 999 then
      raise exception 'customer could change limits';
    end if;
  exception when insufficient_privilege then null;
  end;
  assert (select count(*) from public.subscriptions) = 0, 'customer sees only own (none) subscriptions';
  assert (select count(*) from public.ai_plan_limits) = 4, 'customer can read limits';
end;
$$;
reset role;

-- anon cannot read limits or subscriptions rows
set role anon;
do $$
begin
  assert (select count(*) from public.ai_plan_limits) = 0, 'anon reads no limits';
  assert (select count(*) from public.subscriptions) = 0, 'anon reads no subscriptions';
end;
$$;
reset role;

-- The plus user sees exactly their own row
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin
  assert (select count(*) from public.subscriptions) = 1, 'plus user sees own row only';
end $$;
reset role;

-- Admin
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000005';
do $$
declare u record;
begin
  assert (select count(*) from public.subscriptions) = 4, 'admin sees all subscriptions';

  select * into u from public.admin_set_plan('00000000-0000-0000-0000-000000000002', 'pro', 30, 'expo promo');
  assert u.plan = 'pro' and u.source = 'admin' and u.daily_limit = 25
     and u.period_end between now() + interval '29 days' and now() + interval '31 days', format('admin grant pro: %s', u);
  assert (select granted_by from public.subscriptions where user_id = '00000000-0000-0000-0000-000000000002')
         = '00000000-0000-0000-0000-000000000005', 'granted_by recorded';

  -- grant keeps the store token on an existing store row
  select * into u from public.admin_set_plan('00000000-0000-0000-0000-000000000003', 'pro', 7, null);
  assert (select purchase_token from public.subscriptions where user_id = '00000000-0000-0000-0000-000000000003') = 'tok-plus', 'token kept';

  select * into u from public.admin_set_plan('00000000-0000-0000-0000-000000000002', 'free', null, 'revoked');
  assert u.plan = 'free', 'admin revoke -> free';
  assert (select status from public.subscriptions where user_id = '00000000-0000-0000-0000-000000000002') = 'expired', 'row expired';

  begin
    perform public.admin_set_plan('00000000-0000-0000-0000-000000000002', 'gold', 30, null);
    raise exception 'unknown plan accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.admin_set_plan('00000000-0000-0000-0000-000000000002', 'plus', 0, null);
    raise exception 'p_days 0 accepted';
  exception when invalid_parameter_value then null;
  end;

  select * into u from public.admin_find_user('  ADMIN@test.LOCAL ');
  assert u.id = '00000000-0000-0000-0000-000000000005' and u.plan = 'free', format('admin_find_user: %s', u);
  select * into u from public.admin_find_user('trial@test.local');
  assert u.plan = 'trial' and u.daily_used >= 1, 'admin_find_user shows usage';
end;
$$;
reset role;

-- service_role can spend; one purchase token cannot belong to two users
set role service_role;
do $$
declare r record;
begin
  select * into r from public.consume_ai_render('00000000-0000-0000-0000-000000000006');
  assert r.reason = 'monthly_limit', 'service_role can call consume_ai_render';
  begin
    update public.subscriptions set purchase_token = 'tok-pro' where user_id = '00000000-0000-0000-0000-000000000003';
    raise exception 'duplicate purchase token accepted';
  exception when unique_violation then null;
  end;
end;
$$;
reset role;

\echo 'ALL AI PLAN TESTS PASSED'
