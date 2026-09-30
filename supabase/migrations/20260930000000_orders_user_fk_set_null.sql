-- Account deletion failed for any user who had an order: orders.user_id referenced
-- profiles(id) with no ON DELETE action (and was NOT NULL), so deleting the auth user
-- -> profile cascade was blocked. Keep the order rows (accounting) but detach them.
--
-- NOT applied automatically. Review, then run with `supabase db push`.

alter table public.orders alter column user_id drop not null;

do $$
declare c text;
begin
  for c in
    select con.conname
    from pg_constraint con
    join pg_attribute a on a.attrelid = con.conrelid and a.attnum = any (con.conkey)
    where con.conrelid = 'public.orders'::regclass
      and con.contype = 'f'
      and a.attname = 'user_id'
  loop
    execute format('alter table public.orders drop constraint %I', c);
  end loop;
end $$;

alter table public.orders
  add constraint orders_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;
