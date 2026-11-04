-- Google / Apple sign-ups showed the default avatar: handle_new_user() copied only full_name, while Google puts
-- the photo in raw_user_meta_data.avatar_url (or .picture) and the name in .full_name (or .name).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, phone, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture')
  );
  return new;
end;
$$;

-- Existing accounts: fill only empty photo / name fields, never overwrite what the user set.
update public.profiles p
set avatar_url = coalesce(nullif(p.avatar_url, ''), u.raw_user_meta_data ->> 'avatar_url', u.raw_user_meta_data ->> 'picture'),
    full_name  = coalesce(nullif(p.full_name, ''), u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')
from auth.users u
where u.id = p.id
  and ((coalesce(p.avatar_url, '') = '' and coalesce(u.raw_user_meta_data ->> 'avatar_url', u.raw_user_meta_data ->> 'picture', '') <> '')
    or (coalesce(p.full_name, '') = '' and coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '') <> ''));
