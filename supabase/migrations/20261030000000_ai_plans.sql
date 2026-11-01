-- AI Studio plans (contract: docs/subscriptions_contract.md, 2026-10-30).
--
-- AI Room Studio renders are the only gated feature. Every user is on exactly
-- one effective plan, worked out at read time:
--   1. an ACTIVE row in public.subscriptions whose period_end is in the future
--      (plus / pro, bought in Google Play / App Store, or granted by an admin)
--   2. else 'trial' for the first 7 days after auth.users.created_at
--   3. else 'free'
-- Limits per plan live in public.ai_plan_limits so they can change without an
-- app release. Usage counters live on the existing public.ai_credits row:
-- daily_count/daily_date (calendar day, Asia/Kolkata) and the new
-- month_count/month_key ('YYYY-MM', calendar month, Asia/Kolkata).
--
-- Spending and refunding happen only from the Vercel API with the service role.
-- The old consume_ai_credit / refund_ai_credit / get_ai_credits functions from
-- 20261009000000_ai_credits.sql are left untouched for old app builds.
--
-- Safe to run more than once.

-- ---------------------------------------------------------------------------
-- Plan limits (single source of truth)
-- ---------------------------------------------------------------------------
create table if not exists public.ai_plan_limits (
  plan text primary key check (plan in ('trial', 'free', 'plus', 'pro')),
  monthly_limit integer check (monthly_limit is null or monthly_limit >= 0), -- null = no monthly cap
  daily_limit integer not null check (daily_limit >= 0)
);

-- Seed only; a re-run never overwrites limits an admin has changed since.
insert into public.ai_plan_limits (plan, monthly_limit, daily_limit) values
  ('trial', null, 10),
  ('free', 3, 3),
  ('plus', 60, 10),
  ('pro', 200, 25)
on conflict (plan) do nothing;

alter table public.ai_plan_limits enable row level security;

drop policy if exists "Authenticated users can read AI plan limits" on public.ai_plan_limits;
create policy "Authenticated users can read AI plan limits"
  on public.ai_plan_limits for select
  to authenticated
  using (true);

drop policy if exists "Admins can manage AI plan limits" on public.ai_plan_limits;
create policy "Admins can manage AI plan limits"
  on public.ai_plan_limits for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Subscriptions: one row per user. Written only by the service role
-- (api/verify-purchase.js) or by admin_set_plan(); clients can only read.
-- ---------------------------------------------------------------------------
create table if not exists public.subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null check (plan in ('plus', 'pro')),
  source text not null check (source in ('google_play', 'app_store', 'admin')),
  status text not null default 'active' check (status in ('active', 'canceled', 'expired')),
  product_id text,
  -- Android: Play purchase token. iOS: originalTransactionId (stable across renewals).
  purchase_token text,
  period_end timestamptz not null,
  note text,
  granted_by uuid,
  updated_at timestamptz not null default now()
);

-- One store purchase can entitle only one account (blocks sharing a token).
create unique index if not exists subscriptions_purchase_token_key
  on public.subscriptions (purchase_token)
  where purchase_token is not null;

alter table public.subscriptions enable row level security;

drop policy if exists "Users can read own subscription" on public.subscriptions;
create policy "Users can read own subscription"
  on public.subscriptions for select
  using (auth.uid() = user_id);

drop policy if exists "Admins can read all subscriptions" on public.subscriptions;
create policy "Admins can read all subscriptions"
  on public.subscriptions for select
  using (public.is_admin());

-- No insert/update/delete policies exist, so RLS already refuses client writes;
-- dropping the table privileges as well makes that explicit.
revoke insert, update, delete on public.subscriptions from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Monthly counter on the existing usage row
-- ---------------------------------------------------------------------------
alter table public.ai_credits add column if not exists month_count integer not null default 0;
alter table public.ai_credits add column if not exists month_key text; -- 'YYYY-MM' in Asia/Kolkata

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'ai_credits_month_count_check') then
    alter table public.ai_credits add constraint ai_credits_month_count_check check (month_count >= 0);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Effective plan for a user (internal helper, service role only)
