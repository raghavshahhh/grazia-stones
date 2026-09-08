-- Allow admins to update any user's profile (role promotion/demotion, contact details)
create policy "Admins can update all profiles"
  on public.profiles for update
  using (public.is_admin())
  with check (public.is_admin());
