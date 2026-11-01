-- Security hardening, round 2 (2026-11-01 review). Idempotent; safe to re-run.
-- Tested locally by tool/security/run_rls_tests.sh (throwaway Postgres, never Supabase).

-- 1. orders: a customer could insert (and, if prod has an untracked user UPDATE policy, edit) their own
--    order with payment_status 'paid' / status 'confirmed' / a tracking number, and the admin Orders
--    screen would show it as paid. A trigger (not a policy) so it also covers any drifted prod policy.
--    Admins, service_role and SQL (auth.uid() null) are untouched. jsonb so columns missing in prod
--    (razorpay_payment_id, razorpay_signature) do not break it.
create or replace function public.enforce_order_customer_fields()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  n jsonb := to_jsonb(new);
  o jsonb;
  k text;
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if coalesce(n->>'status', 'pending') <> 'pending' or coalesce(n->>'payment_status', 'pending') <> 'pending' then
      raise exception 'new orders must be pending' using errcode = '42501';
    end if;
    foreach k in array array['payment_id', 'razorpay_payment_id', 'razorpay_signature', 'tracking_number',
                             'carrier', 'shipped_at', 'delivered_at'] loop
      if n->>k is not null then
        raise exception 'column % is staff-only', k using errcode = '42501';
      end if;
    end loop;
    return new;
  end if;

  o := to_jsonb(old);
  foreach k in array array['user_id', 'order_number', 'subtotal', 'shipping_cost', 'tax', 'discount', 'total',
                           'currency', 'payment_id', 'razorpay_payment_id', 'razorpay_signature',
                           'tracking_number', 'carrier', 'shipped_at', 'delivered_at'] loop
    if (n->k) is distinct from (o->k) then
      raise exception 'column % is staff-only', k using errcode = '42501';
    end if;
  end loop;
  -- What the app itself does as a customer: cancel a pending order, mark a payment attempt.
  if (n->'status') is distinct from (o->'status')
     and not (o->>'status' = 'pending' and n->>'status' = 'cancelled') then
    raise exception 'customers can only cancel a pending order' using errcode = '42501';
  end if;
  if (n->'payment_status') is distinct from (o->'payment_status')
     and not (n->>'payment_status' in ('initiated', 'failed') and o->>'payment_status' in ('pending', 'initiated', 'failed')) then
    raise exception 'payment status is set by the server' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_order_customer_fields on public.orders;
create trigger enforce_order_customer_fields
  before insert or update on public.orders
  for each row execute function public.enforce_order_customer_fields();

-- 2. sample_requests: same guard quotes got in 20261101 (status / staff fields are staff-only).
drop policy if exists "Anyone can create sample requests" on public.sample_requests;
create policy "Anyone can create sample requests"
  on public.sample_requests for insert
  with check (
    (user_id is null or user_id = auth.uid())
    and coalesce(status, 'pending') = 'pending'
    and admin_notes is null
    and tracking_number is null
  );

-- 3. Flood guard for lead forms. Anyone holding the public anon key can insert quotes/samples, and the
--    API has no rate limit, so a script could bury the admin inbox. Limits are generous for people:
--    10 per signed-in user per hour; guests (old app builds) share 30 per 10 minutes in total.
-- ponytail: global guest bucket, so a flood also delays real guest leads; per-IP limits need an API in front.
create or replace function public.limit_lead_inserts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent integer;
begin
  if auth.role() is distinct from 'anon' and auth.role() is distinct from 'authenticated' then
    return new; -- service_role / SQL
  end if;
  if new.user_id is null then
    execute format('select count(*) from public.%I where user_id is null and created_at > now() - interval ''10 minutes''', tg_table_name)
      into recent;
    if recent >= 30 then
      raise exception 'too many requests, please try again shortly' using errcode = '54000';
    end if;
  else
    execute format('select count(*) from public.%I where user_id = $1 and created_at > now() - interval ''1 hour''', tg_table_name)
      into recent using new.user_id;
    if recent >= 10 then
      raise exception 'too many requests, please try again later' using errcode = '54000';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.limit_lead_inserts() from public, anon, authenticated;

drop trigger if exists limit_lead_inserts on public.quote_requests;
create trigger limit_lead_inserts before insert on public.quote_requests
  for each row execute function public.limit_lead_inserts();
drop trigger if exists limit_lead_inserts on public.sample_requests;
create trigger limit_lead_inserts before insert on public.sample_requests
  for each row execute function public.limit_lead_inserts();

-- 4. admin_users: "Super admins can manage admin users" selects admin_users inside its own policy, so every
--    read of the table (anon included, verified live) fails with 500 "infinite recursion detected in policy",
--    leaking policy internals. The app never uses the table; admins read it, only service_role writes it.
drop policy if exists "Super admins can manage admin users" on public.admin_users;
drop policy if exists "Admins can view admin users" on public.admin_users;
create policy "Admins can view admin users" on public.admin_users for select using (public.is_admin());

-- 5. handle_new_user() is SECURITY DEFINER with no pinned search_path. Pin it without touching its body.
alter function public.handle_new_user() set search_path = public;

-- 6a. 20261101 dropped the blanket bucket SELECT policies by the wrong names for avatars/stones; the names
--     schema.sql creates are these. Prod listing is already closed (checked live 2026-11-01); this makes a
--     fresh database from the repo match it.
drop policy if exists "Stone images publicly viewable" on storage.objects;
drop policy if exists "Avatar images publicly viewable" on storage.objects;

-- 6. Public buckets accepted any file type, so the Grazia storage domain could host attacker HTML/SVG or
--    malware under a public URL. The app only ever uploads photos to these three buckets.
update storage.buckets
  set allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'image/gif'],
      file_size_limit = 10485760
  where id in ('avatars', 'ai-visualizations', 'ar-screenshots');

-- 7. Lead / profile text had no length limit, so one anon insert could store megabytes of text that the
--    admin screens then load. Limits are far above what the app's forms send. NOT VALID: old rows are left
--    alone, new writes are checked. Columns missing in a drifted database are skipped.
do $$
declare r record;
begin
  for r in select * from (values
    ('quote_requests', 'name', 200), ('quote_requests', 'email', 320), ('quote_requests', 'phone', 40),
    ('quote_requests', 'company', 200), ('quote_requests', 'stone_name', 500), ('quote_requests', 'message', 10000),
    ('sample_requests', 'name', 200), ('sample_requests', 'email', 320), ('sample_requests', 'phone', 40),
    ('sample_requests', 'company', 200), ('sample_requests', 'address', 1000), ('sample_requests', 'city', 100),
    ('sample_requests', 'state', 100), ('sample_requests', 'pincode', 20), ('sample_requests', 'stone_name', 500),
    ('sample_requests', 'message', 10000),
    ('profiles', 'full_name', 200), ('profiles', 'phone', 40), ('profiles', 'email', 320), ('profiles', 'avatar_url', 2000)
  ) v(t, c, n)
  loop
    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = r.t and column_name = r.c)
       and not exists (select 1 from pg_constraint where conname = r.t || '_' || r.c || '_len') then
      execute format('alter table public.%I add constraint %I check (length(%I) <= %s) not valid',
                     r.t, r.t || '_' || r.c || '_len', r.c, r.n);
    end if;
  end loop;
end $$;
