-- Enable Supabase Realtime for ai_jobs so .stream() subscriptions can receive
-- row-level inserts, updates, and deletes in real-time.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'ai_jobs'
  ) then
    alter publication supabase_realtime add table public.ai_jobs;
  end if;
end $$;

-- Set replica identity to full so update payloads include the entire row
alter table public.ai_jobs replica identity full;
