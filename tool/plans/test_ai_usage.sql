-- Scratch-database test for supabase/migrations/20261031000000_ai_usage_events.sql.
-- NEVER run against Supabase. Run with tool/plans/run_sql_tests.sh: it runs this
-- after test_ai_plans.sql in the same throwaway Postgres, reusing its Supabase
-- stand-ins (roles, auth.users, profiles, is_admin) and users.

\set ON_ERROR_STOP 1
set client_min_messages = warning;

alter table public.profiles add column if not exists full_name text;
update public.profiles set full_name = 'Asha Admin' where id = '00000000-0000-0000-0000-000000000005';

-- Migration under test, twice = idempotency check.
\ir ../../supabase/migrations/20261031000000_ai_usage_events.sql
\ir ../../supabase/migrations/20261031000000_ai_usage_events.sql

-- Fixtures, written the way the API writes them (service role).
set role service_role;
insert into public.ai_usage_events (user_id, kind, model, prompt_tokens, output_tokens, total_tokens, ok, created_at) values
  -- trial user: 2 renders today, 1 failed render, 1 old chat (10 days ago)
  ('00000000-0000-0000-0000-000000000001', 'render', 'gemini-3.1-flash-image', 1000, 1300, 2300, true,  now() - interval '1 hour'),
  ('00000000-0000-0000-0000-000000000001', 'render', 'gemini-3.1-flash-image', 1000, 1300, 2300, true,  now() - interval '2 hours'),
  ('00000000-0000-0000-0000-000000000001', 'render', 'gemini-3.1-flash-image', null, null, null, false, now() - interval '3 hours'),
  ('00000000-0000-0000-0000-000000000001', 'chat',   'gemini-3-flash-preview', 5000, 100, 5100, true,  now() - interval '10 days'),
  -- plus user (an admin moved them to pro in test_ai_plans.sql): 3 chats, 2 days ago
  ('00000000-0000-0000-0000-000000000003', 'chat',   'gemini-3-flash-preview', 400, 50, 450, true, now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000000003', 'chat',   'gemini-3-flash-preview', 400, 50, 450, true, now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000000003', 'chat',   'gemini-3-flash-preview', 400, 50, 450, true, now() - interval '2 days'),
  -- guest chat
  (null, 'chat', 'gemini-3-flash-preview', 300, 20, 320, true, now() - interval '5 minutes');
reset role;

-- A customer (authenticated, not admin) is refused and cannot read or write events.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
begin
  begin
    perform public.admin_ai_usage(null);
    raise exception 'customer could call admin_ai_usage';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.ai_usage_events (user_id, kind) values ('00000000-0000-0000-0000-000000000001', 'render');
    raise exception 'customer could insert a usage event';
  exception when insufficient_privilege then null;
  end;
  assert (select count(*) from public.ai_usage_events) = 0, 'customer reads no usage events';
end;
$$;
reset role;

set role anon;
do $$
begin
  begin
    perform public.admin_ai_usage(null);
    raise exception 'anon could call admin_ai_usage';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;

-- Admin sees aggregated rows, heaviest first, and the period filter works.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000005';
do $$
declare r record; n integer;
begin
  assert (select count(*) from public.ai_usage_events) = 8, 'admin reads all events';

  select count(*) into n from public.admin_ai_usage(null);
  assert n = 3, format('all time: 3 rows (trial, plus, guests), got %s', n);

  select * into r from public.admin_ai_usage(null) limit 1;
  assert r.user_id = '00000000-0000-0000-0000-000000000001' and r.email = 'trial@test.local'
     and r.plan = 'trial' and r.renders = 2 and r.chats = 1 and r.failed = 1
     and r.prompt_tokens = 7000 and r.output_tokens = 2700 and r.total_tokens = 9700
     and r.last_used > now() - interval '61 minutes', format('heaviest row: %s', r);

  select * into r from public.admin_ai_usage(null) where user_id = '00000000-0000-0000-0000-000000000003';
  assert r.plan = 'pro' and r.chats = 3 and r.renders = 0 and r.total_tokens = 1350, format('plus row: %s', r);

  select * into r from public.admin_ai_usage(null) where user_id is null;
  assert r.chats = 1 and r.email is null and r.plan is null, format('guest row: %s', r);

  -- 7 days: the trial user's 10-day-old chat drops out
  select * into r from public.admin_ai_usage(now() - interval '7 days') where user_id = '00000000-0000-0000-0000-000000000001';
  assert r.chats = 0 and r.renders = 2 and r.total_tokens = 4600, format('7-day trial row: %s', r);

  -- 1 day: the plus user has no usage, so no row
  select count(*) into n from public.admin_ai_usage(now() - interval '1 day');
  assert n = 2, format('1-day rows: %s', n);
  assert not exists (select 1 from public.admin_ai_usage(now() - interval '1 day') where user_id = '00000000-0000-0000-0000-000000000003'),
    'plus user absent in 1-day window';
end;
$$;
reset role;

-- An admin with usage shows their profile name.
set role service_role;
insert into public.ai_usage_events (user_id, kind, total_tokens) values ('00000000-0000-0000-0000-000000000005', 'chat', 10);
reset role;
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000005';
do $$ begin
  assert (select full_name from public.admin_ai_usage(null) where user_id = '00000000-0000-0000-0000-000000000005') = 'Asha Admin', 'full_name joined';
end $$;
reset role;

\echo 'ALL AI USAGE TESTS PASSED'
