-- ai_jobs had select+insert policies for the owning user, but no update
-- policy — so the client-driven job pipeline (queued -> processing ->
-- completed/failed) could create a job but never update its own status.
create policy "Users can update own AI jobs"
  on public.ai_jobs for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
