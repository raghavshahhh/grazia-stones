-- Dealer panel (contract: "Dealer Panel & Lead Management"). Admins assign a quote request to a dealer account
-- (profiles.role = 'dealer'); the dealer sees only the quotes assigned to them and can move the status and keep
-- their own notes. Additive and idempotent: existing rows, policies for customers and admins are unchanged.

alter table public.quote_requests
  add column if not exists assigned_dealer uuid references public.profiles(id) on delete set null,
  add column if not exists dealer_notes text;
create index if not exists quote_requests_assigned_dealer_idx on public.quote_requests (assigned_dealer);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'quote_requests_dealer_notes_len') then
    alter table public.quote_requests add constraint quote_requests_dealer_notes_len check (length(dealer_notes) <= 5000) not valid;
  end if;
end $$;

drop policy if exists "Dealers can view assigned quotes" on public.quote_requests;
create policy "Dealers can view assigned quotes" on public.quote_requests
  for select using (assigned_dealer = auth.uid());

drop policy if exists "Dealers can update assigned quotes" on public.quote_requests;
create policy "Dealers can update assigned quotes" on public.quote_requests
  for update using (assigned_dealer = auth.uid()) with check (assigned_dealer = auth.uid());

-- Customers and guests must not pick a dealer or write dealer notes when they create a quote.
drop policy if exists "Create own or guest quotes" on public.quote_requests;
create policy "Create own or guest quotes" on public.quote_requests
  for insert with check (
    (user_id is null or user_id = auth.uid())
    and admin_notes is null
    and coalesce(status, 'pending') = 'pending'
    and assigned_dealer is null
    and dealer_notes is null
  );

-- A dealer may change only status and dealer_notes on their quote (not the customer details, the assignment or
-- admin notes). A trigger, not a policy, because RLS cannot compare old and new values. Admins and SQL bypass it.
create or replace function public.enforce_dealer_quote_fields()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  n jsonb := to_jsonb(new) - 'status' - 'dealer_notes' - 'updated_at';
  o jsonb := to_jsonb(old) - 'status' - 'dealer_notes' - 'updated_at';
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;
  if n is distinct from o then
    raise exception 'dealers can only change the status and their notes' using errcode = '42501';
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
