-- Admin accounts (profiles.role = 'admin') are not limited by the AI render
-- plans: consume_ai_render still counts their renders (for the usage view) but
-- never refuses them. Customers keep the plan limits from ai_plan_limits.
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
  is_admin_user boolean := exists (
    select 1 from public.profiles where profiles.id = p_user and profiles.role = 'admin'
  );
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

  if not is_admin_user and u.monthly_limit is not null and c.month_count >= u.monthly_limit then
    return query select false, 'monthly_limit'::text, g.* from public.get_ai_usage(p_user) g;
    return;
  end if;
  if not is_admin_user and c.daily_count >= u.daily_limit then
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
revoke all on function public.consume_ai_render(uuid) from public, anon, authenticated;
grant execute on function public.consume_ai_render(uuid) to service_role;
