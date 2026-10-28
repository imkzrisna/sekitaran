create or replace function public.search_business_comments_full_text(
  search_query text,
  match_count integer default 20
)
returns table (
  comment_id uuid,
  business_id uuid,
  business_name text,
  body text,
  created_at timestamptz,
  relevance real
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

  return query
    with input as (
      select pg_catalog.lower(coalesce(search_query, '')) as query_text
      where pg_catalog.length(
        pg_catalog.btrim(coalesce(search_query, ''))
      ) between 1 and 1000
    ),
    tokens as (
      select distinct split.term
        from input
        cross join lateral pg_catalog.regexp_split_to_table(
          input.query_text,
          '[^[:alnum:]]+'
        ) as split(term)
       where pg_catalog.length(split.term) > 1
    ),
    terms as (
      select pg_catalog.string_agg(term, ' | ') as query_text
        from tokens
    ),
    parsed_query as (
      select case
        when query_text is null then null
        else pg_catalog.to_tsquery('simple'::regconfig, query_text)
      end as query
        from terms
    ),
    ranked_comments as (
      select
        c.id as comment_id,
        b.id as business_id,
        b.name as business_name,
        c.body,
        c.created_at,
        pg_catalog.ts_rank_cd(
          pg_catalog.to_tsvector('simple'::regconfig, coalesce(c.body, '')),
          parsed_query.query
        )::real as relevance
        from public.comments c
        join public.businesses b on b.id = c.business_id
        cross join parsed_query
       where parsed_query.query is not null
         and pg_catalog.to_tsvector(
           'simple'::regconfig,
           coalesce(c.body, '')
         ) @@ parsed_query.query
    )
    select
      ranked_comments.comment_id,
      ranked_comments.business_id,
      ranked_comments.business_name,
      ranked_comments.body,
      ranked_comments.created_at,
      ranked_comments.relevance
      from ranked_comments
     order by ranked_comments.relevance desc, ranked_comments.created_at desc
     limit least(greatest(coalesce(match_count, 20), 1), 20);
end
$$;

revoke all on function public.search_business_comments_full_text(text, integer)
  from public, anon;
grant execute on function public.search_business_comments_full_text(text, integer)
  to authenticated;
