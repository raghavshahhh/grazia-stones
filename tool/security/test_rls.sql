-- Attack tests for the RLS / triggers in supabase/schema.sql + supabase/migrations/*.
-- NEVER run against Supabase: tool/security/run_rls_tests.sh loads everything into a throwaway Postgres first.
-- Every check raises on failure, so the script exits non-zero on the first broken guarantee.
\set ON_ERROR_STOP 1
set client_min_messages = warning;

-- Users: A and B customers, ADM admin, C an auth user whose profile row is missing (legacy accounts).
insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'a@test'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'b@test'),
  ('adadadad-0000-0000-0000-000000000003', 'adm@test');
update public.profiles set role = 'admin' where id = 'adadadad-0000-0000-0000-000000000003';
alter table public.profiles disable trigger user;
insert into auth.users (id, email) values ('cccccccc-0000-0000-0000-000000000004', 'c@test');
delete from public.profiles where id = 'cccccccc-0000-0000-0000-000000000004';
alter table public.profiles enable trigger user;

insert into public.collections (id, name, slug, active) values ('c0000000-0000-0000-0000-000000000001', 'Col', 'col', true);
insert into public.stones (id, name, slug, active) values ('50000000-0000-0000-0000-000000000001', 'Stone', 'stone', true);
insert into public.addresses (user_id, label, name, phone, address_line1, city, state, pincode)
  values ('bbbbbbbb-0000-0000-0000-000000000002', 'Home', 'B', '1', 'x', 'x', 'x', '1');
insert into public.quote_requests (user_id, name, phone) values ('bbbbbbbb-0000-0000-0000-000000000002', 'B', '1');
insert into public.orders (id, user_id, order_number) values
  ('0d000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000001', 'ORD-A'),
  ('0d000000-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-000000000002', 'ORD-B');
insert into storage.objects (bucket_id, name) values
  ('ai-visualizations', 'bbbbbbbb-0000-0000-0000-000000000002/room.png'),
  ('ai-visualizations', 'aaaaaaaa-0000-0000-0000-000000000001/room.png'),
  ('stones', 'products/stone.jpg');

-- Helpers. act() switches to a caller the way PostgREST does (role + JWT claims, transaction-local).
create or replace function act(who text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', case who
    when 'A' then 'aaaaaaaa-0000-0000-0000-000000000001' when 'B' then 'bbbbbbbb-0000-0000-0000-000000000002'
    when 'ADM' then 'adadadad-0000-0000-0000-000000000003' when 'C' then 'cccccccc-0000-0000-0000-000000000004'
    else '' end, true);
  perform set_config('request.jwt.claim.role', case when who = 'anon' then 'anon' else 'authenticated' end, true);
  perform set_config('role', case when who = 'anon' then 'anon' else 'authenticated' end, true);
end $$;

-- Statement must raise, or touch 0 rows.
create or replace function denied(label text, stmt text) returns void language plpgsql as $$
declare n bigint;
begin
  begin
    execute stmt;
    get diagnostics n = row_count;
  exception when insufficient_privilege or program_limit_exceeded then
    return; -- 42501 = RLS / grant / trigger refusal, 54000 = flood guard
  when others then
    raise exception 'FAIL (wrong error %: %): %', sqlstate, sqlerrm, label;
  end;
  if n > 0 then raise exception 'FAIL (allowed, % rows): %', n, label; end if;
end $$;

create or replace function allowed(label text, stmt text) returns void language plpgsql as $$
begin
  execute stmt;
exception when others then
  raise exception 'FAIL (blocked: %): %', sqlerrm, label;
end $$;

create or replace function rows_seen(label text, q text, expected bigint) returns void language plpgsql as $$
declare n bigint;
begin
  execute format('select count(*) from (%s) t', q) into n;
  if n <> expected then raise exception 'FAIL: % saw % rows, expected %', label, n, expected; end if;
end $$;
grant execute on function act(text), denied(text, text), allowed(text, text), rows_seen(text, text, bigint)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Anonymous caller (public anon key)
-- ---------------------------------------------------------------------------
begin; select act('anon');
select rows_seen('anon profiles', 'select * from public.profiles', 0);
select rows_seen('anon orders', 'select * from public.orders', 0);
select rows_seen('anon quotes', 'select * from public.quote_requests', 0);
select rows_seen('anon addresses', 'select * from public.addresses', 0);
select rows_seen('anon storage list', 'select * from storage.objects', 0);
select rows_seen('anon stones (public catalogue)', 'select * from public.stones', 1);
select rows_seen('anon admin_users (no recursion error)', 'select * from public.admin_users', 0);
select denied('anon audit log forge', $q$insert into public.audit_logs (action, entity_type) values ('x', 'y')$q$);
select denied('anon quote as B', $q$insert into public.quote_requests (user_id, name, phone) values ('bbbbbbbb-0000-0000-0000-000000000002', 'x', '1')$q$);
select denied('anon quote preset status', $q$insert into public.quote_requests (name, phone, status) values ('x', '1', 'approved')$q$);
select denied('anon sample preset status', $q$insert into public.sample_requests (name, phone, stone_name, status) values ('x', '1', 's', 'shipped')$q$);
select denied('anon notification to B', $q$insert into public.notifications (user_id, title, body) values ('bbbbbbbb-0000-0000-0000-000000000002', 'x', 'y')$q$);
select denied('anon stone edit', $q$update public.stones set name = 'pwned'$q$);
select denied('anon upload to stones bucket', $q$insert into storage.objects (bucket_id, name) values ('stones', 'x.jpg')$q$);
select denied('anon consume_ai_render', $q$select public.consume_ai_render('aaaaaaaa-0000-0000-0000-000000000001')$q$);
select allowed('anon guest quote (old builds)', $q$insert into public.quote_requests (name, phone) values ('Guest', '1')$q$);
rollback;

-- ---------------------------------------------------------------------------
-- Customer A
-- ---------------------------------------------------------------------------
begin; select act('A');
select rows_seen('A profiles', 'select * from public.profiles', 1);
select rows_seen('A addresses (B has one)', 'select * from public.addresses', 0);
select rows_seen('A quotes (B has one)', 'select * from public.quote_requests', 0);
select rows_seen('A orders', 'select * from public.orders', 1);
select rows_seen('A subscriptions', 'select * from public.subscriptions', 0);
select rows_seen('A storage (sees own folder only)', 'select * from storage.objects', 1);
select rows_seen('A is_admin', 'select 1 where public.is_admin()', 0);
-- role escalation
select denied('A role -> admin', $q$update public.profiles set role = 'admin' where id = auth.uid()$q$);
select denied('A role -> dealer', $q$update public.profiles set role = 'dealer' where id = auth.uid()$q$);
select denied('A edits B profile', $q$update public.profiles set full_name = 'x' where id = 'bbbbbbbb-0000-0000-0000-000000000002'$q$);
select denied('A moves own profile id onto B', $q$update public.profiles set id = 'bbbbbbbb-0000-0000-0000-000000000002' where id = auth.uid()$q$);
select allowed('A edits own name', $q$update public.profiles set full_name = 'A New' where id = auth.uid()$q$);
-- catalogue / prices
select denied('A edits stone price', $q$update public.stones set price_per_sqft = 1$q$);
select denied('A deletes stone', $q$delete from public.stones$q$);
select denied('A adds stone', $q$insert into public.stones (name, slug) values ('x', 'x')$q$);
select denied('A edits collection', $q$update public.collections set name = 'x'$q$);
select denied('A edits plan limits', $q$update public.ai_plan_limits set daily_limit = 9999$q$);
-- plans / AI quota
select denied('A grants self subscription', $q$insert into public.subscriptions (user_id, plan, source, status, period_end) values (auth.uid(), 'pro', 'admin', 'active', now() + interval '1 year')$q$);
select denied('A edits ai_credits', $q$insert into public.ai_credits (user_id, credits_remaining, daily_count) values (auth.uid(), 99999, 0)$q$);
select denied('A admin_set_plan', $q$select public.admin_set_plan(auth.uid(), 'pro', 365, null)$q$);
select denied('A admin_find_user', $q$select public.admin_find_user('b@test')$q$);
select denied('A admin_ai_usage', $q$select public.admin_ai_usage(null)$q$);
select denied('A consume_ai_render', $q$select public.consume_ai_render(auth.uid())$q$);
select denied('A refund_ai_render', $q$select public.refund_ai_render(auth.uid())$q$);
select denied('A get_ai_usage of B', $q$select public.get_ai_usage('bbbbbbbb-0000-0000-0000-000000000002')$q$);
select denied('A writes ai_usage_events', $q$insert into public.ai_usage_events (kind) values ('render')$q$);
-- orders / money
select denied('A inserts paid order', $q$insert into public.orders (user_id, order_number, payment_status) values (auth.uid(), 'X1', 'paid')$q$);
select denied('A inserts confirmed order', $q$insert into public.orders (user_id, order_number, status) values (auth.uid(), 'X2', 'confirmed')$q$);
select denied('A inserts order for B', $q$insert into public.orders (user_id, order_number) values ('bbbbbbbb-0000-0000-0000-000000000002', 'X3')$q$);
select denied('A adds item to B order', $q$insert into public.order_items (order_id, name, unit_price, total_price) values ('0d000000-0000-0000-0000-00000000000b', 'x', 1, 1)$q$);
select denied('A edits B order', $q$update public.orders set notes = 'x' where id = '0d000000-0000-0000-0000-00000000000b'$q$);
select allowed('A inserts pending order (checkout)', $q$insert into public.orders (user_id, order_number, total) values (auth.uid(), 'X4', 100)$q$);
-- leads / notifications
select denied('A quote as B', $q$insert into public.quote_requests (user_id, name, phone) values ('bbbbbbbb-0000-0000-0000-000000000002', 'x', '1')$q$);
select denied('A quote with admin notes', $q$insert into public.quote_requests (user_id, name, phone, admin_notes) values (auth.uid(), 'x', '1', 'vip')$q$);
select denied('A sample as B', $q$insert into public.sample_requests (user_id, name, phone, stone_name) values ('bbbbbbbb-0000-0000-0000-000000000002', 'x', '1', 's')$q$);
select denied('A sample with tracking', $q$insert into public.sample_requests (user_id, name, phone, stone_name, tracking_number) values (auth.uid(), 'x', '1', 's', 'T1')$q$);
select denied('A notification to B', $q$insert into public.notifications (user_id, title, body) values ('bbbbbbbb-0000-0000-0000-000000000002', 'x', 'y')$q$);
select denied('A edits B quote', $q$update public.quote_requests set status = 'approved'$q$);
select allowed('A own quote', $q$insert into public.quote_requests (user_id, name, phone) values (auth.uid(), 'A', '1')$q$);
select allowed('A own sample', $q$insert into public.sample_requests (user_id, name, phone, stone_name, status) values (auth.uid(), 'A', '1', 's', 'pending')$q$);
-- other users' private rows
select denied('A edits B address', $q$update public.addresses set city = 'x'$q$);
select denied('A deletes B address', $q$delete from public.addresses$q$);
select denied('A moves address onto B', $q$insert into public.addresses (user_id, label, name, phone, address_line1, city, state, pincode) values ('bbbbbbbb-0000-0000-0000-000000000002', 'x', 'x', '1', 'x', 'x', 'x', '1')$q$);
select denied('A cart for B', $q$insert into public.cart_items (user_id, stone_id, unit_price) values ('bbbbbbbb-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', 1)$q$);
select denied('A wishlist for B', $q$insert into public.wishlist_items (user_id, stone_id) values ('bbbbbbbb-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001')$q$);
select denied('A ai_job for B', $q$insert into public.ai_jobs (user_id, input_image_url) values ('bbbbbbbb-0000-0000-0000-000000000002', 'x')$q$);
select denied('A audit log', $q$insert into public.audit_logs (action, entity_type) values ('x', 'y')$q$);
-- storage
select denied('A uploads into B folder', $q$insert into storage.objects (bucket_id, name) values ('ai-visualizations', 'bbbbbbbb-0000-0000-0000-000000000002/x.png')$q$);
select denied('A uploads avatar into B folder', $q$insert into storage.objects (bucket_id, name) values ('avatars', 'bbbbbbbb-0000-0000-0000-000000000002/a.png')$q$);
select denied('A uploads into stones bucket', $q$insert into storage.objects (bucket_id, name) values ('stones', 'products/evil.jpg')$q$);
select denied('A overwrites product image', $q$update storage.objects set name = 'products/evil.jpg' where bucket_id = 'stones'$q$);
select denied('A deletes product image', $q$delete from storage.objects where bucket_id = 'stones'$q$);
select denied('A deletes B file', $q$delete from storage.objects where name like 'bbbbbbbb%'$q$);
select allowed('A uploads own avatar', $q$insert into storage.objects (bucket_id, name) values ('avatars', 'aaaaaaaa-0000-0000-0000-000000000001/a.png')$q$);
rollback;

-- Customer A again: cancelling own pending order still works, marking it paid does not.
begin; select act('A');
select allowed('A cancels pending order', $q$update public.orders set status = 'cancelled' where id = '0d000000-0000-0000-0000-00000000000a'$q$);
rollback;
begin; select act('A');
select denied('A marks own order paid', $q$update public.orders set payment_status = 'paid' where id = '0d000000-0000-0000-0000-00000000000a'$q$);
select denied('A rewrites own order total', $q$update public.orders set total = 1 where id = '0d000000-0000-0000-0000-00000000000a'$q$);
select allowed('A marks payment attempt failed', $q$update public.orders set payment_status = 'failed' where id = '0d000000-0000-0000-0000-00000000000a'$q$);
rollback;

-- Legacy user C with no profile row cannot create one as admin.
begin; select act('C');
insert into public.profiles (id, role) values ('cccccccc-0000-0000-0000-000000000004', 'admin');
select rows_seen('C self-insert stays customer', $q$select 1 from public.profiles where id = auth.uid() and role = 'customer'$q$, 1);
rollback;

-- Lead flood guard: the 11th quote in an hour from one user is refused.
begin; select act('A');
select allowed('A quote ' || g, $q$insert into public.quote_requests (user_id, name, phone) values (auth.uid(), 'A', '1')$q$) from generate_series(1, 10) g;
select denied('A 11th quote in an hour', $q$insert into public.quote_requests (user_id, name, phone) values (auth.uid(), 'A', '1')$q$);
rollback;

-- ---------------------------------------------------------------------------
-- Admin keeps working
-- ---------------------------------------------------------------------------
begin; select act('ADM');
select rows_seen('ADM sees all profiles', 'select * from public.profiles', 3);
select allowed('ADM edits stone', $q$update public.stones set name = 'Stone 2'$q$);
select allowed('ADM marks order paid', $q$update public.orders set payment_status = 'paid', status = 'confirmed' where id = '0d000000-0000-0000-0000-00000000000b'$q$);
select allowed('ADM promotes B to dealer', $q$update public.profiles set role = 'dealer' where id = 'bbbbbbbb-0000-0000-0000-000000000002'$q$);
select allowed('ADM sets plan', $q$select public.admin_set_plan('aaaaaaaa-0000-0000-0000-000000000001', 'pro', 30, 'test')$q$);
select allowed('ADM uploads product image', $q$insert into storage.objects (bucket_id, name) values ('stones', 'products/new.jpg')$q$);
select rows_seen('ADM reads admin_users', 'select * from public.admin_users', 0);
rollback;

-- Service role (server) is not limited by the order trigger.
begin;
select set_config('role', 'service_role', true);
select allowed('service marks order paid', $q$update public.orders set payment_status = 'paid' where id = '0d000000-0000-0000-0000-00000000000a'$q$);
rollback;

-- Oversized lead text is refused (check constraint, 23514).
begin; select act('anon');
do $$ begin
  insert into public.quote_requests (name, phone, message) values ('x', '1', repeat('a', 20000));
  raise exception 'FAIL: 20k-char quote message accepted';
exception when check_violation then null;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- Dealer panel: A becomes a dealer and gets B's quote assigned
-- ---------------------------------------------------------------------------
begin;
alter table public.profiles disable trigger user;
update public.profiles set role = 'dealer' where id = 'aaaaaaaa-0000-0000-0000-000000000001';
alter table public.profiles enable trigger user;
update public.quote_requests set assigned_dealer = 'aaaaaaaa-0000-0000-0000-000000000001' where user_id = 'bbbbbbbb-0000-0000-0000-000000000002';
insert into public.quote_requests (name, phone) values ('Unassigned', '1');
select act('A');
select rows_seen('dealer sees only assigned quotes', 'select * from public.quote_requests', 1);
select allowed('dealer moves status + notes', $q$update public.quote_requests set status = 'contacted', dealer_notes = 'called' where assigned_dealer = auth.uid()$q$);
select denied('dealer edits customer phone', $q$update public.quote_requests set phone = '999' where assigned_dealer = auth.uid()$q$);
select denied('dealer writes admin notes', $q$update public.quote_requests set admin_notes = 'x' where assigned_dealer = auth.uid()$q$);
select denied('dealer unassigns self', $q$update public.quote_requests set assigned_dealer = null where assigned_dealer = auth.uid()$q$);
select denied('dealer edits unassigned quote', $q$update public.quote_requests set status = 'quoted' where name = 'Unassigned'$q$);
select act('B');
select denied('customer picks a dealer', $q$insert into public.quote_requests (user_id, name, phone, assigned_dealer) values (auth.uid(), 'B', '1', 'aaaaaaaa-0000-0000-0000-000000000001')$q$);
select denied('customer edits dealer notes', $q$update public.quote_requests set dealer_notes = 'x'$q$);
select act('ADM');
select allowed('ADM reassigns quote', $q$update public.quote_requests set assigned_dealer = null where name = 'B'$q$);
rollback;

select 'ALL RLS ATTACK TESTS PASSED' as result;
