-- Cross-business comment retrieval for the authenticated customer assistant.
-- Businesses are included here on the same public basis as the customer shop
-- listing and shop_detail RPC. Do not add owner-only comment/dashboard fields.

create table if not exists public.business_assistant_request_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  request_count integer not null default 0
);

alter table public.business_assistant_request_limits enable row level security;
revoke all on table public.business_assistant_request_limits
  from public, anon, authenticated;

create index if not exists comments_search_idx
  on public.comments using gin (to_tsvector('simple', body));

create or replace function public.search_business_comments(
  p_query text,
  p_limit integer default 12
)
returns table (
  comment_id uuid,
  business_id uuid,
  business_name text,
  comment_excerpt text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_query text := left(regexp_replace(trim(coalesce(p_query, '')), '\s+', ' ', 'g'), 500);
  v_tsquery tsquery;
  v_broad_query tsquery;
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
  if char_length(v_query) < 2 then
    raise exception 'assistant_query_too_short';
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

  v_tsquery := websearch_to_tsquery('simple', v_query);

  return query
    select c.id,
           b.id,
           b.name,
           left(c.body, 300),
           c.created_at
      from public.comments c
      join public.businesses b on b.id = c.business_id
     where to_tsvector('simple', c.body) @@ v_tsquery
        or to_tsvector('simple', b.name) @@ v_tsquery
     order by ts_rank_cd(
                to_tsvector('simple', b.name || ' ' || c.body),
                v_tsquery
              ) desc,
              c.created_at desc
     limit least(greatest(coalesce(p_limit, 12), 1), 12);

  if not found then
    select string_agg(normalized.query_text, ' | ')::tsquery
      into v_broad_query
      from (
        select distinct plainto_tsquery('simple', term)::text as query_text
          from regexp_split_to_table(v_query, '\s+') as terms(term)
         where numnode(plainto_tsquery('simple', term)) > 0
      ) normalized;

    if v_broad_query is not null then
      return query
        select c.id,
               b.id,
               b.name,
               left(c.body, 300),
               c.created_at
          from public.comments c
          join public.businesses b on b.id = c.business_id
         where to_tsvector('simple', c.body) @@ v_broad_query
            or to_tsvector('simple', b.name) @@ v_broad_query
         order by ts_rank_cd(
                    to_tsvector('simple', b.name || ' ' || c.body),
                    v_broad_query
                  ) desc,
                  c.created_at desc
         limit least(greatest(coalesce(p_limit, 12), 1), 12);
    end if;
  end if;
end
$$;

revoke all on function public.search_business_comments(text, integer)
  from public, anon;
grant execute on function public.search_business_comments(text, integer)
  to authenticated;
