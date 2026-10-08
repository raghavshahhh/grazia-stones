-- AI Studio usage limits: every user gets SIGNUP credits once, and can spend at
-- most DAILY_LIMIT per calendar day (India time). More credits are added by
-- raising credits_remaining (admin / future payment flow).
-- Only the Vercel API (service role) may spend or refund credits; clients can
-- only read their own balance.

create table if not exists public.ai_credits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  credits_remaining integer not null default 12 check (credits_remaining >= 0),
  daily_count integer not null default 0 check (daily_count >= 0),
  daily_date date not null default ((now() at time zone 'Asia/Kolkata')::date),
  updated_at timestamptz not null default now()
);

alter table public.ai_credits enable row level security;

drop policy if exists "Users can read own AI credits" on public.ai_credits;
create policy "Users can read own AI credits"
  on public.ai_credits for select
  using (auth.uid() = user_id);

-- Returns one row: ok, reason ('daily_limit' | 'no_credits' | null),
-- credits_remaining, daily_remaining.
create or replace function public.consume_ai_credit(
  p_user uuid,
  p_daily_limit integer default 3,
  p_signup_credits integer default 12
)
returns table (ok boolean, reason text, credits_remaining integer, daily_remaining integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := (now() at time zone 'Asia/Kolkata')::date;
  row public.ai_credits%rowtype;
begin
  insert into public.ai_credits (user_id, credits_remaining, daily_count, daily_date)
  values (p_user, p_signup_credits, 0, today)
  on conflict (user_id) do nothing;

  select * into row from public.ai_credits where user_id = p_user for update;

  if row.daily_date <> today then
    row.daily_count := 0;
    row.daily_date := today;
  end if;

  if row.daily_count >= p_daily_limit then
    update public.ai_credits
      set daily_count = row.daily_count, daily_date = row.daily_date, updated_at = now()
      where user_id = p_user;
    return query select false, 'daily_limit'::text, row.credits_remaining, 0;
    return;
  end if;

  if row.credits_remaining <= 0 then
    return query select false, 'no_credits'::text, 0, greatest(p_daily_limit - row.daily_count, 0);
    return;
  end if;

  update public.ai_credits
    set credits_remaining = row.credits_remaining - 1,
        daily_count = row.daily_count + 1,
        daily_date = row.daily_date,
        updated_at = now()
    where user_id = p_user;

  return query select true, null::text, row.credits_remaining - 1, p_daily_limit - (row.daily_count + 1);
end;
$$;

-- Give back one credit when generation failed after it was spent.
create or replace function public.refund_ai_credit(p_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ai_credits
    set credits_remaining = credits_remaining + 1,
        daily_count = greatest(daily_count - 1, 0),
        updated_at = now()
    where user_id = p_user;
$$;

-- Read-only balance for the app (does not spend anything).
create or replace function public.get_ai_credits(
  p_user uuid,
  p_daily_limit integer default 3,
  p_signup_credits integer default 12
)
returns table (credits_remaining integer, daily_remaining integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := (now() at time zone 'Asia/Kolkata')::date;
  row public.ai_credits%rowtype;
begin
  select * into row from public.ai_credits where user_id = p_user;
  if not found then
    return query select p_signup_credits, p_daily_limit;
    return;
  end if;
  if row.daily_date <> today then
    row.daily_count := 0;
  end if;
  return query select row.credits_remaining, greatest(p_daily_limit - row.daily_count, 0);
end;
$$;

revoke all on function public.consume_ai_credit(uuid, integer, integer) from public, anon, authenticated;
revoke all on function public.refund_ai_credit(uuid) from public, anon, authenticated;
revoke all on function public.get_ai_credits(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.consume_ai_credit(uuid, integer, integer) to service_role;
grant execute on function public.refund_ai_credit(uuid) to service_role;
grant execute on function public.get_ai_credits(uuid, integer, integer) to service_role;
