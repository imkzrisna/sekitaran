# Populating embeddings for existing business comments

## Problem and approach

Current business comments are visible in the app but cannot be found by the vector-based assistant while their `comments.embedding` values are null. Populate the column with genuine embeddings generated from each comment's text, using the same `gte-small` model and 384 dimensions used for question embeddings. Do not write fabricated/static vectors: those would make nearest-neighbor results misleading rather than searchable.

Backfill existing comments in bounded, repeatable batches through the trusted server-side embedding path, then keep embeddings current for future comment inserts and edits.

## Current state

- The comment table has an `embedding` vector column.
- The deployed `embed-comment` Edge Function expects a comment event and generates a normalized 384-dimensional `gte-small` embedding before conditionally updating the row by both comment ID and original body.
- The current recommendation RPC only returns rows with non-null embeddings.
- Existing local webhook/migration work describes a proposed event trigger and backfill dispatcher, but production must be rechecked before running it. Secret configuration and live deployment need to be verified; do not assume earlier local setup artifacts have already been applied.

## Scope and assumptions

- Use real vectors generated from the exact stored comment body by the same model family/dimensions used at query time.
- Backfill every current comment missing an embedding, with safe retries and bounded batch sizes.
- Also install/verify automatic embedding for new and edited comments.
- Keep service-role and webhook credentials server-side. Do not put keys in client code or committed scripts.
- Avoid changing comment text, business metadata, or unrelated recommendation behavior.

## Implementation todos

1. **Verify current embedding state and prerequisites**
   - Count total comments, missing embeddings, and vectors with unexpected dimensions.
   - Confirm current `embed-comment` deployment, `gte-small` model, 384-dimension column/RPC contract, and necessary Edge Function/Vault secret configuration.
   - Check the existing database trigger/queue setup and avoid installing duplicate dispatchers.

2. **Generate and store authentic embeddings**
   - Use the existing trusted embedding implementation to process rows where `embedding IS NULL`, in bounded batches.
   - Ensure writes are conditional on both comment ID and unchanged comment body so an old vector cannot overwrite a newer comment edit.
   - Make each batch safe to rerun; record processed/skipped/failed counts and retry transient failures without exposing comment contents or secrets in logs.
   - Do not fill the column with random, zero, repeated, or otherwise synthetic vectors.

3. **Automate future comment embedding**
   - Install or repair the server-side insert/body-update trigger/webhook to invoke `embed-comment` using the expected event shape and secret header.
   - Keep delivery observable and recoverable; comment posting should not silently lose embedding work.

4. **Verify search quality and operations**
   - Confirm all eligible comments have non-null, finite, 384-dimensional embeddings.
   - Generate representative query vectors with the same model and call `match_business_comments`; verify actual comment IDs/businesses are returned for relevant questions.
   - Test a new comment and an edited comment through the automatic path.
   - Confirm retries are idempotent and genuinely unmatched questions still return a clear empty-evidence result.

## Acceptance criteria

- Existing comments have model-generated vectors, not placeholders.
- New and edited comments are embedded automatically through the trusted server path.
- Vector matching returns relevant existing comments for representative queries.
- Embedding failures are surfaced for retry/operations; secret values remain out of client code, logs, and version control.

## Dependencies and cautions

- Applying database changes and backfilling production data requires active Supabase database/migration access and correctly configured Edge Function and Vault secrets.
- Verify the target project and deployed function before any production write.
- Live embedding generation can incur compute/provider usage; keep the batches bounded and report progress.

## Execution status

- Added `supabase/scripts/backfill-comment-embeddings.ts`, a dry-run-capable, keyset-paginated backfill that uses the trusted `embed-comment` function, bounds concurrency, retries transient failures, validates 384-dimensional results, and reports only counts/comment IDs.
- Removed automatic backfill dispatch from the trigger migration so migration application does not unexpectedly queue writes; documented the explicit dry-run and backfill commands.
- `deno check` passes for the backfill script and both Edge Functions; assistant tests and targeted Flutter analysis pass.
- Supabase database/migration/deployment/secret tools are not currently available. No live database writes or embeddings were attempted. Production backfill, webhook installation, and live retrieval verification remain blocked pending configured secrets and deployment access.
