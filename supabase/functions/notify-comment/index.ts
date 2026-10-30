import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5";

const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
const secret = Deno.env.get("WEBHOOK_SECRET")!;
const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

async function accessToken(): Promise<string> {
  const key = await importPKCS8(sa.private_key, "RS256");
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  return (await r.json()).access_token;
}

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }
  const payload = await req.json();
  const c = payload.record;
  if (payload.type !== "INSERT" || !c?.business_id) {
    return new Response("ignored");
  }

  const { data: biz } = await admin
    .from("businesses")
    .select("name, owner_id")
    .eq("id", c.business_id)
    .maybeSingle();
  if (!biz) return new Response("no business");

  const { data: tokens } = await admin
    .from("device_tokens")
    .select("token")
    .eq("user_id", biz.owner_id);
  if (!tokens?.length) return new Response("no tokens");

  const body = String(c.body ?? "").slice(0, 120);
  const at = await accessToken();
  const url =
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  for (const { token } of tokens) {
    const r = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${at}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: `Komentar baru di ${biz.name}`, body },
          data: { business_id: String(c.business_id) },
          android: {
            priority: "HIGH",
            notification: { channel_id: "comments" },
          },
        },
      }),
    });
    if (r.status === 404 || r.status === 400) {
      const t = await r.text();
      if (t.includes("UNREGISTERED") || t.includes("INVALID_ARGUMENT")) {
        await admin.from("device_tokens").delete().eq("token", token);
      }
    }
  }
  return new Response("ok");
});
