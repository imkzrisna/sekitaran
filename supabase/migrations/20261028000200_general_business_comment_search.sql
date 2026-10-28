drop function if exists public.match_business_comments(
  extensions.vector,
  integer,
  text
);

create or replace function public.match_business_comments(
  query_embedding extensions.vector(384),
  match_count integer default 20
)
returns table (
  comment_id uuid,
  business_id uuid,
  business_name text,
  body text,
  created_at timestamptz,
  similarity real
)
language sql
stable
set search_path = ''
as $$
  select
    c.id,
    b.id,
    b.name,
    c.body,
    c.created_at,
    (
      1 - (
        c.embedding operator(extensions.<=>) query_embedding
      )
    )::real as similarity
  from public.comments c
  join public.businesses b on b.id = c.business_id
  where c.embedding is not null
  order by c.embedding operator(extensions.<=>) query_embedding
  limit least(greatest(match_count, 1), 50);
$$;
