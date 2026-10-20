-- WHY:  Every tenant policy must use one audited predicate instead of repeating
--       membership subqueries. Policies on memberships/orgs cannot query those same
--       tables as the caller without recursing into their own RLS, so the helpers
--       read them with definer rights.
-- WHAT: private.current_user_org_ids() -> uuid[]  orgs the caller belongs to
--       ('{}' when none, or when not signed in);
--       private.is_staff() -> boolean  true only when the caller is a member of an
--       org whose org_type = 'staff'.
--       Both: SECURITY DEFINER, STABLE, search_path = '', schema-qualified names,
--       identity taken only from auth.uid() (never from arguments or user
--       metadata). execute revoked from public and anon, granted to authenticated;
--       usage on schema private granted to authenticated so policies can call them.
--       Why they work despite FORCED RLS on public.memberships / public.orgs: the
--       functions run as their owner `postgres`, which has the BYPASSRLS attribute,
--       and FORCE ROW LEVEL SECURITY does not apply to roles with BYPASSRLS.
--       Policies call them as `(select private.current_user_org_ids())` so Postgres
--       evaluates them once per statement (initPlan), not once per row.
-- ROLLBACK: drop function if exists private.is_staff();
--           drop function if exists private.current_user_org_ids();
--           revoke usage on schema private from authenticated;

grant usage on schema private to authenticated;

create or replace function private.current_user_org_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(m.org_id order by m.org_id), '{}'::uuid[])
  from public.memberships m
  where m.user_id = (select auth.uid());
$$;

comment on function private.current_user_org_ids() is
  'Org ids of the signed-in user (empty array if none). Definer rights; identity from auth.uid() only.';

create or replace function private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    join public.orgs o on o.id = m.org_id
    where m.user_id = (select auth.uid())
      and o.org_type = 'staff'
  );
$$;

comment on function private.is_staff() is
  'True only if the signed-in user is a member of an org with org_type = staff. Definer rights; identity from auth.uid() only.';

revoke execute on function private.current_user_org_ids() from public, anon;
revoke execute on function private.is_staff() from public, anon;
grant execute on function private.current_user_org_ids() to authenticated;
grant execute on function private.is_staff() to authenticated;
