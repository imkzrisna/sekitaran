import { createClient } from "npm:@supabase/supabase-js@2";

type CommentRow = { id: string; body: string };
type EmbedResult = {
  success?: boolean;
  commentId?: string;
  skipped?: boolean;
  dimensions?: number;
};

class NonRetryableError extends Error {}

const pageSize = 100;
const concurrency = 3;
const maxAttempts = 3;
const dryRun = Deno.args.includes("--dry-run");

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Set ${name} in the environment.`);
  return value;
}

const supabaseUrl = requiredEnv("SUPABASE_URL");
const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
const webhookSecret = requiredEnv("EMBEDDING_WEBHOOK_SECRET");

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const functionUrl = new URL(
  "/functions/v1/embed-comment",
  supabaseUrl,
).toString();

async function loadPage(afterId: string | null): Promise<CommentRow[]> {
  let query = supabase
    .from("comments")
    .select("id, body")
    .is("embedding", null)
    .order("id", { ascending: true })
    .limit(pageSize);
  if (afterId !== null) query = query.gt("id", afterId);

  const { data, error } = await query;
  if (error) {
    throw new Error(`Could not load comments for backfill: ${error.message}`);
  }
  return (data ?? []) as CommentRow[];
}

async function embedComment(
  comment: CommentRow,
): Promise<"embedded" | "skipped"> {
  const payload = {
    type: "UPDATE",
    table: "comments",
    schema: "public",
    record: { id: comment.id, body: comment.body },
    old_record: null,
  };

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const response = await fetch(functionUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-webhook-secret": webhookSecret,
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(30_000),
      });

      if (response.ok) {
        const result = await response.json() as EmbedResult;
        if (
          result.success !== true ||
          result.commentId !== comment.id ||
          (!result.skipped && result.dimensions !== 384)
        ) {
          throw new NonRetryableError(
            "Embedding function returned an invalid success response.",
          );
        }
        return result.skipped ? "skipped" : "embedded";
      }

      if (
        response.status < 500 &&
        response.status !== 429
      ) {
        throw new NonRetryableError(
          `Embedding function rejected a comment (HTTP ${response.status}).`,
        );
      }
      if (attempt === maxAttempts) {
        throw new Error(`Embedding function failed (HTTP ${response.status}).`);
      }
    } catch (error) {
      if (error instanceof NonRetryableError) throw error;
      if (attempt === maxAttempts) {
        if (error instanceof Error) throw error;
        throw new Error("Embedding request failed.");
      }
    }

    await new Promise((resolve) => setTimeout(resolve, attempt * 1000));
  }

  throw new Error("Embedding request exhausted retry attempts.");
}

async function run(): Promise<void> {
  let cursor: string | null = null;
  let discovered = 0;
  let embedded = 0;
  let skipped = 0;
  const failures: string[] = [];

  while (true) {
    const page = await loadPage(cursor);
    if (page.length === 0) break;

    discovered += page.length;
    cursor = page[page.length - 1].id;
    if (dryRun) continue;

    for (let start = 0; start < page.length; start += concurrency) {
      const batch = page.slice(start, start + concurrency);
      const results = await Promise.allSettled(
        batch.map((comment) => embedComment(comment)),
      );
      results.forEach((result, index) => {
        if (result.status === "fulfilled") {
          if (result.value === "skipped") skipped++;
          else embedded++;
        } else {
          failures.push(batch[index].id);
        }
      });
    }

    console.log(
      `Scanned ${discovered} comments; embedded ${embedded}; skipped ${skipped}; failed ${failures.length}.`,
    );
  }

  if (dryRun) {
    console.log(`Dry run: found ${discovered} comments without embeddings.`);
    return;
  }

  console.log(
    `Backfill finished: found ${discovered}; embedded ${embedded}; skipped ${skipped}; failed ${failures.length}.`,
  );
  if (failures.length > 0) {
    console.error(`Retry failed comment IDs: ${failures.join(", ")}`);
    Deno.exitCode = 1;
  }
}

await run();
