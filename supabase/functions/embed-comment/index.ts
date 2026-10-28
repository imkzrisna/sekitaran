/// <reference types="jsr:@supabase/functions-js/edge-runtime.d.ts" />

import { createClient } from "npm:@supabase/supabase-js@2";

declare const Supabase: {
    ai: {
        Session: new (model: string) => {
            run(
                input: string,
                options: { mean_pool: boolean; normalize: boolean },
            ): Promise<unknown>;
        };
    };
};

type CommentRecord = { id: string; body: string };
type CommentWebhook = {
    type: "INSERT" | "UPDATE";
    table: "comments";
    schema: "public";
    record: CommentRecord;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const webhookSecret = Deno.env.get("EMBEDDING_WEBHOOK_SECRET");

if (!supabaseUrl || !serviceRoleKey || !webhookSecret) {
    throw new Error("Missing required embedding function secrets.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
});
const model = new Supabase.ai.Session("gte-small");

const json = (body: unknown, status = 200) =>
    Response.json(body, {
        status,
        headers: { "Access-Control-Allow-Origin": "*" },
    });

Deno.serve(async (request: Request) => {
    if (request.method !== "POST") {
        return json({ error: "Method not allowed" }, 405);
    }
    if (request.headers.get("x-webhook-secret") !== webhookSecret) {
        return json({ error: "Unauthorized webhook" }, 401);
    }

    let event: CommentWebhook;
    try {
        event = await request.json();
    } catch {
        return json({ error: "Invalid webhook payload" }, 400);
    }
    const { id, body } = event.record ?? {};
    if (
        event.schema !== "public" ||
        event.table !== "comments" ||
        !["INSERT", "UPDATE"].includes(event.type) ||
        typeof id !== "string" ||
        typeof body !== "string" ||
        body.trim().length === 0 ||
        body.length > 500
    ) {
        return json({ error: "Unsupported or invalid comment event" }, 400);
    }

    try {
        const embedding = await model.run(body.trim(), {
            mean_pool: true,
            normalize: true,
        });
        if (
            !Array.isArray(embedding) ||
            embedding.length !== 384 ||
            !embedding.every((value: number) => Number.isFinite(value))
        ) {
            throw new Error("Invalid embedding output.");
        }

        const { data, error } = await supabase
            .from("comments")
            .update({ embedding: JSON.stringify(embedding) })
            .eq("id", id)
            .eq("body", body)
            .select("id");
        if (error) throw error;
        return json({
            success: true,
            commentId: id,
            skipped: !data?.length,
            dimensions: embedding.length,
        });
    } catch (error) {
        console.error("Comment embedding failed:", error);
        return json({ error: "Could not generate comment embedding" }, 500);
    }
});
