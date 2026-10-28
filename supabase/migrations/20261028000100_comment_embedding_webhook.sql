-- Connect public.comments writes to the deployed embed-comment Edge Function.
-- Before applying, add the same strong random value to:
--   1. Edge Function secret EMBEDDING_WEBHOOK_SECRET
--   2. Vault secret named embedding_webhook_secret
-- See supabase/COMMENT_EMBEDDING_WEBHOOK.md for setup instructions.

create extension if not exists pg_net with schema extensions;

do $$
begin
  if not exists (
    select 1
      from vault.decrypted_secrets
     where name = 'embedding_webhook_secret'
  ) then
    raise exception
      'Add Vault secret embedding_webhook_secret before applying this migration';
  end if;
end
$$;

create or replace function public.dispatch_comment_embedding(
  p_comment_id uuid,
  p_comment_body text,
  p_event_type text
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret text;
  v_request_id bigint;
begin
  if p_event_type not in ('INSERT', 'UPDATE') then
    raise exception 'unsupported_comment_event';
  end if;

  select decrypted_secret
    into v_secret
    from vault.decrypted_secrets
   where name = 'embedding_webhook_secret'
   limit 1;

  if v_secret is null then
    raise exception 'embedding_webhook_secret_missing';
  end if;

  select net.http_post(
    url := 'https://jiyvwjzzirszsypsfsvj.supabase.co/functions/v1/embed-comment',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object(
      'type', p_event_type,
      'table', 'comments',
      'schema', 'public',
      'record', jsonb_build_object(
        'id', p_comment_id,
        'body', p_comment_body
      ),
      'old_record', null
    ),
    timeout_milliseconds := 20000
  )
    into v_request_id;

  return v_request_id;
end
$$;

revoke all on function public.dispatch_comment_embedding(uuid, text, text)
  from public, anon, authenticated;

create or replace function public.comments_embedding_webhook_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.dispatch_comment_embedding(
    new.id,
    new.body,
    tg_op
  );
  return new;
exception
  when others then
    -- Do not fail a customer comment write because the asynchronous embedding
    -- service is temporarily unavailable; null embeddings are backfillable.
    raise warning 'Could not queue comment embedding for comment %: %',
      new.id, sqlerrm;
    return new;
end
$$;

revoke all on function public.comments_embedding_webhook_trigger()
  from public, anon, authenticated;

do $$
begin
  if not exists (
    select 1
      from pg_trigger
     where tgrelid = 'public.comments'::regclass
       and tgname = 'comments_embedding_webhook'
       and not tgisinternal
  ) then
    execute '
      create trigger comments_embedding_webhook
      after insert or update of body on public.comments
      for each row
      execute function public.comments_embedding_webhook_trigger()
    ';
  end if;
end
$$;
