create table if not exists public.business_assistant_request_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  request_count integer not null default 0
);

alter table public.business_assistant_request_limits enable row level security;
revoke all on table public.business_assistant_request_limits
  from public, anon, authenticated;

create or replace function public.get_all_business_comments_for_assistant(
  p_offset integer default 0,
  p_limit integer default 250
)
returns table (
  comment_id uuid,
  business_id uuid,
  business_name text,
  body text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_request_count integer;
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

  insert into public.business_assistant_request_limits
    (user_id, window_started_at, request_count)
  values
    (v_uid, date_trunc('minute', now()), 1)
  on conflict (user_id) do update
    set window_started_at = case
          when public.business_assistant_request_limits.window_started_at
               < date_trunc('minute', now())
            then date_trunc('minute', now())
          else public.business_assistant_request_limits.window_started_at
        end,
        request_count = case
          when public.business_assistant_request_limits.window_started_at
               < date_trunc('minute', now())
            then 1
          else public.business_assistant_request_limits.request_count + 1
        end
  returning request_count into v_request_count;

  if v_request_count > 10 then
    raise exception 'assistant_rate_limited';
  end if;

  return query
    select c.id, b.id, b.name, c.body, c.created_at
      from public.comments c
      join public.businesses b on b.id = c.business_id
     order by c.created_at desc, c.id desc
     limit least(greatest(coalesce(p_limit, 250), 1), 250)
    offset greatest(coalesce(p_offset, 0), 0);
end
$$;

revoke all on function public.get_all_business_comments_for_assistant(integer, integer)
  from public, anon;
grant execute on function public.get_all_business_comments_for_assistant(integer, integer)
  to authenticated;
