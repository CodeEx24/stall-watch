-- WHY:  The app and link-test-users.sql need every Supabase Auth user as a row in
--       public.users (same id, same email). Clients must not be able to write that
--       table, so a trigger on auth.users copies the row with definer rights.
-- WHAT: private.mirror_auth_user(): AFTER INSERT OR UPDATE OF email ON auth.users,
--       upserts (id, lower(email)) into public.users. Users without an email are
--       skipped (email/password is the only auth method). Backfills existing auth
--       users. Deletes need no trigger: public.users.id references auth.users on
--       delete cascade.
--       SECURITY DEFINER is deliberate: the caller is GoTrue (supabase_auth_admin),
--       which has no rights on public.users; the owner (postgres) has BYPASSRLS, so
--       the insert works despite forced RLS on public.users. search_path = '' and
--       every name schema-qualified; execute revoked from public, anon,
--       authenticated, because only the trigger may run it.
-- ROLLBACK: drop trigger if exists trg_auth_users_mirror on auth.users;
--           drop function if exists private.mirror_auth_user();
--           (mirrored rows in public.users are left in place)

create or replace function private.mirror_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is null then
    return new;
  end if;

  insert into public.users (id, email)
  values (new.id, lower(new.email))
  on conflict (id) do update
    set email = excluded.email
    where public.users.email is distinct from excluded.email;

  return new;
end;
$$;

comment on function private.mirror_auth_user() is
  'Trigger on auth.users: mirrors (id, lower(email)) into public.users. Definer rights; not callable by app roles.';

revoke execute on function private.mirror_auth_user() from public, anon, authenticated;

create trigger trg_auth_users_mirror
  after insert or update of email on auth.users
  for each row execute function private.mirror_auth_user();

-- backfill users that existed before this migration
insert into public.users (id, email)
select u.id, lower(u.email)
from auth.users u
where u.email is not null
on conflict (id) do nothing;
