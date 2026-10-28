create or replace function public.get_business_comments_for_assistant(
  p_business_id uuid
)
returns table (
  comment_id uuid,
  business_id uuid,
  business_name text,
  body text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (
    select 1
      from public.profiles p
     where p.id = v_uid
       and p.role = 'regular'
  ) then
    raise exception 'not_authorized';
  end if;

  if not exists (
    select 1
      from public.businesses b
     where b.id = p_business_id
  ) then
    raise exception 'store_not_found';
  end if;

  return query
    select c.id, b.id, b.name, c.body, c.created_at
      from public.comments c
      join public.businesses b on b.id = c.business_id
     where b.id = p_business_id
     order by c.created_at desc, c.id;
end
$$;

revoke all on function public.get_business_comments_for_assistant(uuid)
  from public, anon;
grant execute on function public.get_business_comments_for_assistant(uuid)
  to authenticated;
