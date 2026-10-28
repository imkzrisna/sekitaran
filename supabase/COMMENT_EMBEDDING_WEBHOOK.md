# Supabase assistant search and comment embedding setup

The active assistant retrieval path uses PostgreSQL full-text search against
existing comment bodies, so assistant answers no longer require embeddings.
The SQL RPC ranks matching comments and caps results before the Edge Function
passes evidence to Gemini. This is lexical search: paraphrases and synonyms
that do not share words with comments may not match.

The `embed-comment` function, vector RPC, webhook, and backfill script remain
available as an optional semantic-search path; they are not prerequisites for
the current assistant flow.

The active function sources are now tracked under `supabase/functions/`:
`recommend-stores` and `embed-comment`. The separate
`functions/business-assistant` directory is a full-text prototype and is not
the Flutter app's active recommendation endpoint.

## Deploy active SQL comment search

Apply migrations
`20261028000300_business_comment_full_text_search.sql` and
`20261028000400_business_comment_search_security.sql`, then deploy the tracked
`recommend-stores` Edge Function. The first migration adds an expression GIN
index and bounded `search_business_comments_full_text` RPC. The follow-up
allows the RPC to read comments hidden by customer-facing RLS while restricting
execution to authenticated regular customers. For store-specific Gemini
analysis, also apply
`20261028000500_store_assistant_comments.sql`; the assistant page can then load
all comments for the selected store and send them to Gemini as evidence. These
migrations do not read or write `comments.embedding`.

General questions across stores use
`20261028000600_global_assistant_comments.sql` to retrieve all comments in
bounded pages for Gemini-side comparison. Deploy both `recommend-stores` and
the compatibility `business-assistant` endpoint so older app builds do not
continue using lexical-only retrieval.

Before applying production migrations, reconcile the migration history with
the live schema. Prior inspection found live database objects while Supabase
reported no migration history; do not blindly run `db push` or replace
existing functions.

## Optional: configure semantic comment embeddings

Generate a strong random secret (at least 32 bytes). Store the same value in
both places without committing or sharing it:

1. Add an Edge Function secret named `EMBEDDING_WEBHOOK_SECRET` for
   `embed-comment`.
2. In the Supabase SQL Editor, store it in Vault:

   ```sql
   select vault.create_secret(
     '<same generated random value>',
     'embedding_webhook_secret',
     'Shared secret for comment embedding webhook requests'
   );
   ```

If either secret already exists, update it to the same value in its respective
secret store. Do not retrieve a secret value into client code, logs, or this
file.

## Optional: install and process existing comment embeddings

Only use this path if semantic vector search is separately desired. Apply the
vector/webhook migrations in order with the Supabase CLI or Dashboard after
checking the live schema:

1. Apply `20261028000000_match_business_comments.sql` to establish the
   vector-search RPC contract.
2. Ensure the Vault secret is configured, then apply
   `20261028000100_comment_embedding_webhook.sql`. It enables `pg_net`, creates
   a server-side trigger for comment inserts and body updates. It does not
   automatically backfill existing rows.
3. Apply `20261028000200_general_business_comment_search.sql` to remove category
   filtering and return only comment-based business evidence from the vector
   search RPC.
4. Deploy `recommend-stores` and `embed-comment` from their tracked function
   directories, preserving the function secrets and `verify_jwt` settings.

To backfill from a trusted local environment after deployment, export
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `EMBEDDING_WEBHOOK_SECRET`
without putting their values in source control. First run
`deno run --allow-env --allow-net supabase/scripts/backfill-comment-embeddings.ts --dry-run`
to count missing vectors. Then omit `--dry-run` to process bounded pages through
the same `embed-comment` function. Failed comment IDs are reported so the
script can be safely rerun; it never logs the comment text or secret values.

The trigger's network requests are asynchronous. Verify completion by checking that
`public.comments.embedding` is non-null for prior comments and that new comments
receive vectors. Then test `public.match_business_comments` and the deployed
`recommend-stores` Edge Function with representative questions.

If function secrets are rotated, update the Vault copy to the same value. The
trigger does not block comment posting if embedding queuing fails; inspect
Postgres warnings and Edge Function logs, then rerun the backfill.

Do not treat applying these local artifacts as proof that production has been
fixed. Confirm the deployed functions, migration state, and embedding counts
against the target Supabase project after rollout.