-- ---------------------------------------------------------------------------
create or replace function public.ai_effective_plan(p_user uuid)
returns table (plan text, source text, period_end timestamptz, trial_ends_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  with sub as (
    select s.plan, s.source, s.period_end
    from public.subscriptions s
    where s.user_id = p_user
      and s.status = 'active'
      and s.period_end > now()
  ),
  usr as (
    select u.created_at + interval '7 days' as trial_ends_at
    from auth.users u
    where u.id = p_user
  )
  select
    coalesce(sub.plan, case when usr.trial_ends_at > now() then 'trial' else 'free' end),
    sub.source,
    sub.period_end,
    usr.trial_ends_at
  from (select 1) as one
  left join sub on true
  left join usr on true;
$$;

-- ---------------------------------------------------------------------------
-- get_ai_usage: read-only usage snapshot (does not spend anything)
-- resets_at = when the next render becomes possible: start of next IST month
-- if the monthly cap is used up, otherwise next IST midnight.
-- ---------------------------------------------------------------------------
create or replace function public.get_ai_usage(p_user uuid)
returns table (
  plan text,
  source text,
  period_end timestamptz,
  trial_ends_at timestamptz,
  monthly_limit integer,
  monthly_used integer,
  daily_limit integer,
  daily_used integer,
  resets_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  today date := (now() at time zone 'Asia/Kolkata')::date;
  cur_month text := to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM');
  p record;
  l public.ai_plan_limits%rowtype;
  c public.ai_credits%rowtype;
  d_used integer := 0;
  m_used integer := 0;
begin
  select * into p from public.ai_effective_plan(p_user);

  select * into l from public.ai_plan_limits where ai_plan_limits.plan = p.plan;
  if not found then
    raise exception 'ai_plan_limits has no row for plan %', p.plan;
  end if;

  select * into c from public.ai_credits where ai_credits.user_id = p_user;
  if found then
    if c.daily_date = today then d_used := c.daily_count; end if;
    if c.month_key = cur_month then m_used := c.month_count; end if;
  end if;

  return query select
    p.plan,
    p.source,
    p.period_end,
    p.trial_ends_at,
    l.monthly_limit,
    m_used,
    l.daily_limit,
    d_used,
    case
      when l.monthly_limit is not null and m_used >= l.monthly_limit
        then (date_trunc('month', today) + interval '1 month')::timestamp at time zone 'Asia/Kolkata'
      else (today + 1)::timestamp at time zone 'Asia/Kolkata'
    end;
end;
$$;

-- ---------------------------------------------------------------------------
-- consume_ai_render: spend one render if the plan allows it.
-- reason = 'monthly_limit' | 'daily_limit' | null. Monthly is reported first
-- because it is the longer wait. Usage fields are the state after the call.
-- The row lock serialises parallel requests from the same user.
-- ---------------------------------------------------------------------------
create or replace function public.consume_ai_render(p_user uuid)
returns table (
  ok boolean,
  reason text,
  plan text,
  source text,
  period_end timestamptz,
  trial_ends_at timestamptz,
  monthly_limit integer,
  monthly_used integer,
  daily_limit integer,
  daily_used integer,
  resets_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  today date := (now() at time zone 'Asia/Kolkata')::date;
  cur_month text := to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM');
  c public.ai_credits%rowtype;
  u record;
begin
  insert into public.ai_credits (user_id, daily_count, daily_date, month_count, month_key)
  values (p_user, 0, today, 0, cur_month)
  on conflict (user_id) do nothing;

  select * into c from public.ai_credits where ai_credits.user_id = p_user for update;

  -- Roll the windows over before checking limits.
  if c.daily_date <> today then
    c.daily_count := 0;
    c.daily_date := today;
  end if;
  if c.month_key is distinct from cur_month then
    c.month_count := 0;
    c.month_key := cur_month;
  end if;

  select * into u from public.get_ai_usage(p_user);

  if u.monthly_limit is not null and c.month_count >= u.monthly_limit then
    return query select false, 'monthly_limit'::text, g.* from public.get_ai_usage(p_user) g;
    return;
  end if;
  if c.daily_count >= u.daily_limit then
    return query select false, 'daily_limit'::text, g.* from public.get_ai_usage(p_user) g;
    return;
  end if;

  update public.ai_credits
    set daily_count = c.daily_count + 1,
        daily_date = c.daily_date,
        month_count = c.month_count + 1,
        month_key = c.month_key,
        updated_at = now()
    where ai_credits.user_id = p_user;

  return query select true, null::text, g.* from public.get_ai_usage(p_user) g;
end;
$$;

-- ---------------------------------------------------------------------------
-- refund_ai_render: give one render back after a failed generation. Only
-- touches counters that are still in the current day / month window.
-- ---------------------------------------------------------------------------
create or replace function public.refund_ai_render(p_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ai_credits
    set daily_count = case
          when daily_date = (now() at time zone 'Asia/Kolkata')::date then greatest(daily_count - 1, 0)
          else daily_count end,
        month_count = case
          when month_key = to_char((now() at time zone 'Asia/Kolkata'), 'YYYY-MM') then greatest(month_count - 1, 0)
          else month_count end,
        updated_at = now()
    where user_id = p_user;
$$;

revoke all on function public.ai_effective_plan(uuid) from public, anon, authenticated;
revoke all on function public.get_ai_usage(uuid) from public, anon, authenticated;
revoke all on function public.consume_ai_render(uuid) from public, anon, authenticated;
revoke all on function public.refund_ai_render(uuid) from public, anon, authenticated;
grant execute on function public.ai_effective_plan(uuid) to service_role;
grant execute on function public.get_ai_usage(uuid) to service_role;
grant execute on function public.consume_ai_render(uuid) to service_role;
grant execute on function public.refund_ai_render(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- Admin RPCs (called from the app's admin "Plans" screen with the user's JWT).
-- Callable by authenticated, but raise unless public.is_admin() -- the same
-- check every existing admin policy uses.
-- ---------------------------------------------------------------------------

-- p_plan 'plus' | 'pro': grant for p_days from now (source 'admin').
-- p_plan 'free': expire whatever subscription row the user has.
-- Store fields (product_id, purchase_token) are kept so a later store restore
-- still maps to the same user. Returns the user's usage after the change.
create or replace function public.admin_set_plan(
  p_user uuid,
  p_plan text,
  p_days integer default 30,
  p_note text default null
)
returns table (
  plan text,
  source text,
  period_end timestamptz,
  trial_ends_at timestamptz,
  monthly_limit integer,
  monthly_used integer,
  daily_limit integer,
  daily_used integer,
  resets_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;

  if p_plan in ('plus', 'pro') then
    if p_days is null or p_days < 1 or p_days > 3660 then
      raise exception 'p_days must be between 1 and 3660' using errcode = '22023';
    end if;
    insert into public.subscriptions as s (user_id, plan, source, status, period_end, note, granted_by, updated_at)
    values (p_user, p_plan, 'admin', 'active', now() + make_interval(days => p_days), p_note, auth.uid(), now())
    on conflict (user_id) do update
      set plan = excluded.plan,
          source = 'admin',
          status = 'active',
          period_end = excluded.period_end,
          note = excluded.note,
          granted_by = excluded.granted_by,
          updated_at = now();
  elsif p_plan = 'free' then
    update public.subscriptions s
      set status = 'expired',
          period_end = least(s.period_end, now()),
          note = coalesce(p_note, s.note),
          granted_by = auth.uid(),
          updated_at = now()
      where s.user_id = p_user;
  else
    raise exception 'unknown plan %', p_plan using errcode = '22023';
  end if;

  return query select * from public.get_ai_usage(p_user);
end;
$$;

-- Look a customer up by email (case-insensitive) with their current usage.
create or replace function public.admin_find_user(p_email text)
returns table (
  id uuid,
  email text,
  created_at timestamptz,
  plan text,
  source text,
  period_end timestamptz,
  trial_ends_at timestamptz,
  monthly_limit integer,
  monthly_used integer,
  daily_limit integer,
  daily_used integer,
  resets_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;

  return query
    select u.id, u.email::text, u.created_at, g.*
    from auth.users u
    cross join lateral public.get_ai_usage(u.id) g
    where lower(u.email) = lower(trim(p_email))
    limit 5;
end;
$$;

revoke all on function public.admin_set_plan(uuid, text, integer, text) from public, anon;
revoke all on function public.admin_find_user(text) from public, anon;
grant execute on function public.admin_set_plan(uuid, text, integer, text) to authenticated, service_role;
grant execute on function public.admin_find_user(text) to authenticated, service_role;
