-- Security hardening from the 2026-10-30 audit (build/audit/03_backend_security.md). Idempotent.

-- M2: quote_requests INSERT was `with check (true)`: anyone could file a quote under another user's id and set
-- status / admin_notes. Guests (old app builds) may still insert with user_id null; a signed-in user only as
-- themselves; status and admin notes stay staff-only.
drop policy if exists "Anyone can create quotes" on public.quote_requests;
drop policy if exists "Create own or guest quotes" on public.quote_requests;
create policy "Create own or guest quotes" on public.quote_requests
  for insert with check (
    (user_id is null or user_id = auth.uid())
    and admin_notes is null
    and coalesce(status, 'pending') = 'pending'
  );

-- M6: public buckets serve files by public URL without any SELECT policy; the blanket SELECT policies only
-- let anyone LIST every object (all users' AI room photos). Owners keep seeing their own folder, admins the
-- stone images.
drop policy if exists "AI visualizations publicly viewable" on storage.objects;
drop policy if exists "AR screenshots publicly viewable" on storage.objects;
drop policy if exists "Avatar images public" on storage.objects;
drop policy if exists "Stone images public" on storage.objects;
drop policy if exists "Owners can view own AI visualizations" on storage.objects;
drop policy if exists "Owners can view own AR screenshots" on storage.objects;
drop policy if exists "Owners can view own avatar" on storage.objects;
drop policy if exists "Admins can view stone images" on storage.objects;
create policy "Owners can view own AI visualizations" on storage.objects
  for select using (bucket_id = 'ai-visualizations' and (auth.uid())::text = (storage.foldername(name))[1]);
create policy "Owners can view own AR screenshots" on storage.objects
  for select using (bucket_id = 'ar-screenshots' and (auth.uid())::text = (storage.foldername(name))[1]);
create policy "Owners can view own avatar" on storage.objects
  for select using (bucket_id = 'avatars' and (auth.uid())::text = (storage.foldername(name))[1]);
create policy "Admins can view stone images" on storage.objects
  for select using (bucket_id = 'stones' and public.is_admin());

-- L3: audit_logs accepted inserts from anyone (anon included) and nothing in the app writes it.
drop policy if exists "System can create audit logs" on public.audit_logs;
