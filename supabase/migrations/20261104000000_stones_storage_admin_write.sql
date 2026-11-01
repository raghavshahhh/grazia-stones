-- Admin product photos: admins can upload to the `stones` bucket on production, but removing a photo silently
-- does nothing (storage returns [] = no row passed a DELETE policy). Verified 2026-11-01 with the QA admin account:
-- upload OK, list OK (via "Admins can view stone images"), delete -> []. schema.sql defines the write policies but
-- they are not on production. Recreate all three with public.is_admin(). Idempotent.
drop policy if exists "Admins can upload stone images" on storage.objects;
drop policy if exists "Admins can update stone images" on storage.objects;
drop policy if exists "Admins can delete stone images" on storage.objects;

create policy "Admins can upload stone images" on storage.objects
  for insert with check (bucket_id = 'stones' and public.is_admin());
create policy "Admins can update stone images" on storage.objects
  for update using (bucket_id = 'stones' and public.is_admin()) with check (bucket_id = 'stones' and public.is_admin());
create policy "Admins can delete stone images" on storage.objects
  for delete using (bucket_id = 'stones' and public.is_admin());

