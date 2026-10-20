-- WHY:  Apps may read identity data scoped to the caller but must never write
--       orgs, users or memberships directly (rows come from the auth-mirror
--       trigger and the provided seed scripts). Builders and staff share the
--       `authenticated` role, so only RLS can tell them apart.
-- WHAT: RLS stays ENABLED and FORCED (set in STW-16, re-asserted here).
--       Read-only policies for `authenticated`:
--         p_orgs_select        own orgs, or everything for staff
--         p_memberships_select memberships of own orgs, or everything for staff
--         p_users_select       self, users who share an org with the caller, or
--                              everything for staff
--       grant select to authenticated; insert/update/delete revoked from anon
--       and authenticated (no write policies exist either). anon gets nothing.
--       Helpers are wrapped in (select ...) so they run once per statement.
-- ROLLBACK: drop policy if exists p_orgs_select on public.orgs;
--           drop policy if exists p_memberships_select on public.memberships;
--           drop policy if exists p_users_select on public.users;
--           revoke select on public.orgs, public.users, public.memberships from authenticated;

alter table public.orgs        enable row level security;
alter table public.orgs        force row level security;
alter table public.users       enable row level security;
alter table public.users       force row level security;
alter table public.memberships enable row level security;
alter table public.memberships force row level security;

create policy p_orgs_select on public.orgs
  for select to authenticated
  using (
    id = any ((select private.current_user_org_ids())::uuid[])
    or (select private.is_staff())
  );

create policy p_memberships_select on public.memberships
  for select to authenticated
  using (
    org_id = any ((select private.current_user_org_ids())::uuid[])
    or (select private.is_staff())
  );

create policy p_users_select on public.users
  for select to authenticated
  using (
    id = (select auth.uid())
    or (select private.is_staff())
    or exists (
      select 1
      from public.memberships m
      where m.user_id = users.id
        and m.org_id = any ((select private.current_user_org_ids())::uuid[])
    )
  );

revoke insert, update, delete, truncate, references, trigger
  on table public.orgs, public.users, public.memberships from anon, authenticated;
revoke select on table public.orgs, public.users, public.memberships from anon;
grant select on table public.orgs, public.users, public.memberships to authenticated;
