-- AI usage per account (admin "AI Usage" screen).
--
-- One row per Gemini call made by the Vercel API: AI Studio renders
-- (api/generate-visualization.js) and Aarna chat replies (api/aarna.js), with
-- the token counts Gemini reports in usageMetadata. Aarna allows signed-out
-- users, so user_id is null for guests (and for accounts deleted later).
--
-- Written only by the service role; admins read it through admin_ai_usage().
-- Depends on 20261030000000_ai_plans.sql (ai_effective_plan).
-- Safe to run more than once.

create table if not exists public.ai_usage_events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  kind text not null check (kind in ('render', 'chat')),
  model text,
  prompt_tokens integer,
  output_tokens integer,
  total_tokens integer,
  ok boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists ai_usage_events_user_created_idx on public.ai_usage_events (user_id, created_at);
create index if not exists ai_usage_events_created_idx on public.ai_usage_events (created_at);

alter table public.ai_usage_events enable row level security;

drop policy if exists "Admins can read AI usage events" on public.ai_usage_events;
create policy "Admins can read AI usage events"
  on public.ai_usage_events for select
  using (public.is_admin());

-- No insert/update/delete policies, so RLS already refuses client writes;
-- dropping the table privileges as well makes that explicit.
revoke insert, update, delete on public.ai_usage_events from anon, authenticated;

-- ---------------------------------------------------------------------------
-- admin_ai_usage: one row per account with any usage since p_since (null = all
-- time), heaviest first. Guests / deleted accounts come back as one row with
-- user_id null. renders / chats count successful calls; failed counts the rest.
-- ---------------------------------------------------------------------------
create or replace function public.admin_ai_usage(p_since timestamptz default null)
returns table (
  user_id uuid,
  email text,
  full_name text,
  plan text,
  renders bigint,
  chats bigint,
  prompt_tokens bigint,
  output_tokens bigint,
  total_tokens bigint,
  failed bigint,
  last_used timestamptz
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
    with agg as (
      select
        e.user_id,
        count(*) filter (where e.kind = 'render' and e.ok) as renders,
        count(*) filter (where e.kind = 'chat' and e.ok) as chats,
        coalesce(sum(e.prompt_tokens), 0)::bigint as prompt_tokens,
        coalesce(sum(e.output_tokens), 0)::bigint as output_tokens,
        coalesce(sum(e.total_tokens), 0)::bigint as total_tokens,
        count(*) filter (where not e.ok) as failed,
        max(e.created_at) as last_used
      from public.ai_usage_events e
      where p_since is null or e.created_at >= p_since
      group by e.user_id
    )
    select
      a.user_id,
      u.email::text,
      p.full_name::text,
      case when a.user_id is null then null else (select ep.plan from public.ai_effective_plan(a.user_id) ep) end,
      a.renders,
      a.chats,
      a.prompt_tokens,
      a.output_tokens,
      a.total_tokens,
      a.failed,
      a.last_used
    from agg a
    left join auth.users u on u.id = a.user_id
    left join public.profiles p on p.id = a.user_id
    order by a.total_tokens desc, a.renders desc, a.chats desc, a.last_used desc;
end;
$$;

revoke all on function public.admin_ai_usage(timestamptz) from public, anon;
grant execute on function public.admin_ai_usage(timestamptz) to authenticated, service_role;
