-- Dealer panel (contract: "Dealer Panel & Lead Management"). Admins assign a quote request to a dealer account
-- (profiles.role = 'dealer'); the dealer sees only the quotes assigned to them and can move the status and keep
-- private notes. Additive and idempotent: existing rows and the customer / admin policies keep working.

alter table public.quote_requests
  add column if not exists assigned_dealer uuid references public.profiles(id) on delete set null;
create index if not exists quote_requests_assigned_dealer_idx on public.quote_requests (assigned_dealer);

drop policy if exists "Dealers can view assigned quotes" on public.quote_requests;
create policy "Dealers can view assigned quotes" on public.quote_requests
  for select using (assigned_dealer = auth.uid());

drop policy if exists "Dealers can update assigned quotes" on public.quote_requests;
create policy "Dealers can update assigned quotes" on public.quote_requests
  for update using (assigned_dealer = auth.uid()) with check (assigned_dealer = auth.uid());

-- Customers and guests must not pick a dealer when they create a quote.
drop policy if exists "Create own or guest quotes" on public.quote_requests;
create policy "Create own or guest quotes" on public.quote_requests
  for insert with check (
    (user_id is null or user_id = auth.uid())
    and admin_notes is null
    and coalesce(status, 'pending') = 'pending'
    and assigned_dealer is null
  );

-- A dealer may change only the status of their quote (not the customer details, the assignment or admin
-- notes). A trigger, not a policy, because RLS cannot compare old and new values. Admins and SQL bypass it.
create or replace function public.enforce_dealer_quote_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;
  if (to_jsonb(new) - 'status' - 'updated_at') is distinct from (to_jsonb(old) - 'status' - 'updated_at') then
    raise exception 'dealers can only change the status' using errcode = '42501';
  end if;
  if new.status not in ('pending', 'contacted', 'quoted', 'closed') then
    raise exception 'unknown status %', new.status using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_dealer_quote_fields on public.quote_requests;
create trigger enforce_dealer_quote_fields
  before update on public.quote_requests
  for each row execute function public.enforce_dealer_quote_fields();

-- Dealer notes live in their own table: the customer can read their own quote row, and must not read what the
-- dealer wrote about them. Only the assigned dealer and admins see a note.
create table if not exists public.quote_dealer_notes (
  quote_id   uuid primary key references public.quote_requests(id) on delete cascade,
  dealer_id  uuid not null references public.profiles(id) on delete cascade,
  notes      text not null default '' check (length(notes) <= 5000),
  updated_at timestamptz not null default now()
);
alter table public.quote_dealer_notes enable row level security;

drop policy if exists "Dealers manage notes on assigned quotes" on public.quote_dealer_notes;
create policy "Dealers manage notes on assigned quotes" on public.quote_dealer_notes
  for all
  using (dealer_id = auth.uid() and exists (select 1 from public.quote_requests q where q.id = quote_id and q.assigned_dealer = auth.uid()))
  with check (dealer_id = auth.uid() and exists (select 1 from public.quote_requests q where q.id = quote_id and q.assigned_dealer = auth.uid()));

drop policy if exists "Admins manage dealer notes" on public.quote_dealer_notes;
create policy "Admins manage dealer notes" on public.quote_dealer_notes
  for all using (public.is_admin()) with check (public.is_admin());
