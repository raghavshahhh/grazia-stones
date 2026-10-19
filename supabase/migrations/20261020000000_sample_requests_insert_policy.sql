-- sample_requests / notifications insert policies were `with check (true)`: anyone holding the public
-- anon key could insert rows under another user's id (planting requests in their history, or pushing
-- notifications to any user). Guests may still request samples (user_id null); a signed-in user may only
-- write rows as themselves. Server code uses the service role and bypasses RLS, so it is unaffected.

drop policy if exists "Anyone can create sample requests" on public.sample_requests;
create policy "Anyone can create sample requests"
  on public.sample_requests for insert
  with check (user_id is null or user_id = auth.uid());

drop policy if exists "System can create notifications" on public.notifications;
create policy "Users can create own notifications"
  on public.notifications for insert
  with check (user_id = auth.uid());
